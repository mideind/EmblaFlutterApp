// The countdown for a timer Embla set with AlarmKit, on the Lock Screen and in
// the Dynamic Island. AlarmKit alarms never appear in the Clock app, so this
// is where the user sees the timer and stops it.

import AlarmKit
import SwiftUI
import WidgetKit

private typealias EmblaAlarmContext = ActivityViewContext<AlarmAttributes<EmblaAlarmMetadata>>

struct EmblaAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<EmblaAlarmMetadata>.self) { context in
            HStack {
                VStack(alignment: .leading) {
                    Text(title(context)).font(.headline)
                    remaining(context).font(.title).monospacedDigit()
                }
                Spacer()
                stopButton(context)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(title(context)).font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    remaining(context).font(.title2).monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    stopButton(context)
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundStyle(context.attributes.tintColor)
            } compactTrailing: {
                remaining(context).monospacedDigit().frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(context.attributes.tintColor)
            }
            .keylineTint(context.attributes.tintColor)
        }
    }
}

private func title(_ context: EmblaAlarmContext) -> String {
    let presentation = context.attributes.presentation
    return String(localized: presentation.countdown?.title ?? presentation.alert.title)
}

@ViewBuilder
private func remaining(_ context: EmblaAlarmContext) -> some View {
    switch context.state.mode {
    case .countdown(let countdown):
        // A range with the lower bound past the upper traps, and the fire
        // date can slip behind the clock just as the alarm goes off.
        Text(timerInterval: min(Date.now, countdown.fireDate)...countdown.fireDate, countsDown: true)
    case .paused(let paused):
        Text(Duration.seconds(paused.totalCountdownDuration - paused.previouslyElapsedDuration)
            .formatted(.time(pattern: .minuteSecond)))
    case .alert:
        Text("Hringir")
    }
}

@ViewBuilder
private func stopButton(_ context: EmblaAlarmContext) -> some View {
    if let id = context.attributes.metadata?.alarmID {
        Button(intent: EmblaStopTimerIntent(alarmID: id)) {
            Label("Stöðva", systemImage: "stop.circle")
        }
        .tint(context.attributes.tintColor)
    }
}
