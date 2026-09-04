// Shared between the app and the EmblaAlarmWidget extension: the Live
// Activity can only be drawn for an attributes type both sides agree on, and
// a LiveActivityIntent must exist in both so the button in the widget can run
// it in the app.

#if canImport(AlarmKit)
import AlarmKit
import AppIntents
import Foundation

@available(iOS 26.0, *)
struct EmblaAlarmMetadata: AlarmMetadata {
    /// The alarm's own id, so the widget can cancel it. Alarm state carries no
    /// id of its own.
    var alarmID: UUID
}

/// The stop button on the countdown Live Activity.
@available(iOS 26.0, *)
struct EmblaStopTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stöðva teljara"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Teljari")
    var alarmID: String

    init() {}

    init(alarmID: UUID) {
        self.alarmID = alarmID.uuidString
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            try AlarmManager.shared.cancel(id: id)
        }
        return .result()
    }
}
#endif
