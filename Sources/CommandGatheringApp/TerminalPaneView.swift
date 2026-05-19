import AppKit
import CommandGatheringCore
import SwiftTerm
import SwiftUI

struct TerminalPaneView: NSViewRepresentable {
    @Bindable var model: AppModel
    let session: TerminalSession

    func makeNSView(context: Context) -> CommandTerminalView {
        let terminalView = CommandTerminalView(frame: .zero)
        terminalView.configureAppearance()
        terminalView.processDelegate = context.coordinator
        context.coordinator.terminalView = terminalView
        context.coordinator.startShellIfNeeded()
        context.coordinator.sendStartupCommandIfNeeded(session.startupCommand)
        return terminalView
    }

    func updateNSView(_ nsView: CommandTerminalView, context: Context) {
        context.coordinator.terminalView = nsView
        context.coordinator.startShellIfNeeded()
        context.coordinator.sendStartupCommandIfNeeded(session.startupCommand)
    }

    func dismantleNSView(_ nsView: CommandTerminalView, coordinator: Coordinator) {
        nsView.terminate()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(sessionID: session.id, workingDirectory: session.workingDirectory)
    }

    final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let sessionID: UUID
        let workingDirectory: String?
        weak var terminalView: CommandTerminalView?
        private var startedShell = false
        private var sentStartupCommand = false
        private var pendingCommands: [String] = []

        init(sessionID: UUID, workingDirectory: String?) {
            self.sessionID = sessionID
            self.workingDirectory = workingDirectory
        }

        @MainActor
        func startShellIfNeeded() {
            guard !startedShell, let terminalView else {
                return
            }

            startedShell = true
            let shell = ShellResolver.defaultShell()
            let launchConfiguration = ShellResolver.launchConfiguration(for: sessionID, shell: shell)
            terminalView.startProcess(
                executable: shell,
                args: launchConfiguration.args,
                environment: launchConfiguration.environment,
                execName: URL(fileURLWithPath: shell).lastPathComponent,
                currentDirectory: workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser.path
            )
            flushPendingCommands()
        }

        @MainActor
        func sendStartupCommandIfNeeded(_ command: String?) {
            guard !sentStartupCommand, let command else {
                return
            }
            sentStartupCommand = true
            let commandLine = command.hasSuffix("\n") ? command : command + "\n"
            pendingCommands.append(commandLine)
            flushPendingCommands()
        }

        @MainActor
        private func flushPendingCommands() {
            guard startedShell, let terminalView, terminalView.process.running else {
                return
            }

            let commands = pendingCommands
            pendingCommands.removeAll()
            for command in commands {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak terminalView] in
                    guard let terminalView else {
                        return
                    }
                    let bytes = Array(command.utf8)
                    terminalView.send(source: terminalView, data: bytes[...])
                }
            }
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func processTerminated(source: TerminalView, exitCode: Int32?) {}
    }
}

