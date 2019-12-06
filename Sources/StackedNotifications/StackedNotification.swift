//
//  StackedNotification.swift
//  StackedNotifications
//
//  Created by Ulf Akerstedt-Inoue on 2016/12/08.
//  Copyright © 2016 hakkabon. All rights reserved.
//

import UIKit
import Dispatch
import QuartzCore

@available(iOS 9.0, *)
protocol StackedNotificationDelegate {
    func show(notification view: StackedNotification, hideAfter delay: TimeInterval)
    func willShow(notification view: StackedNotification, in hostView: UIView)
    func didShow(notification view: StackedNotification, in hostView: UIView)
    func hide(notification view: StackedNotification, forced: Bool)
    func willHide(notification view: StackedNotification, in hostView: UIView)
    func didHide(notification view: StackedNotification, in hostView: UIView)
}

@available(iOS 9.0, *)
public protocol NotificationOptions {

    // Initial position of notification.
    var position: StackedNotification.Position { get }

    // Adjusts the width of a notification view.
    var width: CGFloat { get }
    
    // Specifies duration of fade-in animation of a notification.
    var fadeInDuration: Double { get }
    
    // Specifies duration of fade-out animation of a notification.
    var fadeOutDuration: Double { get }
    
    // Specifies duration of move-in-to-display-slot animation of a notification.
    var showAnimationDuration: Double { get }
    
    // Specifies duration of move-out-of-display-slot animation of a notification.
    var hideAnimationDuration: Double { get }
    
    // Specifies duration of display of a notification.
    var secondsToShow: Double { get }
    
    // Current opacity of notifier.
    var viewOpacity: CGFloat { get }
    
    // Allows for denying dismissal of notifier at tap event.
    var allowTapToDismiss: Bool { get }

    // Specifies how notification views are dismissed.
    var exitType: StackedNotification.ExitType { get }

    // Allows for specifying a code block for execution at tap event.
    var tappedBlock: ((StackedNotification) -> Void)?  { get }
}

@available(iOS 9.0, *)
public extension NotificationOptions {

    // Initial position of notification.
    var position: StackedNotification.Position { return StackedNotification.Position.top }

    // Adjusts the width of a notification view.
    var width: CGFloat {
        let width: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 360 : 300
        return width
    }
    var fadeInDuration: Double { return  0.25 }
    var fadeOutDuration: Double  { return  0.2 }
    var showAnimationDuration: Double { return  0.25 }
    var hideAnimationDuration: Double { return  0.2 }
    var secondsToShow: Double { return 10.0 }
    var viewOpacity: CGFloat { return 0.9 }
    var allowTapToDismiss: Bool  { return true }
    var exitType: StackedNotification.ExitType  { return StackedNotification.ExitType.pop }
    var tappedBlock: ((StackedNotification) -> Void)? { return nil }
}

/**
 * Displays an application-wide notification above all visible application views. The
 * notification may be aligned to the following upper parts of the screen:
 *    { top left | center top | top right }
 * or lower parts of the screen:
 *    { bottom left | center bottom | or bottom right }.
 *
 * Tagged notifications are displayed one at a time regarding their asssigned tag number.
 * This ensures that one notification instance is displayed only one at a time, to avoid
 * showing the same notification, possibly overlapping, more than once.
 *
 */
@available(iOS 9.0, *)
public class StackedNotification: UIView {

    public static var applicationWindow: UIWindow?

    private static var overlayWindow: UIWindow?
    private static var overlayViewController: OverlayViewController?

    // Host view in which notifications views are displayed as subviews.
    public static var hostView: UIView? = {
        overlayViewController = OverlayViewController()
        overlayWindow = UIWindow(frame: UIScreen.main.bounds)
        overlayWindow?.windowLevel = UIWindow.Level.alert
        overlayWindow?.rootViewController = overlayViewController
        overlayWindow?.isHidden = false
        overlayWindow?.isUserInteractionEnabled = true
        return overlayViewController?.overlayView
    }()

    // Type of stacked notifications.
    public enum NotifyType : Int {
        case success, failure, info, warning
        
        var backgroundColor: UIColor {
            switch self {
            case .success:
                return UIColor(red: 77/255.0, green: 175/255.0, blue: 67/255.0, alpha: 1.0)
            case .failure:
                return UIColor(red: 173/255.0, green: 48/255.0, blue: 48/255.0, alpha: 1.0)
            case .info:
                return UIColor(red: 48/255.0, green: 110/255.0, blue: 173/255.0, alpha: 1.0)
            case .warning:
                return UIColor(red: 215/255.0, green: 209/255.0, blue: 100/255.0, alpha: 1.0)
            }
        }

