import UIKit

enum LookDebugActionExecutorError: Error, Equatable {
    case elementNotFound
    case unsupportedElementType
    case notScrollable
}

/// 滚动执行结果：回填 Mac 侧做滚动断言所需的三个量
struct LookDebugScrollResult {
    let contentOffset: CGPoint
    let contentSize: CGSize
    let adjustedContentInset: UIEdgeInsets
}

@MainActor
struct LookDebugActionExecutor {
    let registry: LookDebugElementRegistry

    func validateTappable(id: String) throws {
        guard let entry = registry.entry(for: id),
              let view = entry.view else {
            throw LookDebugActionExecutorError.elementNotFound
        }
        if entry.hasTapAction {
            return
        }
        if view is UISwitch ||
            view is UICollectionViewCell ||
            view is UITableViewCell ||
            view is UIControl {
            return
        }
        throw LookDebugActionExecutorError.unsupportedElementType
    }

    func tap(id: String) throws {
        guard let entry = registry.entry(for: id),
              let view = entry.view else {
            throw LookDebugActionExecutorError.elementNotFound
        }

        if entry.performTapActionIfAvailable() {
            return
        }

        if let switchControl = view as? UISwitch {
            switchControl.setOn(!switchControl.isOn, animated: true)
            switchControl.sendActions(for: .valueChanged)
            return
        }

        if let collectionCell = view as? UICollectionViewCell,
           let collectionView = collectionCell.lookDebugSuperview(of: UICollectionView.self),
           let indexPath = collectionView.indexPath(for: collectionCell) {
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
            collectionView.delegate?.collectionView?(collectionView, didSelectItemAt: indexPath)
            return
        }

        if let tableCell = view as? UITableViewCell,
           let tableView = tableCell.lookDebugSuperview(of: UITableView.self),
           let indexPath = tableView.indexPath(for: tableCell) {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            tableView.delegate?.tableView?(tableView, didSelectRowAt: indexPath)
            return
        }

        guard let control = view as? UIControl else {
            throw LookDebugActionExecutorError.unsupportedElementType
        }

        if tapTabBarButton(control) {
            return
        }

        control.sendActions(for: .touchUpInside)
    }

    /// 按 anchor 定位 UIScrollView 并滚动，返回滚动后的偏移/内容尺寸/内边距。
    /// anchor 可以是 UIScrollView 本身，也可以是它的任意子视图（向上查找最近的 UIScrollView）。
    func scroll(
        id: String,
        to: String?,
        contentOffset: CGPoint?,
        offsetDelta: CGPoint?,
        animated: Bool
    ) throws -> LookDebugScrollResult {
        guard let entry = registry.entry(for: id),
              let view = entry.view else {
            throw LookDebugActionExecutorError.elementNotFound
        }
        guard let scrollView = scrollView(from: view) else {
            throw LookDebugActionExecutorError.notScrollable
        }

        let target: CGPoint
        if let contentOffset {
            target = clampedOffset(contentOffset, in: scrollView)
        } else if let offsetDelta {
            target = clampedOffset(
                CGPoint(
                    x: scrollView.contentOffset.x + offsetDelta.x,
                    y: scrollView.contentOffset.y + offsetDelta.y
                ),
                in: scrollView
            )
        } else {
            // 缺省按 to 处理；to 也为空时视为 top，避免静默无操作
            let maxY = maxOffsetY(in: scrollView)
            switch (to ?? "top").lowercased() {
            case "bottom": target = CGPoint(x: scrollView.contentOffset.x, y: maxY)
            case "top": target = CGPoint(x: scrollView.contentOffset.x, y: -scrollView.adjustedContentInset.top)
            default: throw LookDebugActionExecutorError.unsupportedElementType
            }
        }

        scrollView.setContentOffset(clampedOffset(target, in: scrollView), animated: animated)

        return LookDebugScrollResult(
            contentOffset: scrollView.contentOffset,
            contentSize: scrollView.contentSize,
            adjustedContentInset: scrollView.adjustedContentInset
        )
    }

    private func scrollView(from view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView { return scrollView }
        var current: UIView? = view.superview
        while let candidate = current {
            if let scrollView = candidate as? UIScrollView { return scrollView }
            current = candidate.superview
        }
        return nil
    }

