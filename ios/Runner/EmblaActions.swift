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
        EmblaLaunchClock.markLaunch()
    }

    /// Asks Dart to run one voice turn and waits for the result.
    ///
    /// Mirrors the embla-2.0 contract: always a dictionary with `action` of
    /// `done` or `none`, never a thrown error, so a shortcut can branch on it
    /// instead of dying mid-run.
    static func runVoiceTurn() async -> [String: Any] {
        guard let channel = channel else {
            return ["action": "none", "reason": "Embla er ekki tilbúin"]
        }
        return await withCheckedContinuation { (cont: CheckedContinuation<[String: Any], Never>) in
            let resumed = ResumeGuard()
            DispatchQueue.main.async {
                channel.invokeMethod("runVoiceTurn", arguments: nil) { value in
                    guard resumed.claim() else { return }
                    if let dict = value as? [String: Any] {
                        cont.resume(returning: dict)
                    } else {
                        cont.resume(returning: ["action": "none", "reason": "Ekkert svar frá Emblu"])
                    }
                }
            }
        }
    }

    /// Resuming a continuation twice traps, and a channel reply is not
    /// guaranteed to arrive exactly once.
    final class ResumeGuard {
        private var done = false
        private let l = NSLock()
        func claim() -> Bool {
            l.lock(); defer { l.unlock() }
            if done { return false }
            done = true
            return true
        }
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

        case "signalReady":
            EmblaLaunchClock.markReady()
            result(nil)

        case "addEvent":
            guard let title = title else {
                return result(invalidArgs("vantar title"))
            }
            guard let start = parseDate(args["start"] as? String) else {
                return result(invalidArgs("vantar eða ógilt start"))
            }
            let end = parseDate(args["end"] as? String) ?? start.addingTimeInterval(3600)
            addEvent(title: title, start: start, end: end,
                     notes: args["notes"] as? String,
                     location: args["location"] as? String,
                     result: result)

        case "addShopping":
            let items = (args["items"] as? [Any])?.compactMap { $0 as? String }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty } ?? []
            guard !items.isEmpty else {
                return result(invalidArgs("vantar items"))
            }
            let listName = (args["list"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? "Innkaupalisti"
            addShopping(items: items, list: listName, result: result)

        case "listAlarms":
            listAlarms(result: result)

        case "cancelAlarms":
            cancelAlarms(id: args["id"] as? String, result: result)

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

    /// Writes an event straight to the default calendar. Write-only access
    /// means the app can add events without being able to read the user's
    /// calendar, so the prompt is the narrow one.
    private static func addEvent(title: String, start: Date, end: Date,
                                 notes: String?, location: String?,
                                 result: @escaping FlutterResult) {
        let store = EKEventStore()
        requestCalendarWriteAccess(store) { granted, error in
            DispatchQueue.main.async {
                guard granted else {
                    return result(FlutterError(code: "permission_denied",
                                               message: "Aðgangur að dagatali ekki leyfður",
                                               details: error?.localizedDescription))
                }
                guard let calendar = store.defaultCalendarForNewEvents else {
                    return result(FlutterError(code: "save_failed",
                                               message: "Fann ekkert sjálfgefið dagatal",
                                               details: nil))
                }
                let event = EKEvent(eventStore: store)
                event.title = title
                event.startDate = start
                event.endDate = end
                event.calendar = calendar
                if let notes = notes, !notes.isEmpty { event.notes = notes }
                if let location = location, !location.isEmpty { event.location = location }
                do {
                    try store.save(event, span: .thisEvent, commit: true)
                    result(["calendar": calendar.title])
                } catch {
                    result(FlutterError(code: "save_failed",
                                        message: "Ekki tókst að vista viðburðinn",
                                        details: error.localizedDescription))
                }
            }
        }
    }

    private static func requestCalendarWriteAccess(_ store: EKEventStore,
                                                   _ completion: @escaping (Bool, Error?) -> Void) {
        if #available(iOS 17.0, *) {
            store.requestWriteOnlyAccessToEvents(completion: completion)
        } else {
            store.requestAccess(to: .event, completion: completion)
        }
    }

    /// Adds items to a named Reminders list, creating it if needed. Reminders
    /// is used because Notes has no public API for appending to a list.
    private static func addShopping(items: [String], list: String,
                                    result: @escaping FlutterResult) {
        let store = EKEventStore()
        requestRemindersAccess(store) { granted, error in
            DispatchQueue.main.async {
                guard granted else {
                    return result(FlutterError(code: "permission_denied",
                                               message: "Aðgangur að áminningum ekki leyfður",
                                               details: error?.localizedDescription))
                }
                let calendar: EKCalendar
                if let existing = store.calendars(for: .reminder).first(where: {
                    $0.title.compare(list, options: .caseInsensitive) == .orderedSame
                }) {
                    calendar = existing
                } else {
                    guard let source = store.defaultCalendarForNewReminders()?.source else {
                        return result(FlutterError(code: "save_failed",
                                                   message: "Fann engan áminningalista",
                                                   details: nil))
                    }
                    let created = EKCalendar(for: .reminder, eventStore: store)
                    created.title = list
                    created.source = source
                    do {
                        try store.saveCalendar(created, commit: true)
                    } catch {
                        return result(FlutterError(code: "save_failed",
                                                   message: "Ekki tókst að búa til listann „\(list)“",
                                                   details: error.localizedDescription))
                    }
                    calendar = created
                }
                do {
                    // One commit for the whole batch rather than per item.
                    for item in items {
                        let reminder = EKReminder(eventStore: store)
                        reminder.title = item
                        reminder.calendar = calendar
                        try store.save(reminder, commit: false)
                    }
                    try store.commit()
                    result(["count": items.count, "list": calendar.title])
                } catch {
                    result(FlutterError(code: "save_failed",
                                        message: "Ekki tókst að vista á innkaupalistann",
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

    // MARK: - Listing and cancelling timers/alarms

    private static func listAlarms(result: @escaping FlutterResult) {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            do {
                let alarms = try pendingAlarms()
                let known = labels()
                // Drop labels for alarms that no longer exist.
                let live = Set(alarms.map { $0.id.uuidString })
                forgetLabels(known.keys.filter { !live.contains($0) })
                result(alarms.map { describe($0, labels: known) })
            } catch {
                result(FlutterError(code: "alarm_failed",
                                    message: "Ekki tókst að lesa vekjara",
                                    details: error.localizedDescription))
            }
            return
        }
        #endif
        result(unsupported())
    }

    /// Cancels one alarm by id, or every pending alarm when `id` is nil.
    /// Returns the ids that were cancelled.
    private static func cancelAlarms(id: String?, result: @escaping FlutterResult) {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            do {
                let targets: [Alarm]
                if let id = id, let uuid = UUID(uuidString: id) {
                    targets = try pendingAlarms().filter { $0.id == uuid }
                } else if id != nil {
                    return result(invalidArgs("ógilt id"))
                } else {
                    targets = try pendingAlarms()
                }
                for alarm in targets {
                    try AlarmManager.shared.cancel(id: alarm.id)
                }
                let ids = targets.map { $0.id.uuidString }
                forgetLabels(ids)
                result(ids)
            } catch {
                result(FlutterError(code: "alarm_failed",
                                    message: "Ekki tókst að hætta við vekjara",
                                    details: error.localizedDescription))
            }
            return
        }
        #endif
        result(unsupported())
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
        let id = UUID()
        _ = try await AlarmManager.shared.schedule(id: id, configuration: config)
        // Alarm does not carry its attributes back out, so keep the spoken
        // label alongside the id in order to describe pending alarms later.
        rememberLabel(title, for: id)
    }

    // MARK: - Listing and cancelling

    /// id -> user-facing label, persisted so labels survive app restarts.
    private static let labelsKey = "embla.alarmLabels"

    private static func rememberLabel(_ label: String, for id: UUID) {
        var map = UserDefaults.standard.dictionary(forKey: labelsKey) as? [String: String] ?? [:]
        map[id.uuidString] = label
        UserDefaults.standard.set(map, forKey: labelsKey)
    }

    private static func labels() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: labelsKey) as? [String: String] ?? [:]
    }

    private static func forgetLabels(_ ids: [String]) {
        var map = labels()
        for id in ids { map.removeValue(forKey: id) }
        UserDefaults.standard.set(map, forKey: labelsKey)
    }

    @available(iOS 26.0, *)
    private static func pendingAlarms() throws -> [Alarm] {
        // Anything already fired or stopped is not something to cancel.
        try AlarmManager.shared.alarms.filter { $0.state != .alerting }
    }

    @available(iOS 26.0, *)
    private static func describe(_ alarm: Alarm, labels: [String: String]) -> [String: Any] {
        var info: [String: Any] = [
            "id": alarm.id.uuidString,
            "kind": alarm.countdownDuration != nil ? "timer" : "alarm",
        ]
        if let label = labels[alarm.id.uuidString] { info["title"] = label }
        return info
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

// MARK: - Launch timing and the Shortcuts entry point
//
// The Action Button runs a Shortcut, the Shortcut runs this intent, and the
// intent has to bring the app to the foreground because microphone capture
// cannot start from the background. In a native app that is instant. Here it
// also has to boot a Flutter engine and run main() before anything can
// listen, so the question this measures is whether the wait is short enough
// for the feature to be worth building.
@objc public class EmblaLaunchClock: NSObject {
    private static var launchedAt: Date?
    private static var readyAt: Date?
    private static var waiters: [(TimeInterval) -> Void] = []
    private static let lock = NSLock()

    /// Called from the plugin registrar, i.e. at app launch.
    @objc public static func markLaunch() {
        lock.lock(); defer { lock.unlock() }
        if launchedAt == nil { launchedAt = Date() }
    }

    /// Called from Dart once the app is actually able to take a command.
    @objc public static func markReady() {
        var toCall: [(TimeInterval) -> Void] = []
        lock.lock()
        if readyAt == nil { readyAt = Date() }
        let elapsed = readyAt!.timeIntervalSince(launchedAt ?? readyAt!)
        toCall = waiters
        waiters.removeAll()
        lock.unlock()
        for w in toCall { w(elapsed) }
    }

    /// Seconds from app launch to Dart being ready. Resolves immediately when
    /// the app was already running, which is the warm case.
    static func waitForReady(timeout: TimeInterval = 10) async -> TimeInterval? {
        lock.lock()
        if let readyAt = readyAt {
            let elapsed = readyAt.timeIntervalSince(launchedAt ?? readyAt)
            lock.unlock()
            return elapsed
        }
        lock.unlock()

        return await withCheckedContinuation { (cont: CheckedContinuation<TimeInterval?, Never>) in
            let resumed = ResumeOnce()
            lock.lock()
            waiters.append { elapsed in
                if resumed.claim() { cont.resume(returning: elapsed) }
            }
            lock.unlock()
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if resumed.claim() { cont.resume(returning: nil) }
            }
        }
    }

    /// Guards against a continuation being resumed twice, which traps.
    private final class ResumeOnce {
        private var done = false
        private let l = NSLock()
        func claim() -> Bool {
            l.lock(); defer { l.unlock() }
            if done { return false }
            done = true
            return true
        }
    }
}

#if canImport(AppIntents)
import AppIntents

/// Spike, not the finished feature: it reports the cold-start cost rather than
/// recording anything. App Intents need iOS 16; the app targets 15.
/// The Shortcuts entry point. Assign a shortcut running this to the Action
/// Button, or put it on the home screen.
@available(iOS 16.0, *)
struct InterpretCommandIntent: AppIntent {
    static var title: LocalizedStringResource = "Túlka raddskipun"
    static var description = IntentDescription(
        "Ræsir Emblu, hlustar á raddskipun og skilar niðurstöðunni.")

    // Microphone capture cannot start from the background, so the app has to
    // come forward. That also means the device must be unlocked.
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard await EmblaLaunchClock.waitForReady() != nil else {
            return Self.reply(["action": "none", "reason": "Embla ræsti ekki í tæka tíð"])
        }
        return Self.reply(await EmblaActions.runVoiceTurn())
    }

    /// Shortcuts gets the whole dictionary as JSON to branch on, and the user
    /// hears the one line that matters.
    private static func reply(_ dict: [String: Any])
        -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let spoken = (dict["speech"] as? String) ?? (dict["reason"] as? String) ?? ""
        let json = (try? JSONSerialization.data(withJSONObject: dict))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{\"action\":\"none\"}"
        return .result(value: json, dialog: IntentDialog(stringLiteral: spoken))
    }
}

@available(iOS 16.0, *)
struct EmblaLaunchProbeIntent: AppIntent {
    static var title: LocalizedStringResource = "Mæla ræsingu Emblu"
    static var description = IntentDescription(
        "Þróunartól: mælir hve lengi Embla er að verða tilbúin eftir ræsingu.")

    // Microphone capture cannot start from the background.
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let seconds = await EmblaLaunchClock.waitForReady() else {
            return .result(value: "Embla varð ekki tilbúin innan 10 s")
        }
        return .result(value: String(format: "Tilbúin á %.2f s", seconds))
    }
}
#endif
