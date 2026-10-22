import Foundation

public enum LookDebugElementType: String, Codable, Equatable {
    case button
    case `switch` = "switch"
    case cell
    case text
    case label
    case view
}
struct LookDebugElementMetadata: Codable, Equatable {
    let id: String
    let type: LookDebugElementType
    let label: String
    let enabled: Bool
}

struct LookDebugPagePayload: Codable, Equatable {
    let pageID: String
    let title: String
    let elements: [LookDebugElementMetadata]
}

struct LookDebugPingResponse: Codable, Equatable {
    let ok: Bool
}

/// /debug/identity 响应：用于 Mac 侧 preflight 校验目标 App 是否匹配预期
/// sessionID 是上下文标记（POST /debug/session 注入），不是并发隔离依据
struct LookDebugIdentityResponse: Codable, Equatable {
    let ok: Bool
    let bundleID: String
    let sessionID: String
    let port: UInt16
}

struct LookDebugTapRequest: Codable, Equatable {
    let id: String
    /// 重复点击次数，1...20，缺省 1
    let `repeat`: Int?
}

struct LookDebugTapResponse: Codable, Equatable {
    let success: Bool
    let id: String?
    /// 请求的重复次数（回显），缺省请求时为 1
    let `repeat`: Int?
    /// 实际成功触发的次数；success 仅在 invoked == repeat 时为 true
    let invoked: Int?
    let error: String?
}

/// POST /debug/scroll 请求：按 anchor 定位 UIScrollView 后滚动
/// - to: "top" | "bottom"，与 contentOffset / offsetDelta 互斥
/// - contentOffset: 绝对偏移
/// - offsetDelta: 相对当前偏移的增量
struct LookDebugScrollRequest: Codable, Equatable {
    let anchor: String
    let to: String?
    let contentOffset: LookDebugRuntimePoint?
    let offsetDelta: LookDebugRuntimePoint?
    let animated: Bool?
}

struct LookDebugScrollResponse: Codable, Equatable {
    let success: Bool
    let anchor: String?
    let contentOffset: LookDebugRuntimePoint?
    let contentSize: LookDebugRuntimeSize?
    let adjustedContentInset: LookDebugRuntimeInsets?
    let error: String?
}

struct LookDebugSwitchRequest: Codable, Equatable {
    let id: String
    let isOn: Bool
}

struct LookDebugSwitchResponse: Codable, Equatable {
    let success: Bool
    let id: String?
    let isOn: Bool?
    let error: String?
}

struct LookDebugTextRequest: Codable, Equatable {
    let id: String
    let text: String
}

struct LookDebugTextResponse: Codable, Equatable {
    let success: Bool
    let id: String?
    let text: String?
    let error: String?
    /// secure 字段时不回显明文，仅返回长度（兼容字段，旧调用方可忽略）
    let length: Int?
    /// secure 字段时为 true，标识响应已脱敏
    let redacted: Bool?

    init(success: Bool, id: String?, text: String?, error: String?, length: Int? = nil, redacted: Bool? = nil) {
        self.success = success
        self.id = id
        self.text = text
        self.error = error
        self.length = length
        self.redacted = redacted
    }
}

struct LookDebugRuntimeNodeRequest: Codable, Equatable {
    let anchor: String
}

struct LookDebugRuntimeRect: Codable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct LookDebugRuntimeSize: Codable, Equatable {
    let width: Double
    let height: Double
}

struct LookDebugRuntimePoint: Codable, Equatable {
    let x: Double
    let y: Double
}

struct LookDebugRuntimeInsets: Codable, Equatable {
    let top: Double
    let left: Double
    let bottom: Double
    let right: Double
}

struct LookDebugRuntimeColor: Codable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    let hex: String
}

struct LookDebugRuntimeNodeSummary: Codable, Equatable {
    let accessibilityIdentifier: String?
    let accessibilityLabel: String?
    let className: String
    let frameInWindow: LookDebugRuntimeRect
    let hidden: Bool
    let alpha: Double
}

struct LookDebugRuntimeNodeDetail: Codable, Equatable {
    let anchor: String
    let accessibilityIdentifier: String?
    let accessibilityLabel: String?
    let accessibilityValue: String?
    let className: String
    let classChain: [String]
    let frameInWindow: LookDebugRuntimeRect
    let bounds: LookDebugRuntimeRect
    let hidden: Bool
    let alpha: Double
    let userInteractionEnabled: Bool
    let backgroundColor: LookDebugRuntimeColor?
    let tintColor: LookDebugRuntimeColor?
    let contentMode: String
    let cornerRadius: Double
    let masksToBounds: Bool
    /// 视图旋转角度（度），由 transform 推导
    let rotationDegrees: Double
    /// layer.anchorPoint
    let anchorPoint: LookDebugRuntimePoint
    /// 已挂载的手势识别器数量
    let gestureCount: Int
    let borderWidth: Double
    let borderColor: LookDebugRuntimeColor?
    let shadowColor: LookDebugRuntimeColor?
    let shadowOpacity: Double
    let shadowRadius: Double
    let shadowOffset: LookDebugRuntimeSize
    let text: String?
    let placeholder: String?
    let fontName: String?
    let fontSize: Double?
    let textColor: LookDebugRuntimeColor?
    let textAlignment: String?
    let numberOfLines: Int?
    let imageAssetName: String?
    let imageSize: LookDebugRuntimeSize?
    let imageRenderingMode: String?
    let controlEnabled: Bool?
    let controlSelected: Bool?
    let controlHighlighted: Bool?
}

