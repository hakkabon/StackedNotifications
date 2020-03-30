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
public protocol StackedNotificationDelegate {
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

    // Adjusts the max height of a notification view.
    var height: CGFloat { get }

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

    var width: CGFloat { return UIDevice.current.userInterfaceIdiom == .pad ? 360 : 300 }
    var height: CGFloat { return UIDevice.current.userInterfaceIdiom == .pad ? 200 : 190 }
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

    static var applicationWindow: UIWindow?

    private static var overlayWindow: UIWindow?
    private static var overlayViewController: OverlayViewController?

    /// The host view in which notifications views are displayed as subviews.
    public static var hostView: UIView? = {
        overlayViewController = OverlayViewController()
        guard let keyWindow = currentWindow else { fatalError("cannot retrive current window") }
        if #available(iOS 13.0, *) {
            overlayWindow = UIWindow(windowScene: keyWindow.windowScene!)
        } else {
            overlayWindow = UIWindow(frame: UIScreen.main.bounds)
        }
        applicationWindow = keyWindow
        overlayWindow?.windowLevel = UIWindow.Level.alert
        overlayWindow?.rootViewController = overlayViewController
        overlayWindow?.isHidden = false
        overlayWindow?.isUserInteractionEnabled = true
        return overlayViewController?.overlayView
    }()
    
    /// Specifies how notification views are dismissed.
    public enum ExitType : Int {
        case dequeue, pop, slide
    }

    /// Position on screen where notification view is displayed.
    /// Note that `topLeft`, `topRight`, `bottomLeft`, `bottomRight` are meant for iPad devices only.
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

    /// Display options for notifications views.
    var options: NotificationOptions!

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
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFit
        view.image = getAppIcon()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = Constants.cornerRadius * 0.5
        return view
    }()

    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: Constants.titleFontSize)
        label.lineBreakMode = .byTruncatingTail
        label.numberOfLines = 1
        label.textAlignment = .left
        label.textColor = UIColor.labelText
        label.sizeToFit()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    lazy var separator: SeparatorLine = {
        let view = SeparatorLine()
        view.thickness = 1
        view.color = .lightGray
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    lazy var message: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: Constants.detailFontSize)
        label.lineBreakMode = .byTruncatingTail
        label.numberOfLines = 0
        label.textAlignment = .left
        label.textColor = UIColor.labelText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let blurEffect = UIBlurEffect(style: blurEffectStyle())
    
    lazy var blurredView: UIVisualEffectView = {
        let effect = UIVisualEffectView(effect: blurEffect)
        effect.isUserInteractionEnabled = false
        effect.translatesAutoresizingMaskIntoConstraints = false
        return effect
    }()

    class func blurEffectStyle() -> UIBlurEffect.Style {
        if #available(iOS 13, *) {
            return .systemUltraThinMaterial
        } else {
            return .dark
        }
    }

    // Defines the internal display states.
    enum State : Int {
        case showing, hiding, movingForward, movingBackward, visible, hidden
    }
    var state: State = State.hidden
    var isScheduledToHide: Bool = false
    var shouldForceHide: Bool = false
    private let forceHideAnimationDuration = 0.1
    private var delegate: StackedNotificationDelegate?

    struct Constants {
        static var cornerRadius: CGFloat = 10
        static var titleHeight: CGFloat = 30
        static var minHeight: CGFloat = 100
        static var titleFontSize: CGFloat { return UIDevice.current.userInterfaceIdiom == .pad ? 20 : 18 }
        static var detailFontSize: CGFloat { return UIDevice.current.userInterfaceIdiom == .pad ? 18 : 17 }
        static var margin: CGFloat = 10

        static let showAnimation = "ShowAnimation"
        static let hideAnimation = "HideAnimation"
        static let moveAnimation = "MoveAnimation"
        static let propertyKey = "Animation"
    }

    private override init(frame: CGRect) {
        super.init(frame: frame)
        self.initializeUsingHostView(host: StackedNotification.hostView!)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.initializeUsingHostView(host: StackedNotification.hostView!)
    }
    
    public convenience init(title: String, message: String, options: NotificationOptions) {
        self.init(
            frame: CGRect(
                // temporary offscreen origin
                origin: CGPoint(x: options.position.isTop ? -400 : 0,
                                y: options.position.isTop ? -400 : UIScreen.main.bounds.height),
                size: CGSize(
                    width: options.width,
                    height: StackedNotification.adjustedHeight(for: message, constrained: options.width, maximumHeight: options.height)
                )
            )
        )

        guard let view = StackedNotification.hostView else {
            fatalError("Host view cannot be nil.")
        }

        self.options = options
        self.titleLabel.text = title
        self.message.text = message
        self.initializeUsingHostView(host: view)
        setupInitialFrame(for: self.options.position)
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
    
    func initializeUsingHostView(host view: UIView) {
        self.translatesAutoresizingMaskIntoConstraints = true
        self.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        self.isUserInteractionEnabled = true
        self.isHidden = false
        
        self.addSubview(outerStackView)
        innerStackView.addArrangedSubview(iconView)
        innerStackView.addArrangedSubview(titleLabel)
        outerStackView.addArrangedSubview(innerStackView)
        outerStackView.addArrangedSubview(separator)
        outerStackView.addArrangedSubview(message)
        
        self.insertSubview(blurredView, at: 0)

        // Add self as a subview in the hosting view.
        view.addSubview(self)

        // Setup delegate to manager (monitor) object.
        self.delegate = StackedNotificationMonitor.sharedManager
        self.state = .hidden
    }

    override public func updateConstraints() {
        NSLayoutConstraint.activate([
            outerStackView.topAnchor.constraint(equalTo: self.topAnchor, constant: Constants.margin),
            outerStackView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: Constants.margin),
            outerStackView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -Constants.margin),
            outerStackView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -Constants.margin),
        ])
        NSLayoutConstraint.activate([
            innerStackView.topAnchor.constraint(equalTo: outerStackView.topAnchor),
            innerStackView.leadingAnchor.constraint(equalTo: outerStackView.leadingAnchor),
            innerStackView.trailingAnchor.constraint(equalTo: outerStackView.trailingAnchor),
            innerStackView.heightAnchor.constraint(equalToConstant: Constants.titleHeight),
        ])

        NSLayoutConstraint.activate([   // aspect ratio 1:1
            iconView.widthAnchor.constraint(equalTo: iconView.heightAnchor, multiplier: 1)
        ])

        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: outerStackView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: outerStackView.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])

        NSLayoutConstraint.activate([
            blurredView.heightAnchor.constraint(equalTo: self.heightAnchor),
            blurredView.widthAnchor.constraint(equalTo: self.widthAnchor),
            blurredView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            blurredView.centerYAnchor.constraint(equalTo: self.centerYAnchor)
        ])

        iconView.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: .horizontal)
        iconView.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: .vertical)
        
        message.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: .horizontal)
        message.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: .vertical)
        
        super.updateConstraints()
    }
    
    override public func draw(_ rect: CGRect) {
        super.draw(rect)

        // Create rectangle with rounded corners to mask background.
        let rect = CGRect(origin: .zero, size: rect.size)
        let roundedRectanglePath = UIBezierPath(roundedRect: rect, cornerRadius: Constants.cornerRadius)

        let maskLayer = CAShapeLayer()
        maskLayer.frame = self.bounds
        maskLayer.path = roundedRectanglePath.cgPath
        self.layer.mask = maskLayer
        blurredView.layer.mask = maskLayer
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
        delayExecution(seconds: self.options.fadeInDuration) {
            let oldPoint = CGPoint(x: self.layer.position.x, y: self.layer.position.y)
            let x = oldPoint.x
            var y = oldPoint.y

            switch self.options.position {
            case .top, .topLeft, .topRight:
                y += self.bounds.size.height
                if #available(iOS 11.0, *) {
                    y += self.safeAreaInsets.top
                }
            case .bottom, .bottomLeft, .bottomRight:
                y -= self.bounds.size.height
                if #available(iOS 11.0, *) {
                    y -= self.safeAreaInsets.bottom
                }
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
            moveLayer.setValue(Constants.showAnimation, forKey: Constants.propertyKey)
            self.layer.add(moveLayer, forKey: Constants.showAnimation)
        }
    }
    
    /// Move the center of the notification to a new position in global coordinates.
    func hideView() {
        self.delegate?.willHide(notification: self, in: self.superview!)
        
        self.state = .hiding
        let oldPoint = self.layer.position
        var newPoint: CGPoint = .zero
        
        switch self.options.position {
        case .top, .topLeft, .topRight:
            switch self.options.exitType {
            case .dequeue:
                newPoint = CGPoint(x: oldPoint.x, y: self.superview!.bounds.size.height - self.bounds.height/2)
                if #available(iOS 11.0, *) {
                    newPoint.y -= self.safeAreaInsets.bottom
                }
            case .pop:
                newPoint = CGPoint(x: oldPoint.x, y: self.bounds.height/2)
                if #available(iOS 11.0, *) {
                    newPoint.y += self.safeAreaInsets.top
                }
            case .slide:
                newPoint = self.options.position == .topLeft ? CGPoint(x: -self.bounds.width, y: oldPoint.y) : CGPoint(x: self.superview!.bounds.width + self.bounds.width/2, y: oldPoint.y)
            }
        case .bottom, .bottomLeft, .bottomRight:
            switch self.options.exitType {
            case .dequeue:
                newPoint = CGPoint(x: oldPoint.x, y: self.bounds.height/2)
                if #available(iOS 11.0, *) {
                    newPoint.y += self.safeAreaInsets.top
                }
            case .pop:
                newPoint = CGPoint(x: oldPoint.x, y: self.superview!.bounds.size.height - self.bounds.height/2)
                if #available(iOS 11.0, *) {
                    newPoint.y -= self.safeAreaInsets.bottom
                }
            case .slide:
                    newPoint = self.options.position == .bottomLeft ? CGPoint(x: -self.bounds.width, y: oldPoint.y) : CGPoint(x: self.superview!.bounds.width + self.bounds.width/2, y: oldPoint.y)
            }
        }
        
        // Change center of layer.
        self.layer.position = newPoint
        
        // Animate change.
        let moveLayer = CABasicAnimation(keyPath: "position")
        moveLayer.fromValue = NSValue(cgPoint: oldPoint)
        moveLayer.toValue = NSValue(cgPoint: newPoint)
        moveLayer.duration = self.shouldForceHide ? self.forceHideAnimationDuration : self.options.hideAnimationDuration
        moveLayer.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)
        moveLayer.delegate = self
        moveLayer.setValue(Constants.hideAnimation, forKey: Constants.propertyKey)
        self.layer.add(moveLayer, forKey: Constants.hideAnimation)
    }
    
    func pushView(_ distance: CGFloat, forward: Bool, delay: Double) {
        self.state = forward ? .movingForward : .movingBackward
        let distanceToPush = self.options.position.isBottom ? -distance : distance

        // Change center of layer.
        let oldPoint = self.layer.position
        let newPoint = CGPoint(x: oldPoint.x, y: self.layer.position.y + distanceToPush)

        // Animate change.
        delayExecution(seconds: delay) {
            self.layer.position = newPoint // Assignment has to be delayed as well.
            let moveLayer = CABasicAnimation(keyPath: "position")
            moveLayer.fromValue = NSValue(cgPoint: oldPoint)
            moveLayer.toValue = NSValue(cgPoint: newPoint)
            moveLayer.duration = forward ? self.options.showAnimationDuration : self.options.hideAnimationDuration
            moveLayer.timingFunction = forward ? CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut) : CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)
            moveLayer.setValue(Constants.moveAnimation, forKey: Constants.propertyKey)
            moveLayer.delegate = self
            self.layer.add(moveLayer, forKey: Constants.moveAnimation)
        }
    }

    /// Adjust top left (x,y) coordinates according to position.
    private func setupInitialFrame(for position: Position) {
        let screen: CGSize = CGSize(width: self.superview!.bounds.width, height: self.superview!.bounds.size.height)
        let (x,y): (CGFloat,CGFloat) = {
            switch self.options.position {
            case .top: return((screen.width - self.frame.width) * 0.5, -self.frame.size.height)
            case .topLeft: return(Constants.margin, -self.frame.size.height)
            case .topRight: return (screen.width - self.frame.width - Constants.margin, -self.frame.size.height)
            case .bottom: return ((screen.width - self.frame.width) * 0.5, screen.height)
            case .bottomLeft: return (Constants.margin, screen.height)
            case .bottomRight: return (screen.width - frame.size.width - Constants.margin, screen.height)
            }
        }()
        self.frame = CGRect(origin: CGPoint(x:x,y:y), size: frame.size)
    }
}

