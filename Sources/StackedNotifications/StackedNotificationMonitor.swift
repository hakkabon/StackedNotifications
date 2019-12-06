//
//  StackedNotificationMonitor.swift
//  StackedNotifications
//
//  Created by Ulf Akerstedt-Inoue on 2018/04/10.
//  Copyright © 2018 hakkabon. All rights reserved.
//

import UIKit

/**
 * Global shared instance that manages the presentation and dismissal of notification views.
 * Presentation and dismissal of notifications are done in sequence in order to avoid cluttering
 * the screen with notifications that may come in random bursts.
 * The monitor object uses semaphores to manage presentation and dismissal logic. The objective
 * is to make sure sure that only one animation block happens at a time. The animation blocks
 * are essentially as follows:
 *    - Show notification block: show() ... didShow()
 *    - Hide notification block: hide() ... didHide().
 *
 * Note that it is essential that the semaphores are balanced for everything to work properly.
 */
@available(iOS 9.0, *)
class StackedNotificationMonitor : NSObject {
    // Keep track of all views being displayed.
    var allDisplayedViews = [StackedNotification]()
    
    // Use semaphores to make sure only one animation happens at a time. See comment above.
    let topPositionSemaphore = DispatchSemaphore(value: 1)
    let bottomPositionSemaphore = DispatchSemaphore(value: 1)

    // Queue used to enqueue display requests.
    let queue = DispatchQueue(label: "com.hakkabon.queue")
    
    struct Default {
        static let gap: CGFloat = 2
    }
    
    // Create and initialize one singleton monitor object.
    static let sharedManager : StackedNotificationMonitor = {
        let instance = StackedNotificationMonitor()
        return instance
    }()
    
    // Prevent using the default initializer for this class.
    private override init() {
    }
    
    public func notifications(in view: UIView) -> [StackedNotification] {
        return view.subviews.filter{ $0 is StackedNotification } as! [StackedNotification]
    }
    
    public func notification(with tag: Int, in view: UIView) -> [StackedNotification] {
        return view.subviews.filter{ $0 is StackedNotification && $0.tag == tag } as! [StackedNotification]
    }
    
    public func hideNotifications(in view: UIView) {
        let views = view.subviews.filter{ $0 is StackedNotification } as! [StackedNotification]
        for view in views {
            self.hide(notification: view, forced: false)
        }
    }
    
    public func hideAllNotifications() {
        for view in self.allDisplayedViews {
            self.hideNotifications(in: view)
        }
    }
    
    public func forceHideAllNotifications(in view: UIView) {
        for view in self.allDisplayedViews {
            self.hide(notification: view, forced: true)
        }
    }
}

@available(iOS 9.0, *)
extension StackedNotificationMonitor : StackedNotificationDelegate {
    
    // Tagged notifications are displayed one at a time regarding their asssigned tag number.
    func show(notification view: StackedNotification, hideAfter delay: TimeInterval) {
        if view.tag > 0 {
            // Check for identically tagged notifications being displayed.
            if notification(with: view.tag, in: view.superview!).count > 0 {
                // Only allow for one instance to be displayed at a time.
                return
            }
        }

        // Start show sequence of view.
        // Show sequence: [semaphore.wait] -> StackedNotification.showView -> StackedNotificationManager.willShow() ->
        // StackedNotification.pushView() ... -> didShow() [semaphore.signal]
        let task = DispatchWorkItem {
            DispatchQueue.global(qos: .default).async(execute: {() -> Void in
                let semaphore = view.options.position.isTop ? self.topPositionSemaphore : self.bottomPositionSemaphore
                _ = semaphore.wait(timeout: .distantFuture)
                DispatchQueue.main.sync(execute: {() -> Void in
                    view.showView()
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        view.hide()
                    }
                })
            })
        }
        queue.sync(execute: task)
    }
    
    func willShow(notification view: StackedNotification, in hostView: UIView) {
        // Keep track of all views we're displaying.
        if !self.allDisplayedViews.contains(view) {
            self.allDisplayedViews.append(view)
        }
        // Get stacked views displayed in this host view.
        let stackViews = hostView.subviews.filter{ $0 is StackedNotification && $0 != view } as! [StackedNotification]
        // And only views displayed in view (not the ones waiting to be displayed).
        let stackViewsToPush = stackViews.filter{
            $0.options.position == view.options.position &&
            $0.state != .hidden
        }
        for viewToPush in stackViewsToPush {
            viewToPush.pushView(view.frame.size.height + Default.gap, forward: true, delay: view.options.fadeInDuration)
        }
    }
    
    // Show notification block: show()  ... didShow() ends here.
    func didShow(notification view: StackedNotification, in hostView: UIView) {
        let semaphore = view.options.position.isTop ? self.topPositionSemaphore : self.bottomPositionSemaphore
        semaphore.signal()
    }
    
    func hide(notification view: StackedNotification) {
        self.hide(notification: view, forced: false)
    }
    
    func hide(notification view: StackedNotification, forced: Bool) {
        // Stop the recursive call chain here.
        if view.isScheduledToHide { return }
        if forced {
            view.shouldForceHide = true
            view.hide()
        } else {
            view.isScheduledToHide = true

            // Start hide sequence of view.
            // Hide sequence: StackedNotification.hide() -> StackedNotificationManager.hide() -> [semaphore.wait] ->
            // StackedNotificationManager.willHide() -> StackedNotification.pushView() ... -> didHide() [semaphore.signal]
            let task = DispatchWorkItem {
                DispatchQueue.global(qos: .default).async(execute: {() -> Void in
                    let semaphore = view.options.position.isTop ? self.topPositionSemaphore : self.bottomPositionSemaphore
                    _ = semaphore.wait(timeout: DispatchTime.distantFuture)
                    DispatchQueue.main.sync(execute: {() -> Void in
                        view.hideView()
                    })
                })
            }
            queue.sync(execute: task)
        }
    }
    
    func willHide(notification view: StackedNotification, in hostView: UIView) {
        let stackedViews = hostView.subviews.filter{ $0 is StackedNotification } as! [StackedNotification]
        let viewsInSamePosition = stackedViews.filter{ $0.options.position == view.options.position }
        if let index = viewsInSamePosition.firstIndex(of: view) {
            for i in 0 ..< index {
                viewsInSamePosition[i].pushView(-(view.frame.size.height + Default.gap), forward: false, delay: 0.0)
            }
        } else {
            if viewsInSamePosition.count > 1 {
            }
        }
    }
    
    // Hide notification block: hide()  ... didHide() ends here.
    func didHide(notification view: StackedNotification, in hostView: UIView) {
        if let index = self.allDisplayedViews.firstIndex(of: view) {
            self.allDisplayedViews.remove(at: index)
        }
        if !view.shouldForceHide {
        }
        let semaphore = view.options.position.isTop ? self.topPositionSemaphore : self.bottomPositionSemaphore
        semaphore.signal()
    }
}
