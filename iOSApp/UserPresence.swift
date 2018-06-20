//
//  UserPresence.swift
//  SoftU2F
//
//  Created by Benjamin P Toews on 1/27/17.
//

import Foundation

//class UserPresence: NSObject {
//    enum Notification {
//        case Register(facet: String?)
//        case Authenticate(facet: String?)
//    }
//
//    typealias Callback = (_ success: Bool) -> Void
//
//    static var skip = false
//
//    // Hacks to avoid a race between reads/writes to current.
//    static let currentAccessQueue = DispatchQueue(label: "currentAccessQueue")
//    static var _current: UserPresence?
//    static var current: UserPresence? {
//        get {
//            return currentAccessQueue.sync {
//                return _current
//            }
//        }
//
//        set(newValue) {
//            currentAccessQueue.sync {
//                _current = newValue
//            }
//        }
//    }
//
//    // Display a notification, wait for the user to click it, and call the callback with `true`.
//    // Calls callback with `false` if another test is done while we're waiting for this one.
//    static func test(_ type: Notification, skip skipOnce: Bool = false, with callback: @escaping Callback) {
//        if skip || skipOnce {
//            callback(true)
//        } else {
//            // Fail any outstanding test.
//            current?.complete(false)
//
//            // Backup previous delegate to restore on completion.
//            let delegateWas = NotificationCenter.default.delegate
//
//            let up = UserPresence { success in
//                NotificationCenter.default.delegate = delegateWas
//                callback(success)
//            }
//
//            current = up
//            NotificationCenter.default.delegate = up
//            up.test(type)
//        }
//    }
//
//    let callback: Callback
//    var notification: NSUserNotification?
//    var timer: Timer?
//    var timerStart: Date?
//
//    // Give up after 10 seconds.
//    var timedOut: Bool {
//        guard let ts = timerStart else { return false }
//        return Date().timeIntervalSince(ts) > 10
//    }
//
//    // Helper for accessing user notification center singleton.
//    var center: NotificationCenter { return NotificationCenter.default }
//
//    init(with cb: @escaping Callback) {
//        callback = cb
//        super.init()
//    }
//
//    // Send a notification popup to the user.
//    func test(_ type: Notification) {
//        sendNotification(type)
//    }
//
//    // Send a notification popup to the user.
//    func sendNotification(_ type: Notification) {
//        let n = NSUserNotification()
//        n.title = "Security Key Request"
//        n.actionButtonTitle = "Approve"
//        n.otherButtonTitle = "Reject"
//
//        switch type {
//        case let .Register(facet):
//            n.informativeText = "Register with " + (facet ?? "site")
//        case let .Authenticate(facet):
//            n.informativeText = "Authenticate with " + (facet ?? "site")
//        }
//
//        NotificationCenter.default.deliver(n)
//
//        notification = n
//    }
//
//    // Call the callback closure with our result and reset everything.
//    func complete(_ result: Bool) {
//        clearTimer()
//        removeNotification()
//        callback(result)
//        UserPresence.current = nil
//    }
//
//    // Stop showing the notification.
//    func removeNotification() {
//        guard let n = notification else { return }
//        center.removeDeliveredNotification(n)
//    }
//
//    // Install timer to check if user has dismissed notification.
//    func installTimer() {
//        timerStart = Date()
//
//        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
//            guard let n = self.notification else { return }
//
//            if self.timedOut {
//                // It's taken too long.
//                self.complete(false)
//            } else if let _ = self.center.deliveredNotifications.index(of: n) {
//                // User still viewing.
//            } else {
//                // User dismissed.
//                self.complete(false)
//            }
//        }
//    }
//
//    // Stop the timer.
//    func clearTimer() {
//        guard let t = timer else { return }
//        t.invalidate()
//    }
//}
//
//extension UserPresence: NotificationCenterDelegate {
//    func userNotificationCenter(_ center: NotificationCenter, didDeliver notification: NSUserNotification) {
//        if #available(OSX 10.13, *) {
//          // notification.isPresented is always false on the latest 10.13 beta.
//          installTimer()
//        } else {
//          if notification.isPresented {
//            // Alert is showing to user. Watch to see if it's dismissed.
//            installTimer()
//          } else {
//            // Alert wasn't shown to user. Fail.
//            complete(false)
//          }
//        }
//    }
//
//    func userNotificationCenter(_ center: NotificationCenter, didActivate notification: NSUserNotification) {
//        switch notification.activationType {
//        case .actionButtonClicked:
//            // User clicked "Accept".
//            complete(true)
//        default:
//            // User did something else.
//            complete(false)
//        }
//    }
//
//    func userNotificationCenter(_ center: NotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
//        // Present notification even if we're in foreground.
//        return true
//    }
//}