        var textColor: UIColor {
            switch self {
            case .success:
                return UIColor(white: CGFloat(1.0), alpha: CGFloat(0.9))
            case .failure:
                return UIColor(white: CGFloat(1.0), alpha: CGFloat(0.9))
            case .info:
                return UIColor(white: CGFloat(1.0), alpha: CGFloat(0.9))
            case .warning:
                return UIColor(red: 135/255, green: 84/255, blue: 26/255, alpha: 1)
            }
        }
    }
    
    // Specifies how notification views are dismissed.
    public enum ExitType : Int {
        case dequeue, pop
    }

    // Position on screen where notifier view is displayed.
    public enum Position : Int {
        case top, topLeft, topRight
        case bottom, bottomLeft, bottomRight
        
        var isTop: Bool {
            return self == .top || self == .topLeft || self == .topRight
        }
        var isBottom: Bool {
            return self == .bottom || self == .bottomLeft || self == .bottomRight
        }
    }

    // Display options for notifications views.
    var options: NotificationOptions!

    // Defines the internal display states.
    enum State : Int {
        case showing, hiding, movingForward, movingBackward, visible, hidden
    }
    var state: State = State.hidden
    var isScheduledToHide: Bool = false
    var shouldForceHide: Bool = false
    private var type: NotifyType = .info
    private let forceHideAnimationDuration = 0.1
    private var delegate: StackedNotificationDelegate?

    struct Default {
        static var width: CGFloat { return UIDevice.current.userInterfaceIdiom == .pad ? 360 : 300 }
        static var maxHeight: CGFloat { return UIDevice.current.userInterfaceIdiom == .pad ? 200 : 167 }
        static var minHeight: CGFloat { return UIDevice.current.userInterfaceIdiom == .pad ? 100 : 80 }
        static var panelHeight: CGFloat { return UIDevice.current.userInterfaceIdiom == .pad ? 30 : 30 }
        static var titleFontSize: CGFloat { return UIDevice.current.userInterfaceIdiom == .pad ? 20 : 18 }
        static var detailFontSize: CGFloat { return UIDevice.current.userInterfaceIdiom == .pad ? 18 : 17 }
        static var margin: CGFloat { return UIDevice.current.userInterfaceIdiom == .pad ? 10 : 10 }
        
        // Specifies names used for animations.
        static let showAnimation = "ShowAnimation"
        static let hideAnimation = "HideAnimation"
        static let moveAnimation = "MoveAnimation"
        static let propertyKey = "Animation"
    }

