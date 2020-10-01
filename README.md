# StackedNotifications

This package provides a local notification mechanism displaying simple messages in stacked views for iOS written in Swift. The messages can be positioned to appear at 6 different positions, top and bottom center, and the four corners of the screen. The messages appear on transparent background, like shown in the animation below.
![stacked notifications look like this](https://github.com/hakkabon/Assets/blob/master/notifications.gif)

## Import Statement
First, add an import statement to *StackedNotifications* like so:

```swift
import UIKit
import StackedNotifications
```

## Position and animation style
You probably want to customize your notifications depending on the device type being used:

```swift
struct iPadCustomOptions : NotificationOptions {
    var exitType: StackedNotification.ExitType { return StackedNotification.ExitType.slide }
    var position: StackedNotification.Position { return StackedNotification.Position.topRight }
}

struct iPhoneCustomOptions : NotificationOptions {
    var exitType: StackedNotification.ExitType { return StackedNotification.ExitType.pop }
    var position: StackedNotification.Position { return StackedNotification.Position.top }
}

let customOptions: NotificationOptions = UIDevice.current.userInterfaceIdiom == . pad ? iPadCustomOptions() : iPhoneCustomOptions()
```

## Display the notification
Display your notification where it is appropriate by using the `StackedNotification` API with the neccessary parameters supplied to . 

```swift
StackedNotification(title: "ERROR", message: "some meaningful error message", options: customOptions).show()
```

## Sample app
There is demo project available at [StackedNotifications-Demo ](https://github.com/hakkabon/StackedNotifications-Demo) with sample code explaining the use of the component.

## License
MIT
