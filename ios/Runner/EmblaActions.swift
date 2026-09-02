/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2026 Miðeind ehf. <mideind@mideind.is>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

// Native side of the `is.mideind.embla/actions` method channel: the device
// actions that have no Flutter plugin. Ported from the embla-2.0 Swift MVP
// (LocalActions.swift).
//
//   addReminder { title: String, due: String? }   EventKit reminder
//   setTimer    { seconds: Int, title: String? }  AlarmKit countdown
//   setAlarm    { start: String, title: String? } AlarmKit alarm
//
// Dates are ISO 8601 local times without an offset, e.g. 2026-08-24T14:00:00.
// Errors are returned as FlutterError; the code `unsupported` means the OS is
// too old for the underlying API, which the Dart side turns into an Icelandic
// explanation. AlarmKit only exists from iOS 26 on and only in the iOS 26 SDK,
// hence both the `canImport` and the `available` guards.

import EventKit
import Flutter
import Foundation

#if canImport(AlarmKit)
import AlarmKit
import SwiftUI
#endif

#if canImport(AlarmKit)
@available(iOS 26.0, *)
private struct EmblaAlarmMetadata: AlarmMetadata {}
#endif

@objc public class EmblaActions: NSObject {

    private static let channelName = "is.mideind.embla/actions"

    // The messenger only holds the handler weakly through the channel, so the
    // channel has to stay alive for the lifetime of the app.
    private static var channel: FlutterMethodChannel?

    /// Called from AppDelegate.m with `[self registrarForPlugin:@"EmblaActions"]`.
    @objc public static func register(withRegistrar registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName,
                                           binaryMessenger: registrar.messenger())
        channel.setMethodCallHandler { call, result in
            handle(call, result)
        }
        self.channel = channel
    }

    // MARK: - Dispatch

    private static func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        let title = (args["title"] as? String).flatMap { $0.isEmpty ? nil : $0 }

        switch call.method {
        case "addReminder":
            guard let title = title else {
                return result(invalidArgs("vantar title"))
            }
            addReminder(title: title, due: parseDate(args["due"] as? String), result: result)

        case "setTimer":
            guard let seconds = (args["seconds"] as? NSNumber)?.doubleValue, seconds > 0 else {
                return result(invalidArgs("vantar seconds"))
            }
            scheduleAlarm(timer: seconds, fixed: nil, title: title ?? "Teljari", result: result)

        case "setAlarm":
            guard let start = parseDate(args["start"] as? String) else {
                return result(invalidArgs("vantar eða ógilt start"))
            }
            scheduleAlarm(timer: nil, fixed: start, title: title ?? "Vekjari", result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Reminders (EventKit)

    private static func addReminder(title: String, due: Date?, result: @escaping FlutterResult) {
        let store = EKEventStore()
        requestRemindersAccess(store) { granted, error in
            DispatchQueue.main.async {
                guard granted else {
                    return result(FlutterError(code: "permission_denied",
                                               message: "Aðgangur að áminningum ekki leyfður",
                                               details: error?.localizedDescription))
                }
                let reminder = EKReminder(eventStore: store)
                reminder.title = title
                reminder.calendar = store.defaultCalendarForNewReminders()
                if let due = due {
                    reminder.dueDateComponents = Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute], from: due)
                    reminder.addAlarm(EKAlarm(absoluteDate: due))
                }
                do {
                    try store.save(reminder, commit: true)
                    result(nil)
                } catch {
                    result(FlutterError(code: "save_failed",
                                        message: "Ekki tókst að vista áminninguna",
                                        details: error.localizedDescription))
                }
            }
        }
    }

    private static func requestRemindersAccess(_ store: EKEventStore,
                                               _ completion: @escaping (Bool, Error?) -> Void) {
        if #available(iOS 17.0, *) {
            store.requestFullAccessToReminders(completion: completion)
        } else {
            store.requestAccess(to: .reminder, completion: completion)
        }
    }

    // MARK: - Timers and alarms (AlarmKit, iOS 26+)

    private static func scheduleAlarm(timer seconds: Double?, fixed date: Date?,
                                      title: String, result: @escaping FlutterResult) {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            Task {
                do {
                    try await schedule(timer: seconds, fixed: date, title: title)
                    await MainActor.run { result(nil) }
                } catch let error as AlarmScheduleError {
                    await MainActor.run { result(error.flutterError) }
                } catch {
                    await MainActor.run {
                        result(FlutterError(code: "alarm_failed",
                                            message: "Ekki tókst að stilla vekjarann",
                                            details: error.localizedDescription))
                    }
                }
            }
            return
        }
        #endif
        result(unsupported())
    }

    #if canImport(AlarmKit)
    // ponytail: no countdown Live Activity (that needs a widget extension);
    // the alert itself still fires.
    @available(iOS 26.0, *)
    private static func schedule(timer seconds: Double?, fixed date: Date?, title: String) async throws {
        guard try await AlarmManager.shared.requestAuthorization() == .authorized else {
            throw AlarmScheduleError.notAuthorized
        }
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: title),
            stopButton: AlarmButton(text: "Stöðva", textColor: .white, systemImageName: "stop.circle"))
        let attributes = AlarmAttributes<EmblaAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert), tintColor: .orange)
        let config: AlarmManager.AlarmConfiguration<EmblaAlarmMetadata>
        if let seconds = seconds {
            config = .timer(duration: seconds, attributes: attributes)
        } else if let date = date {
            config = .alarm(schedule: .fixed(date), attributes: attributes)
        } else {
            throw AlarmScheduleError.notAuthorized
        }
        _ = try await AlarmManager.shared.schedule(id: UUID(), configuration: config)
    }

    private enum AlarmScheduleError: Error {
        case notAuthorized

        var flutterError: FlutterError {
            FlutterError(code: "permission_denied",
                         message: "Aðgangur að vekjurum ekki leyfður",
                         details: nil)
        }
    }
    #endif

    // MARK: - Helpers

    private static func parseDate(_ s: String?) -> Date? {
        guard let s = s, !s.isEmpty else { return nil }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return df.date(from: s)
    }

    private static func invalidArgs(_ reason: String) -> FlutterError {
        FlutterError(code: "invalid_args", message: reason, details: nil)
    }

    private static func unsupported() -> FlutterError {
        FlutterError(code: "unsupported",
                     message: "Vekjarar og teljarar krefjast iOS 26",
                     details: nil)
    }
}
