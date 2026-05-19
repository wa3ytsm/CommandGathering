# Command Gathering Handoff

更新日期：2026-05-19

## 当前状态
- 项目是 Swift Package macOS App。
- UI 外壳使用 SwiftUI，左侧是分组树，右侧上方是选中分组的命令列表，右侧下方是终端 tabs。
- 终端使用 vendored SwiftTerm 的 `LocalProcessTerminalView`，运行真实 pseudo-terminal shell。
- 核心模型和 tab 绑定逻辑有 XCTest 覆盖。
- 发布到 GitHub 时，必须忽略 `CommandGatheringData/` 和 `dist/`，不要提交用户自定义命令、终端历史或本地打包产物。
- GitHub Releases 应上传 `scripts/build-release.sh` 产出的干净 zip；这个脚本会单独生成 `dist/release/CommandGathering-Clean.app`，不要碰用户正在使用的 `dist/CommandGathering.app`。

## 入口文件
- `Package.swift`：包定义和本地 SwiftTerm 依赖。
- `Sources/CommandGatheringApp/CommandGatheringApp.swift`：App 入口。
- `Sources/CommandGatheringApp/RootView.swift`：主布局，左侧分组树，右侧命令列表和终端 tab。
- `Sources/CommandGatheringApp/AppModel.swift`：应用状态、配置加载保存、命令编辑和 tab 操作。
- `Sources/CommandGatheringApp/CommandListView.swift`：当前分组下的命令卡片列表。
- `Sources/CommandGatheringApp/PersistentVerticalStackSplitView.swift`：右侧命令卡片区域和终端区域之间的上下拖动分隔，持久化 `commandListHeight`。
- `Sources/CommandGatheringApp/CommandSidebarView.swift`：分组树、新建分组、分组拖拽排序和分组操作菜单。
- `Sources/CommandGatheringApp/GroupEditorView.swift`：分组名称编辑弹窗。
- `Sources/CommandGatheringApp/TerminalPaneView.swift`：SwiftTerm AppKit bridge 和 zsh 启动。
- `Sources/CommandGatheringCore/TerminalCoordinator.swift`：命令按钮到终端 tab 的绑定规则。
- `Sources/CommandGatheringCore/CommandStore.swift`：`commands.json` 读写。

## 功能规则
- 左侧树状展示命令分组，可新建分组。
- 左侧分组支持拖拽排序、右键编辑名称和删除，排序写入 `sortOrder` 并保存到 `commands.json`。
- 删除分组会同步删除该分组下命令，并且至少保留一个分组。
- 右侧按当前选中分组展示命令卡片。
- 右侧命令卡片支持右键菜单，可编辑命令或删除。
- 命令可新建、编辑、删除。
- 命令字段包含名称、分组、命令文本、说明、图标、颜色。
- 右侧顶部有两个入口：
  - `新建命令`：在当前选中分组里创建保存到配置的命令。
  - `临时命令`：打开临时命令窗口，不保存命令配置；默认进入运行时推导出的工作目录。`swift run` 时是当前项目目录，打包 `.app` 时优先回到外层工作目录，否则回落到用户 Home。
- 侧边栏显隐按钮在左侧栏 `命令分组` 标题右边，只显示图标不加额外背景；显隐状态保存到 `UserDefaults.isSidebarHidden`；隐藏后最左侧会显示窄恢复条。
- 左侧 `命令分组` 和右侧当前分组标题下不显示说明小字。
- 右侧顶部靠右有暗亮模式图标按钮，主题状态保存到 `UserDefaults.themeMode`。
- 右侧命令卡片区域的空白处支持右键 `新建命令`，实现使用 `BlankCommandContextMenuView` 覆盖卡片实际内容下方的空白区，避免 `ScrollView` 吃掉 SwiftUI 背景菜单。
- 新建命令默认填入名称 `新命令` 和命令 `pwd`，避免空表单保存时像没有响应；校验错误在编辑弹窗内直接显示。
- 右侧命令卡片容器和终端容器之间只有终端顶部细分隔条可拖动，不额外保留大块空白；拖动后的命令卡片区域高度保存到 `UserDefaults.commandListHeight`。
- 终端 tab 的非当前窗口标题使用动态主题色保证可读。
- 终端 tab 栏高度压缩到 36px，和右侧 `+` 按钮高度接近。
- 默认分组：
  - `常用命令`
  - `程序打包`
- 默认打包命令在 `程序打包` 分组，命令内容：
  ```bash
  cd <当前项目目录>/scripts
  bash build-app.sh
  ```
- 点击命令：
  - 如果没有活跃绑定 tab，新建 tab 并执行命令一次。
  - 如果已有绑定 tab，只切换到该 tab，不重复执行。
- 关闭绑定 tab 后会解除绑定，下次点击会重新创建并执行。
- tab 栏 `+` 新建空白交互式 shell，不绑定任何命令。

## 存储
- `swift run`：`CommandGatheringData/commands.json`
- `.app`：`CommandGathering.app/CommandGatheringData/commands.json`
- 首次启动没有配置文件时写入默认命令。
- 如果检测到旧默认 `Git 状态 / git status --short`，启动时会做一次旧配置迁移：移除旧 Git 默认，并补入 `程序打包 / 打包 Command Gathering`。
- 正常已有配置不会重新补齐默认命令，用户删除、改名或编辑默认命令后，重启必须保持用户配置。
- JSON 使用 schemaVersion，后续迁移可基于该字段。
- 打包脚本会保留已有 `.app` 内的 `CommandGatheringData`。

## 运行和打包
```bash
cd <repo>
rtk swift test
rtk swift build
rtk swift run CommandGatheringApp
rtk scripts/build-app.sh
rtk scripts/build-release.sh
```

打包输出：
```text
dist/CommandGathering.app
dist/release/CommandGathering-v<version>-macOS.zip
```

## 已知取舍
- SwiftTerm 以 `Vendor/SwiftTerm` 本地依赖方式引入，因为当前网络下 SwiftPM 拉 GitHub 经常失败。
- `Vendor/SwiftTerm/Package.swift` 已裁剪成只构建 `SwiftTerm` library，避免拉 `swift-argument-parser` 和 docc 插件。
- 这是本地自用 unsandboxed 工具风格，配置写在 `.app` 内部数据目录；如果以后要 sandbox 或上架，应迁回 Application Support。
- 之前点击命令可能卡死的根因候选是 `NSViewRepresentable.makeNSView/updateNSView` 内直接调用 `model.consumePendingCommand` 修改 `@Observable` 状态，容易触发 SwiftUI 更新重入；现在启动命令保存在 `TerminalSession.startupCommand`，终端视图只读 session 数据并自行保证只发送一次。
- 终端启动改为用户 shell + `-i` 交互模式，避免用 `-zsh` 登录 shell 额外触发登录初始化；`~/.zshrc` 仍会生效。
- 2026-05-19 收口时，默认打包命令与临时命令默认目录已改成运行时推导，不再把某台机器的 `/Users/...` 路径写死到源码里，便于公开仓库发布。
- 2026-05-19 新增 `scripts/build-release.sh`，独立构建 `dist/release/CommandGathering-Clean.app` 和 release zip，保证 Release 下载包是干净版本，同时不覆盖本地正在使用的 `.app`。