@available(iOS 9.0, *)
extension StackedNotification : CAAnimationDelegate {
    
    /// CA animation stopped at this point.
    /// - Parameters:
    ///   - animation: reference to the animation
    ///   - flag: flag indicating completion of animation (which is always false)
    public func animationDidStop(_ animation: CAAnimation, finished flag: Bool) {
        let animationKind = animation.value(forKey: Constants.propertyKey) as! String

        // Show animation ended.
        if animationKind == Constants.showAnimation {
            self.delegate?.didShow(notification: self, in: self.superview!)
            self.state = .visible
        }
        // Hide animation ended.
        else if animationKind == Constants.hideAnimation {
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
        else if animationKind == Constants.moveAnimation {
            self.state = .visible
        }
    }
}

@available(iOS 9.0, *)
extension StackedNotification {

    /// Returns the app icon contained in the app bundle. Seems to be AppIcon60x60 which is returned.
    func getAppIcon() -> UIImage? {
        guard let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String:Any],
            let primaryIconsDictionary = iconsDictionary["CFBundlePrimaryIcon"] as? [String:Any],
            let iconFiles = primaryIconsDictionary["CFBundleIconFiles"] as? [String],
            let lastIcon = iconFiles.last else { return nil }
        return UIImage(named: lastIcon)
    }
    
