# LookDebugBridgeService

`LookDebugBridge` is a Debug-only iOS bridge for AI/script-driven UI inspection, control, and temporary App logs.

It exposes a small local HTTP API from the running Debug app:

```text
GET  /ping
GET  /debug/identity
GET  /debug/page
GET  /debug/windows
GET  /debug/logs
POST /debug/session
POST /debug/tap
POST /debug/switch
POST /debug/text/set
POST /debug/text/type
```

The bridge provides semantic page IDs, stable element IDs, UIWindow/UIView hierarchy inspection, safe UIKit actions, and an in-memory log pool. It does not depend on LookinServer.

## 端口与会话

- 默认监听端口 `37777`（`LookDebugBridge.init(port: UInt16 = 37777)`）；同一台真机/同一个 App 只暴露这一个端口，连续会话直接复用。
- CoreDevice 直连：iOS 17+ 真机优先走 CoreDevice tunnel，MCP 直接访问 `tunnelIP:37777`，无需 iproxy。
- iproxy 回退：旧设备走 `iproxy <localPort>:37777`，`localPort` 由 Mac 侧动态分配，远端始终是 `37777`。
- `sessionID` 是上下文标记，不是并发隔离：
  - 初始值来自环境变量 `DEV_FLOW_SESSION_ID` / `CODEX_THREAD_ID` / `CURSOR_CONVERSATION_ID`，读不到则为 `"local"`。
  - 真机 App 经 `devicectl launch` 启动无法注入环境变量，Mac 侧 MCP 在确认桥后通过 `POST /debug/session` 运行时注入真实会话 id。
  - `sessionID` 用于日志返回值和 `/debug/identity` 匹配目标 App；多个 MCP 会话并发控制同一 App 仍需后续 ownership/lease 机制。
- 连续会话 release 后下个会话可正常连接：`/debug/session` 可被覆盖式注入，NWListener 端口 `37777` 在 TIME_WAIT 后由 `allowLocalEndpointReuse` 复用。

## 鉴权（可选）

设置环境变量 `LOOKDEBUG_TOKEN` 后，所有接口必须携带请求头 `X-LookDebug-Token: <token>` 才放行；未配置时全部放行（默认兼容模式）。token 通过 `LookDebugBridge.init(port:)` 自动从环境变量读取，无需额外配置。

## Podfile

Local development:

```ruby
target 'YourApp' do
  use_frameworks!

  pod 'LookDebugBridge',
      :path => '../LookDebugBridgeService',
      :configurations => ['Debug']
end
```

Git source:

```ruby
target 'YourApp' do
  use_frameworks!

  pod 'LookDebugBridge',
      :git => 'git@github.com:Immmmmmortal1/LookDebugBridgeService.git',
      :configurations => ['Debug']
end
```

The Pod does not depend on LookinServer. Logs are process-local and disappear when the App exits.

## Start

```swift
#if DEBUG
import LookDebugBridge
#endif

#if DEBUG
Task { @MainActor in
    LookDebugBridge.shared.startIfNeeded()
}
#endif
```

## Register Elements

```swift
#if DEBUG
import LookDebugBridge
#endif

final class ExampleViewController: UIViewController {
    private let primaryButton = UIButton(type: .system)
}

#if DEBUG
extension ExampleViewController: LookDebugPageDescribing {
    var lookDebugPageID: String {
        "exampleviewcontroller"
    }

    var lookDebugPageTitle: String {
        "Example"
    }

    func registerLookDebugElements(in registry: LookDebugElementRegistry) {
        registry.register(
            view: primaryButton,
            id: "exampleviewcontroller.primarybutton",
            type: .button,
            label: "Primary"
        )
    }
}
#endif
```

## Notes

- Use only in Debug builds.
- Prefer stable semantic IDs over coordinates.
- System permission alerts are outside the app process and are not handled by this bridge.

## 发布与群通知

打 tag 发布新版本并 push 时，`.githooks/pre-push` 会自动推送飞书群机器人通知（仅发版触发，普通提交不通知）。

新 clone 后启用 hook（一次性）：

```bash
git config core.hooksPath .githooks
```

发布流程：

```bash
# 1. bump 版本（LookDebugBridge.podspec 的 s.version）
# 2. commit 改动
# 3. git tag -a <版本> -m "Release <版本>"
# 4. git push origin main && git push origin <版本>   # 触发飞书通知
```

发布约束：

- 更新 Pod 代码时，必须同步更新 `LookDebugBridge.podspec` 的 `s.version`。
- Podspec 的 `s.version`、Git tag 和发布版本号必须完全一致；例如 tag 为 `0.1.12` 时，tag 指向的提交内 Podspec 必须也是 `0.1.12`。
- 创建 tag 前必须检查 `git show <版本>:LookDebugBridge.podspec`，确认 tag 内的 Podspec 版本与 tag 一致，避免 CocoaPods 解析出旧版本。
- 如果已发布的 tag 指向错误版本，必须先修正 Podspec、提交，再明确校正对应 tag，并清理使用方的 CocoaPods 外部依赖缓存后重新解析。

默认 webhook 地址内置于 `.githooks/pre-push`，可用环境变量 `LOOKDEBUG_LARK_WEBHOOK` 覆盖。
