# LookDebugBridgeService

`LookDebugBridge` is a Debug-only iOS bridge for AI/script-driven UI inspection, control, and temporary App logs.

It exposes a small local HTTP API from the running Debug app:

```text
GET  /ping
GET  /debug/page
GET  /debug/windows
GET  /debug/logs
POST /debug/tap
POST /debug/switch
POST /debug/text/set
POST /debug/text/type
```

The bridge provides semantic page IDs, stable element IDs, UIWindow/UIView hierarchy inspection, safe UIKit actions, and an in-memory log pool. It does not depend on LookinServer.

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

默认 webhook 地址内置于 `.githooks/pre-push`，可用环境变量 `LOOKDEBUG_LARK_WEBHOOK` 覆盖。