    private func clampedOffset(_ offset: CGPoint, in scrollView: UIScrollView) -> CGPoint {
        let minX = -scrollView.adjustedContentInset.left
        let minY = -scrollView.adjustedContentInset.top
        let maxX = max(minX, scrollView.contentSize.width - scrollView.bounds.width + scrollView.adjustedContentInset.right)
        let maxY = max(minY, scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
        return CGPoint(
            x: min(max(offset.x, minX), maxX),
            y: min(max(offset.y, minY), maxY)
        )
    }

    private func maxOffsetY(in scrollView: UIScrollView) -> CGFloat {
        max(
            -scrollView.adjustedContentInset.top,
            scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        )
    }

    func setSwitch(id: String, isOn: Bool) throws {        guard let entry = registry.entry(for: id),
              let view = entry.view else {
            throw LookDebugActionExecutorError.elementNotFound
        }

        guard let switchControl = view as? UISwitch else {
            throw LookDebugActionExecutorError.unsupportedElementType
        }

        switchControl.setOn(isOn, animated: true)
        switchControl.sendActions(for: .valueChanged)
    }

    func setText(id: String, text: String, appending: Bool) throws -> (finalText: String, isSecure: Bool) {
        guard let entry = registry.entry(for: id),
              let view = entry.view else {
            throw LookDebugActionExecutorError.elementNotFound
        }

        if let textField = view as? UITextField {
            return try setTextFieldText(textField, text: text, appending: appending)
        }

        if let textView = view as? UITextView {
            return try setTextViewText(textView, text: text, appending: appending)
        }

        throw LookDebugActionExecutorError.unsupportedElementType
    }

    private func tappableView(id: String) throws -> UIView {
        guard let entry = registry.entry(for: id),
              let view = entry.view else {
            throw LookDebugActionExecutorError.elementNotFound
        }
        return view
    }

    private func setTextFieldText(_ textField: UITextField, text: String, appending: Bool) throws -> (finalText: String, isSecure: Bool) {
        let current = textField.text ?? ""
        let next = appending ? current + text : text
        let range = appending
            ? NSRange(location: (current as NSString).length, length: 0)
            : NSRange(location: 0, length: (current as NSString).length)

        if textField.delegate?.textField?(textField, shouldChangeCharactersIn: range, replacementString: text) == false {
            throw LookDebugActionExecutorError.unsupportedElementType
        }

        textField.becomeFirstResponder()
        textField.text = next
        // secure 字段不写明文到 accessibilityValue，写长度占位避免泄漏
        if textField.isSecureTextEntry {
            textField.accessibilityValue = next.isEmpty ? nil : String(repeating: "•", count: min(next.count, 64))
        } else {
            textField.accessibilityValue = next.isEmpty ? nil : next
        }
        textField.sendActions(for: .editingChanged)
        return (next, textField.isSecureTextEntry)
    }

    private func setTextViewText(_ textView: UITextView, text: String, appending: Bool) throws -> (finalText: String, isSecure: Bool) {
        let current = textView.text ?? ""
        let next = appending ? current + text : text
        let range = appending
            ? NSRange(location: (current as NSString).length, length: 0)
            : NSRange(location: 0, length: (current as NSString).length)

        if textView.delegate?.textView?(textView, shouldChangeTextIn: range, replacementText: text) == false {
            throw LookDebugActionExecutorError.unsupportedElementType
        }

        let isSecure = lookDebugIsSecureTextView(textView)
        textView.becomeFirstResponder()
        textView.text = next
        // secure 字段不写明文到 accessibilityValue，写长度占位避免泄漏
        if isSecure {
            textView.accessibilityValue = next.isEmpty ? nil : String(repeating: "•", count: min(next.count, 64))
        } else {
            textView.accessibilityValue = next.isEmpty ? nil : next
        }
        textView.delegate?.textViewDidChange?(textView)
        NotificationCenter.default.post(name: UITextView.textDidChangeNotification, object: textView)
        return (next, isSecure)
    }

    /// UITextView.isSecureTextEntry 是 iOS 17+ API，旧版本无该属性，用 #available 兼容
    private func lookDebugIsSecureTextView(_ textView: UITextView) -> Bool {
        if #available(iOS 17.0, *) {
            return textView.isSecureTextEntry
        }
        return false
    }

    private func tapTabBarButton(_ control: UIControl) -> Bool {
        guard let tabBar = control.lookDebugSuperview(of: UITabBar.self),
              let tabBarController = tabBar.lookDebugOwningViewController() as? UITabBarController else {
            return false
        }

        let buttons = tabBar.subviews
            .compactMap { $0 as? UIControl }
            .filter { !$0.isHidden && $0.alpha > 0.01 }
            .sorted { $0.frame.minX < $1.frame.minX }

        guard let index = buttons.firstIndex(where: { $0 === control }),
              let viewControllers = tabBarController.viewControllers,
              viewControllers.indices.contains(index) else {
            return false
        }

        let target = viewControllers[index]
        if tabBarController.delegate?.tabBarController?(tabBarController, shouldSelect: target) == false {
            return true
        }

        tabBarController.selectedIndex = index
        tabBarController.delegate?.tabBarController?(tabBarController, didSelect: target)
        return true
    }
}

private extension UIView {
    func lookDebugSuperview<T: UIView>(of type: T.Type) -> T? {
        var current = superview
        while let view = current {
            if let matched = view as? T {
                return matched
            }
            current = view.superview
        }
        return nil
    }

    func lookDebugOwningViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let viewController = current as? UIViewController {
                return viewController
            }
            responder = current.next
        }
        return nil
    }
}