    /// Adjust height of notification size depending on the amount of text, constraining width and max height.
    /// - Parameters:
    ///   - text: text for which the adjusted height is calculated
    ///   - width: maximum width
    /// - Note: Doesn't work well for iphones. The constant `4 * Constants.margin` is just made large enough
    ///         to work for iphones. On ipads, on the other hand, the bounding rectangle is too large, but
    ///         still not too bad.
    static func adjustedHeight(for text: String, constrained width: CGFloat, maximumHeight maxHeight: CGFloat) -> CGFloat {
        let rect = boundingRect(of: text, constraining: width - 2 * Constants.margin, font: UIFont.systemFont(ofSize: Constants.detailFontSize))
        var height = Constants.titleHeight + 1 + 4 * Constants.margin + rect.height

        // Clamp height value to [min ... max].
        height = height < Constants.minHeight ? Constants.minHeight : height
        height = height > maxHeight ? maxHeight : height
        
        return ceil(height)
    }

    /// Returns a bounding rectangle of given text and font constrained by the given width.
    /// - Parameters:
    ///   - text: text for which the bounding rect is calculated
    ///   - width: constraining width limit for bounding rect calculation
    ///   - font: font used for bounding rect calculation
    /// - Note: To render the string in multiple lines, specify `usesLineFragmentOrigin` in options.
    static func boundingRect(of text: String, constraining width: CGFloat, font: UIFont) -> CGRect {
        let limits = CGSize(width: width, height: .greatestFiniteMagnitude)
        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let rect = text.count == 0 ?
            CGRect(origin: .zero, size: CGSize(width: width, height: 0)) :
            text.boundingRect(with: limits, options: options, attributes: [NSAttributedString.Key.font: font], context: nil)
        return rect
    }

