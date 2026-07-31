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
