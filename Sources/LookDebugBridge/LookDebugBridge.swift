import UIKit

@MainActor
public final class LookDebugBridge {
    public static let shared = LookDebugBridge()

    public nonisolated static let sessionID = {
        let environment = ProcessInfo.processInfo.environment
        if let value = environment["DEV_FLOW_SESSION_ID"], value.isEmpty == false {
            return value
        }
        if let value = environment["CODEX_THREAD_ID"], value.isEmpty == false {
            return value
        }
        if let value = environment["CURSOR_CONVERSATION_ID"], value.isEmpty == false {
            return value
        }
        return "local"
    }()

    /// 桥接服务对外状态：idle → starting → ready / failed；failed 可重试
    public enum State: Equatable {
        case idle
        case starting
        case ready
        case failed
    }

    private let server: LookDebugBridgeServer
    private var state: State = .idle

    public convenience init(port: UInt16 = 37777) {
        // 可选 token：环境变量 LOOKDEBUG_TOKEN 配置后所有接口需校验 X-LookDebug-Token
        // 未配置时全部放行（兼容模式，保持现有用户不受影响）
        let token = ProcessInfo.processInfo.environment["LOOKDEBUG_TOKEN"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedToken = (token?.isEmpty == false) ? token : nil
        self.init(server: LookDebugBridgeServer(port: port, token: normalizedToken))
    }

    public nonisolated static func log(
        _ message: String,
        level: String = "info",
        category: String = "app"
    ) {
        Task {
            await LookDebugLogStore.shared.append(
                level: level,
                category: category,
                message: message
            )
        }
    }

    init(server: LookDebugBridgeServer) {
        self.server = server
    }

    /// 当前桥接状态（只读）
    public var currentState: State { state }

    public func startIfNeeded() {
        // Release 构建：库内二道防线，调用方应已 #if DEBUG 包裹
        #if !DEBUG
        print("[LookDebugBridge] DEBUG-only, skipped")
        return
        #endif

        // 仅 idle / failed 状态可启动；ready / starting 直接返回避免重复
        guard state == .idle || state == .failed else { return }
        state = .starting

        LookDebugAccessibilityInstaller.installIfNeeded()
        do {
            try server.start(
                currentViewControllerProvider: { [weak self] in
                    self?.currentViewController()
                },
                onStateChange: { [weak self] serverState in
                    self?.handleServerState(serverState)
                }
            )
        } catch {
            state = .failed
            Self.log("LookDebugBridge failed to start: \(error)", level: "error", category: "bridge")
            #if DEBUG
            print("[LookDebugBridge] FAILED to start: \(error)")
            #endif
        }
    }

    /// 处理 NWListener 状态变化：.ready 才标记启动成功；.failed/.cancelled 允许重试
    /// 双重保险：即使 server 端漏过上报 cancelled，这里也确保 failed 状态不被覆盖
    private func handleServerState(_ serverState: LookDebugBridgeServer.State) {
        switch serverState {
        case .ready:
            // ready 不是终态，允许后续 failed
            state = .ready
            Self.log("LookDebugBridge ready", category: "bridge")
            #if DEBUG
            print("[LookDebugBridge] ready")
            #endif
        case .failed:
            // failed 是终态，稳定保持，允许 startIfNeeded 重试
            state = .failed
            #if DEBUG
            print("[LookDebugBridge] listener failed, can retry startIfNeeded")
            #endif
        case .cancelled:
            // cancelled 是终态；仅在未进入 failed 时回到 idle（允许重试）
            // server 端已用 reachedTerminalState 保证 failed 后不会上报 cancelled，此处为双重保险
            if state != .failed {
                state = .idle
            }
        case .idle, .starting:
            break
        }
    }

    private func currentViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        let keyWindow = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)

        return topViewController(from: keyWindow?.rootViewController)
    }

    private func topViewController(from viewController: UIViewController?) -> UIViewController? {
        if let presentedViewController = viewController?.presentedViewController {
            return topViewController(from: presentedViewController)
        }
        if let navigationController = viewController as? UINavigationController {
            return topViewController(from: navigationController.visibleViewController)
        }
        if let tabBarController = viewController as? UITabBarController {
            return topViewController(from: tabBarController.selectedViewController)
        }
        if shouldDescendIntoCustomContainer(viewController),
           let visibleChild = viewController?.children.reversed().first(where: { child in
            child.isViewLoaded && child.view.window != nil && !child.view.isHidden && child.view.alpha > 0.01
        }) {
            return topViewController(from: visibleChild)
        }
        return viewController
    }

    private func shouldDescendIntoCustomContainer(_ viewController: UIViewController?) -> Bool {
        guard let viewController else { return false }
        return String(describing: type(of: viewController)) == "SecureWindowController"
    }
}