    /// Delay execution with the given amount in seconds.
    /// - Parameters:
    ///   - delay: Intended delay in seconds.
    ///   - closure: Block of code to be executed after the delay has expired.
    /// - Note: It dispatches execution on the main thread.
    func delayExecution(seconds delay: Double, closure: @escaping ()->()) {
        let when = DispatchTime.now() + delay
        DispatchQueue.main.asyncAfter(deadline: when, execute: closure)
    }
    
    /// Make the given color lighter.
    /// - Parameters:
    ///   - color: amount of change relative this color
    ///   - amount: amount of change to be applied, range of value: (0 < x < 1)
    func lighten(color: UIColor, amount: CGFloat = 0.25) ->  UIColor {
        return hue(color: color, with: 1 + amount)
    }
    
    /// Make the given color darker.
    /// - Parameters:
    ///   - color: amount of change relative this color
    ///   - amount: amount of change to be applied, range of value: (0 < x < 1)
    func darken(color: UIColor, amount: CGFloat = 0.25) ->  UIColor {
        return hue(color: color, with: 1 - amount)
    }
    
    /// Color transform given color with given amount of brightness (in per cent).
    /// - Parameters:
    ///   - color: amount of change relative this color
    ///   - amount: amount of change to be applied, range of value: (0 < x < 1)
    private func hue(color: UIColor, with amount: CGFloat) ->  UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        if color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return UIColor(hue: hue, saturation: saturation, brightness: brightness * amount, alpha: alpha)
        } else {
            return color
        }
    }
}

extension UIColor {
    static var labelText: UIColor {
        if #available(iOS 13, *) {
            return UIColor { (traitCollection: UITraitCollection) -> UIColor in
                return .label
            }
        } else {
            return UIColor.white
        }
    }
}

/// Current keyWindow
private var currentWindow: UIWindow? = {
    if #available(iOS 13.0, *) {
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        return windowScene?.windows.first
    } else {
        return UIApplication.shared.keyWindow
    }
}()
