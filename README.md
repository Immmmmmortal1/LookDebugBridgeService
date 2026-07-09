# LookDebugBridge

`LookDebugBridge` is a Debug-only iOS bridge for AI/script-driven UI inspection and control.

It exposes a small local HTTP API from the running Debug app:

```text
GET  /ping
GET  /debug/page
POST /debug/tap
POST /debug/switch
```

The bridge pairs well with LookinServer for visual hierarchy inspection, while this Pod provides semantic page IDs, stable element IDs, and safe action execution through existing UIKit controls.

## Podfile

Local development:

```ruby
target 'YourApp' do
  use_frameworks!

  pod 'LookDebugBridge',
      :path => '../LookDebugBridge',
      :configurations => ['Debug']
end
```

Git source:

```ruby
target 'YourApp' do
  use_frameworks!

  pod 'LookDebugBridge',
      :git => 'git@github.com:Immmmmmortal1/LookDebugBridge.git',
      :configurations => ['Debug']
end
```

`LookDebugBridge.podspec` depends on `LookinServer/Swift`.

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