extension LookDebugRuntimeNodeDetail {
    /// 显式编码全部字段：不可用字段输出 null 而不是省略键。
    /// 这样 Mac 侧能区分「桥支持该字段但本节点不适用（null）」与「桥不支持该字段（键缺失）」。
    enum CodingKeys: String, CodingKey {
        case anchor
        case accessibilityIdentifier
        case accessibilityLabel
        case accessibilityValue
        case className
        case classChain
        case frameInWindow
        case bounds
        case hidden
        case alpha
        case userInteractionEnabled
        case backgroundColor
        case tintColor
        case contentMode
        case cornerRadius
        case masksToBounds
        case rotationDegrees
        case anchorPoint
        case gestureCount
        case borderWidth
        case borderColor
        case shadowColor
        case shadowOpacity
        case shadowRadius
        case shadowOffset
        case text
        case placeholder
        case fontName
        case fontSize
        case textColor
        case textAlignment
        case numberOfLines
        case imageAssetName
        case imageSize
        case imageRenderingMode
        case controlEnabled
        case controlSelected
        case controlHighlighted
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(anchor, forKey: .anchor)
        try container.encode(accessibilityIdentifier, forKey: .accessibilityIdentifier)
        try container.encode(accessibilityLabel, forKey: .accessibilityLabel)
        try container.encode(accessibilityValue, forKey: .accessibilityValue)
        try container.encode(className, forKey: .className)
        try container.encode(classChain, forKey: .classChain)
        try container.encode(frameInWindow, forKey: .frameInWindow)
        try container.encode(bounds, forKey: .bounds)
        try container.encode(hidden, forKey: .hidden)
        try container.encode(alpha, forKey: .alpha)
        try container.encode(userInteractionEnabled, forKey: .userInteractionEnabled)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encode(tintColor, forKey: .tintColor)
        try container.encode(contentMode, forKey: .contentMode)
        try container.encode(cornerRadius, forKey: .cornerRadius)
        try container.encode(masksToBounds, forKey: .masksToBounds)
        try container.encode(rotationDegrees, forKey: .rotationDegrees)
        try container.encode(anchorPoint, forKey: .anchorPoint)
        try container.encode(gestureCount, forKey: .gestureCount)
        try container.encode(borderWidth, forKey: .borderWidth)
        try container.encode(borderColor, forKey: .borderColor)
        try container.encode(shadowColor, forKey: .shadowColor)
        try container.encode(shadowOpacity, forKey: .shadowOpacity)
        try container.encode(shadowRadius, forKey: .shadowRadius)
        try container.encode(shadowOffset, forKey: .shadowOffset)
        try container.encode(text, forKey: .text)
        try container.encode(placeholder, forKey: .placeholder)
        try container.encode(fontName, forKey: .fontName)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(textColor, forKey: .textColor)
        try container.encode(textAlignment, forKey: .textAlignment)
        try container.encode(numberOfLines, forKey: .numberOfLines)
        try container.encode(imageAssetName, forKey: .imageAssetName)
        try container.encode(imageSize, forKey: .imageSize)
        try container.encode(imageRenderingMode, forKey: .imageRenderingMode)
        try container.encode(controlEnabled, forKey: .controlEnabled)
        try container.encode(controlSelected, forKey: .controlSelected)
        try container.encode(controlHighlighted, forKey: .controlHighlighted)
    }
}


struct LookDebugRuntimeNodeResponse: Codable, Equatable {
    let anchor: String
    let found: Bool
    let unique: Bool
    let matchCount: Int
    let node: LookDebugRuntimeNodeDetail?
    let matches: [LookDebugRuntimeNodeSummary]
    let error: String?
}

struct LookDebugWindowTreeNode: Codable, Equatable {
    let className: String
    let accessibilityIdentifier: String?
    let accessibilityLabel: String?
    let accessibilityValue: String?
    let frameInWindow: LookDebugRuntimeRect
    let hidden: Bool
    let alpha: Double
    let userInteractionEnabled: Bool
    let text: String?
    let children: [LookDebugWindowTreeNode]
}

struct LookDebugWindowTree: Codable, Equatable {
    let className: String
    let isKeyWindow: Bool
    let windowLevel: Double
    let hidden: Bool
    let frameInWindow: LookDebugRuntimeRect
    let root: LookDebugWindowTreeNode?
}

struct LookDebugWindowTreeResponse: Codable, Equatable {
    let success: Bool
    let windows: [LookDebugWindowTree]
    let truncated: Bool
    let error: String?
}

struct LookDebugErrorResponse: Codable, Equatable {
    let success: Bool
    let error: String
}

struct LookDebugSessionRequest: Codable, Equatable {
    let sessionID: String
}

struct LookDebugSessionResponse: Codable, Equatable {
    let success: Bool
    let sessionID: String
}

struct LookDebugHTTPResponse: Equatable {
    let statusCode: Int
    let body: Data
}