    lazy var outerStackView: UIStackView = {
        let view = UIStackView()
        view.axis = NSLayoutConstraint.Axis.vertical
        view.alignment = UIStackView.Alignment.fill
        view.distribution = UIStackView.Distribution.fill
        view.isUserInteractionEnabled = false
        view.spacing = 10
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    lazy var innerStackView: UIStackView = {
        let view = UIStackView()
        view.axis = NSLayoutConstraint.Axis.horizontal
        view.alignment = UIStackView.Alignment.center
        view.distribution = UIStackView.Distribution.fill
        view.isUserInteractionEnabled = false
        view.spacing = 10
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    lazy var iconView: UIImageView = {
        let view = UIImageView()
        view.backgroundColor = UIColor.clear
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFit
        view.image = getAppIcon()
        view.layer.cornerRadius = Default.margin
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = UIColor.clear
        label.font = UIFont.boldSystemFont(ofSize: Default.titleFontSize)
        label.isUserInteractionEnabled = false
        label.lineBreakMode = .byTruncatingTail
        label.numberOfLines = 1
        label.textAlignment = .left
        label.textColor = type.textColor
        label.sizeToFit()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    lazy var separator: SeparatorLine = {
        let view = SeparatorLine()
        view.thickness = 1
        view.color = darken(color: type.backgroundColor)
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = UIColor.clear
        label.font = UIFont.systemFont(ofSize: Default.detailFontSize)
        label.isUserInteractionEnabled = false
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .left
        label.textColor = type.textColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private override init(frame: CGRect) {
        super.init(frame: frame)
        self.initialization(host: StackedNotification.hostView!)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.initialization(host: StackedNotification.hostView!)
    }
    
    public convenience init(title: String, message: String, type: NotifyType, options: NotificationOptions) {
        self.init(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: options.width, height: StackedNotification.adjustedHeight(for: message, constrained: options.width))))

        guard let view = StackedNotification.hostView else {
            fatalError("Host view cannot be nil.")
        }

        self.options = options
        self.initialization(host: view)
        self.titleLabel.text = title
        self.messageLabel.text = message
        self.type = type
        setupInitalFrame(for: self.options.position)
    }
    
    // Returns an array of notifications within a certain view.
    public class func notifications(in view: UIView) -> [StackedNotification] {
        return StackedNotificationMonitor.sharedManager.notifications(in: view)
    }
    
    // Returns the notification with given tag within a certain view or nil if there is no match.
    public class func notification(with tag: Int, in view: UIView) -> [StackedNotification]? {
        return StackedNotificationMonitor.sharedManager.notification(with: tag, in: view)
    }
    
    // Immediately hides all notifications in all views, forgoing their secondsToShow values.
    public class func hideAllNotifications() {
        StackedNotificationMonitor.sharedManager.hideAllNotifications()
    }
    
    // Immediately hides all notifications in a certain view, forgoing their secondsToShow values.
    public class func hideNotifications(in view: UIView) {
        StackedNotificationMonitor.sharedManager.hideNotifications(in: view)
    }
    
    // Immediately force hide all notifications, forgoing their dismissal animations.
    // Call this in viewWillDisappear: of your view controller if necessary.
    public class func forceHideAllNotifications(in view: UIView) {
        StackedNotificationMonitor.sharedManager.forceHideAllNotifications(in: view)
    }
    
    public func show() {
        self.delegate?.show(notification: self, hideAfter: self.options.secondsToShow)
    }
    
    public func hide() {
        self.delegate?.hide(notification: self, forced: false)
    }
    
    func initialization(host view: UIView) {
        // Setup view.
        self.isUserInteractionEnabled = true
        self.translatesAutoresizingMaskIntoConstraints = true
        self.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        self.backgroundColor = UIColor.clear
        self.state = .hidden
        
        // Add subviews.
        view.addSubview(self)

        innerStackView.addArrangedSubview(iconView)
        innerStackView.addArrangedSubview(titleLabel)

        outerStackView.addArrangedSubview(innerStackView)
        outerStackView.addArrangedSubview(separator)
        outerStackView.addArrangedSubview(messageLabel)
        self.addSubview(outerStackView)

        // Setup delegate to manager (monitor) object.
        self.delegate = StackedNotificationMonitor.sharedManager
    }

    override public func updateConstraints() {
        NSLayoutConstraint.activate([
            innerStackView.topAnchor.constraint(equalTo: outerStackView.topAnchor),
            innerStackView.leadingAnchor.constraint(equalTo: outerStackView.leadingAnchor),
            innerStackView.trailingAnchor.constraint(equalTo: outerStackView.trailingAnchor),
            innerStackView.heightAnchor.constraint(equalToConstant: Default.panelHeight),
        ])
        
        NSLayoutConstraint.activate([
            outerStackView.topAnchor.constraint(equalTo: self.topAnchor, constant: 10),
            outerStackView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 10),
            outerStackView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -10),
            outerStackView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -10),
        ])

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalTo: iconView.heightAnchor, multiplier: 1)
        ])

        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: outerStackView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: outerStackView.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])

        iconView.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: .horizontal)
        iconView.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: .vertical)
        
        messageLabel.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: .horizontal)
        messageLabel.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: .vertical)
        
        super.updateConstraints()
    }

    override public func draw(_ rect: CGRect) {
        super.draw(rect)
        
        // Hasn't got its real value yet!
        self.separator.color = darken(color: type.backgroundColor)
        
        // Get the current graphics context.
        let context = UIGraphicsGetCurrentContext()!
        
        // Save the previous graphics state and make the specified context the current context.
        UIGraphicsPushContext(context)
        
        // Make the painting area just a tiny bit smaller.
        // let rect = CGRect(origin: CGPoint.zero, size: rect.size)
        let rect = CGRect(origin: CGPoint.zero, size: rect.size)
        let roundedRectanglePath = UIBezierPath(roundedRect: rect, cornerRadius: Default.margin)
        roundedRectanglePath.addClip()
        let colorsArray = [type.backgroundColor.cgColor, darken(color: type.backgroundColor).cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colorsArray as CFArray, locations: [0.0, 1.0])
        context.drawLinearGradient(gradient!, start: CGPoint.zero, end: CGPoint(x: 0.0, y: self.bounds.size.height),
                                   options: .drawsBeforeStartLocation)
        
        // Balance call to UIGraphicsPushContext, restore to previous state.
        UIGraphicsPopContext()
    }

    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard self.state == .visible else { return }
        self.options.tappedBlock?(self)
        if self.options.allowTapToDismiss {
            self.delegate?.hide(notification: self, forced: false)
        }
    }

    func showView() {
        self.delegate?.willShow(notification: self, in: self.superview!)
        self.state = .showing

        self.alpha = self.options.viewOpacity
        delayExecution(deadline: self.options.fadeInDuration) {
            let oldPoint = CGPoint(x: self.layer.position.x, y: self.layer.position.y)
            let x = oldPoint.x
            var y = oldPoint.y

            switch self.options.position {
            case .top, .topLeft, .topRight:
                y += self.bounds.size.height
            case .bottom, .bottomLeft, .bottomRight:
                y -= self.bounds.size.height
            }
            
            // Change center of layer.
            let newPoint = CGPoint(x:x, y:y)
            self.layer.position = newPoint
            
            // Animate change.
            let moveLayer = CABasicAnimation(keyPath: "position")
            moveLayer.fromValue = NSValue(cgPoint: oldPoint)
            moveLayer.toValue = NSValue(cgPoint: newPoint)
            moveLayer.duration = self.options.showAnimationDuration
            moveLayer.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
            moveLayer.delegate = self
            moveLayer.setValue(Default.showAnimation, forKey:Default.propertyKey)
            self.layer.add(moveLayer, forKey: Default.showAnimation)
        }
    }
    
    func hideView() {
        self.delegate?.willHide(notification: self, in: self.superview!)
        
        self.state = .hiding
        let oldPoint = self.layer.position
        let x: CGFloat = oldPoint.x
        var y: CGFloat = oldPoint.y
        switch self.options.position {
        case .top, .topLeft, .topRight:
            y = self.options.exitType == .dequeue ? self.superview!.bounds.size.height - self.bounds.height/2 : self.bounds.height/2
        case .bottom, .bottomLeft, .bottomRight:
            y = self.options.exitType == .dequeue ? self.bounds.height/2 : self.superview!.bounds.size.height - self.bounds.height/2
        }
        
        // Change center of layer.
        let newPoint = CGPoint(x: x, y: y)
        self.layer.position = newPoint
        
        // Animate change.
        let moveLayer = CABasicAnimation(keyPath: "position")
        moveLayer.fromValue = NSValue(cgPoint: oldPoint)
        moveLayer.toValue = NSValue(cgPoint: newPoint)
        moveLayer.duration = self.shouldForceHide ? self.forceHideAnimationDuration : self.options.hideAnimationDuration
        moveLayer.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)
        moveLayer.delegate = self
        moveLayer.setValue(Default.hideAnimation, forKey: Default.propertyKey)
        self.layer.add(moveLayer, forKey: Default.hideAnimation)
    }
    
    func pushView(_ distance: CGFloat, forward: Bool, delay: Double) {
        self.state = forward ? .movingForward : .movingBackward
        let distanceToPush = self.options.position.isBottom ? -distance : distance

        // Change center of layer.
        let oldPoint = self.layer.position
        let newPoint = CGPoint(x: oldPoint.x, y: self.layer.position.y + distanceToPush)

        // Animate change.
        delayExecution(deadline: delay) {
            self.layer.position = newPoint // Assignment has to be delayed as well.
            let moveLayer = CABasicAnimation(keyPath: "position")
            moveLayer.fromValue = NSValue(cgPoint: oldPoint)
            moveLayer.toValue = NSValue(cgPoint: newPoint)
            moveLayer.duration = forward ? self.options.showAnimationDuration : self.options.hideAnimationDuration
            moveLayer.timingFunction = forward ? CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut) : CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)
            moveLayer.setValue(Default.moveAnimation, forKey: Default.propertyKey)
            moveLayer.delegate = self
            self.layer.add(moveLayer, forKey: Default.moveAnimation)
        }
    }

    // Adjust top left (x,y) coordinates according to position.
    private func setupInitalFrame(for position: Position) {
        var frame = self.frame
        var p: CGPoint = CGPoint.zero
        
        switch self.options.position {
        case .top:
            p.x = self.superview!.bounds.size.width / 2 - frame.size.width / 2
            p.y -= frame.size.height
        case .topLeft:
            p.x = frame.size.width
            p.y -= frame.size.height
        case .topRight:
            p.x = self.superview!.bounds.size.width - frame.size.width
            p.y -= frame.size.height
        case .bottom:
            p.x = self.superview!.bounds.size.width / 2 - frame.size.width / 2
            p.y = self.superview!.bounds.size.height
        case .bottomLeft:
            p.x = 0
            p.y = self.superview!.bounds.size.height
        case .bottomRight:
            p.x = self.superview!.bounds.size.width - frame.size.width
            p.y = self.superview!.bounds.size.height
        }
        frame.origin = p
        self.frame = frame
    }
    
    private func gradientSetup() -> CGGradient? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let border = type.backgroundColor.withAlphaComponent(0.6)
        let topColor = lighten(color: border, amount: 0.37)
        let midColor = lighten(color: border, amount: 0.1)
        let bottomColor = lighten(color: border, amount: 0.12)
        let newGradientColors = [topColor.cgColor, midColor.cgColor, border.cgColor, border.cgColor, bottomColor.cgColor] as CFArray
        return CGGradient(colorsSpace: colorSpace, colors: newGradientColors, locations: [0, 0.500, 0.501, 0.66, 1])
    }
}