final class CommandTerminalView: LocalProcessTerminalView {
    func configureAppearance() {
        wantsLayer = true
        nativeForegroundColor = Theme.terminalForeground
        nativeBackgroundColor = Theme.terminalBackground
        layer?.backgroundColor = Theme.terminalBackground.cgColor
        scrollerStyle = .legacy
        selectedTextBackgroundColor = Theme.terminalSelection
        caretColor = Theme.terminalCaret
        optionAsMetaKey = true
        useBrightColors = true
        font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        getTerminal().setCursorStyle(.steadyBlock)
        do {
            try setUseMetal(false)
        } catch {
            feed(text: "SwiftTerm Metal renderer disabled: \(error.localizedDescription)\r\n")
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
}

enum ShellResolver {
    struct LaunchConfiguration {
        let args: [String]
        let environment: [String]
    }

    static func defaultShell() -> String {
        let fallback = "/bin/zsh"
        let bufferSize = sysconf(_SC_GETPW_R_SIZE_MAX)
        guard bufferSize > 0 else {
            return fallback
        }

        let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var pwd = passwd()
        var result: UnsafeMutablePointer<passwd>?
        guard getpwuid_r(getuid(), &pwd, buffer, bufferSize, &result) == 0,
              let shell = result?.pointee.pw_shell else {
            return fallback
        }

        let resolved = String(cString: shell)
        return resolved.isEmpty ? fallback : resolved
    }

    static func launchConfiguration(for sessionID: UUID, shell: String) -> LaunchConfiguration {
        let historyFileURL = TerminalSessionStorage.historyFileURL(for: sessionID)
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["SHELL"] = shell
        env["HISTFILE"] = historyFileURL.path
        env["COMMAND_GATHERING_HISTFILE"] = historyFileURL.path
        env["COMMAND_GATHERING_HISTSIZE"] = env["HISTSIZE"] ?? "10000"
        env["COMMAND_GATHERING_SAVEHIST"] = env["SAVEHIST"] ?? "10000"
        env["COMMAND_GATHERING_HISTFILESIZE"] = env["HISTFILESIZE"] ?? "10000"
        ensureUTF8Locale(&env)

        let shellName = URL(fileURLWithPath: shell).lastPathComponent
        switch shellName {
        case "zsh":
            let wrapperDirectory = shellWrapperDirectory(for: "zsh")
            prepareZshWrapper(at: wrapperDirectory, environment: &env)
            return LaunchConfiguration(
                args: ["-i"],
                environment: env.map { key, value in "\(key)=\(value)" }
            )
        case "bash":
            let wrapperFileURL = shellWrapperDirectory(for: "bash").appending(path: ".bashrc", directoryHint: .notDirectory)
            prepareBashWrapper(at: wrapperFileURL)
            return LaunchConfiguration(
                args: ["--rcfile", wrapperFileURL.path, "-i"],
                environment: env.map { key, value in "\(key)=\(value)" }
            )
        default:
            applyHistoryFallbacks(&env)
            return LaunchConfiguration(
                args: ["-i"],
                environment: env.map { key, value in "\(key)=\(value)" }
            )
        }
    }

    private static func shellWrapperDirectory(for shellName: String) -> URL {
        let rootDirectory = StorageRootLocator.resolveRootDirectory()
        let wrapperDirectory = rootDirectory
            .appending(path: "shell", directoryHint: .isDirectory)
            .appending(path: shellName, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: wrapperDirectory, withIntermediateDirectories: true)
        return wrapperDirectory
    }

    private static func prepareZshWrapper(at wrapperDirectory: URL, environment: inout [String: String]) {
        let userZdotdir = environment["ZDOTDIR"] ?? FileManager.default.homeDirectoryForCurrentUser.path
        environment["COMMAND_GATHERING_USER_ZDOTDIR"] = userZdotdir
        environment["ZDOTDIR"] = wrapperDirectory.path

        let zshenv = """
        if [[ -f "${COMMAND_GATHERING_USER_ZDOTDIR:-$HOME}/.zshenv" ]]; then
          source "${COMMAND_GATHERING_USER_ZDOTDIR:-$HOME}/.zshenv"
        fi
        """

        let zshrc = """
        export ZDOTDIR="${COMMAND_GATHERING_USER_ZDOTDIR:-$HOME}"
        if [[ -f "$ZDOTDIR/.zshrc" ]]; then
          source "$ZDOTDIR/.zshrc"
        fi
        if [[ -n "${COMMAND_GATHERING_HISTFILE:-}" ]]; then
          export HISTFILE="$COMMAND_GATHERING_HISTFILE"
          export HISTSIZE="${COMMAND_GATHERING_HISTSIZE:-10000}"
          export SAVEHIST="${COMMAND_GATHERING_SAVEHIST:-10000}"
          builtin fc -p "$HISTFILE" "$HISTSIZE" "$SAVEHIST"
          if [[ -f "$HISTFILE" ]]; then
            builtin fc -R "$HISTFILE"
          fi
        fi
        """

        writeShellWrapper(contents: zshenv, to: wrapperDirectory.appending(path: ".zshenv", directoryHint: .notDirectory))
        writeShellWrapper(contents: zshrc, to: wrapperDirectory.appending(path: ".zshrc", directoryHint: .notDirectory))
    }

    private static func prepareBashWrapper(at wrapperFileURL: URL) {
        let bashrc = """
        if [[ -f "$HOME/.bashrc" ]]; then
          source "$HOME/.bashrc"
        fi
        if [[ -n "${COMMAND_GATHERING_HISTFILE:-}" ]]; then
          export HISTFILE="$COMMAND_GATHERING_HISTFILE"
          export HISTSIZE="${COMMAND_GATHERING_HISTSIZE:-10000}"
          export HISTFILESIZE="${COMMAND_GATHERING_HISTFILESIZE:-10000}"
          history -c
          if [[ -f "$HISTFILE" ]]; then
            history -r "$HISTFILE"
          fi
        fi
        """

        writeShellWrapper(contents: bashrc, to: wrapperFileURL)
    }

    private static func writeShellWrapper(contents: String, to url: URL) {
        let existingContents = try? String(contentsOf: url, encoding: .utf8)
        guard existingContents != contents else {
            return
        }
        try? contents.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func applyHistoryFallbacks(_ env: inout [String: String]) {
        if env["HISTSIZE"] == nil {
            env["HISTSIZE"] = "10000"
        }
        if env["SAVEHIST"] == nil {
            env["SAVEHIST"] = "10000"
        }
        if env["HISTFILESIZE"] == nil {
            env["HISTFILESIZE"] = "10000"
        }
    }

    private static func ensureUTF8Locale(_ env: inout [String: String]) {
        let localeKeys = ["LC_ALL", "LC_CTYPE", "LANG"]
        let hasUTF8Locale = localeKeys.contains { key in
            guard let value = env[key]?.uppercased() else {
                return false
            }
            return value.contains("UTF-8") || value.contains("UTF8")
        }

        guard !hasUTF8Locale else {
            return
        }

        env["LANG"] = "C.UTF-8"
        env["LC_CTYPE"] = "C.UTF-8"
    }
}