@available(iOS 9.0, *)
extension StackedNotification : CAAnimationDelegate {
    
    // Swift 3 issue: finished flag always false here
    public func animationDidStop(_ animation: CAAnimation, finished flag: Bool) {
        // Show animation ended.
        if ((animation.value(forKey: Default.propertyKey) as! String) == Default.showAnimation) {
            self.delegate?.didShow(notification: self, in: self.superview!)
            self.state = .visible
        }
        // Hide animation ended.
        else if ((animation.value(forKey: Default.propertyKey) as! String) == Default.hideAnimation) {
            UIView.animate(withDuration: self.shouldForceHide ? self.forceHideAnimationDuration : self.options.fadeOutDuration, delay: 0.0, options: .curveLinear, animations: {() -> Void in
                self.alpha = 0.0
            }, completion: {(_ finished: Bool) -> Void in
                self.state = .hidden
                self.delegate?.didHide(notification: self, in: self.superview!)
                NotificationCenter.default.removeObserver(self)
                self.removeFromSuperview()
            })
        }
        // Move animation ended.
        else if ((animation.value(forKey: Default.propertyKey) as! String) == Default.moveAnimation) {
            self.state = .visible
        }
    }
}

@available(iOS 9.0, *)
extension StackedNotification {

    // Seems to be AppIcon60x60 which is returned.
    func getAppIcon() -> UIImage? {
        guard let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String:Any],
            let primaryIconsDictionary = iconsDictionary["CFBundlePrimaryIcon"] as? [String:Any],
            let iconFiles = primaryIconsDictionary["CFBundleIconFiles"] as? [String],
            let lastIcon = iconFiles.last else { return nil }
        return UIImage(named: lastIcon)
    }
    
    static func adjustedHeight(for text: String, constrained width: CGFloat) -> CGFloat {
        let rect = boundingRect(of: text, constrained: width, font: UIFont.boldSystemFont(ofSize: Default.detailFontSize))
        var height = Default.panelHeight + 1 + rect.height
        // Clamp height value to [min ... max].
        height = height < Default.minHeight ? Default.minHeight : height
        return height < Default.maxHeight ? height : Default.maxHeight
    }

    // Returns a bounding rectangle of given text and font contrained by the given width.
    static func boundingRect(of text: String, constrained width: CGFloat, font: UIFont) -> CGRect {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let rect = text.count == 0 ?
            "Abc".boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: font], context: nil) :
            text.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: font], context: nil)
        return rect
    }

    /// Note that it executes on the main thread.
    /// - Parameters:
    ///   - delay: Intended delay in seconds.
    ///   - closure: Block of code to be executed after the delay has expired.
    func delayExecution(deadline delay: Double, closure: @escaping ()->()) {
        let when = DispatchTime.now() + delay
        DispatchQueue.main.asyncAfter(deadline: when, execute: closure)
    }
    
    /// Returns an initialized UIColor object corresponding to the given hex string.
    /// - Parameters:
    ///   - hex: String which specifies a color given in hexadecimal string format, example: "#d3d3d3".
    /// - Returns: The initialized UIColor object.
    func color(hex: String) -> UIColor {
        var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if cString.hasPrefix("#") {
            cString.remove(at: cString.startIndex)
        }
        
        if cString.count != 6 {
            return UIColor.gray
        }
        
        var rgbValue:UInt32 = 0
        Scanner(string: cString).scanHexInt32(&rgbValue)
        
        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
    
    func lighten(color: UIColor, amount: CGFloat = 0.25) ->  UIColor {
        return hue(color: color, with: 1 + amount)
    }
    
    func darken(color: UIColor, amount: CGFloat = 0.25) ->  UIColor {
        return hue(color: color, with: 1 - amount)
    }
    
    private func hue(color: UIColor, with amount: CGFloat) ->  UIColor {
        var hue         : CGFloat = 0
        var saturation  : CGFloat = 0
        var brightness  : CGFloat = 0
        var alpha       : CGFloat = 0
        
        if color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return UIColor(hue: hue, saturation: saturation, brightness: brightness * amount, alpha: alpha)
        } else {
            return color
        }
    }
}
