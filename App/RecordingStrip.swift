import SwiftUI

/// This row has the same layout before, during and after recording.
/// Only RecordingReadout subscribes to the frequently changing activity.
struct RecordingStrip: View {
    @ObservedObject var audio: PageAudio
    let action: () -> Void
    @ScaledMetric(relativeTo: .caption2) private var actionWidth: CGFloat = 72

    var body: some View {
        HStack(spacing: 12) {
            WorkspaceAction(title: audio.recording ? "إيقاف" : "تسجيل",
                            symbol: audio.recording ? "stop.circle" : "mic",
                            selected: audio.recording, action: action)
                .disabled(audio.requestingPermission)
                .frame(width: actionWidth)
                .accessibilityIdentifier("recordLinkedAudio")
                .accessibilityValue(audio.recording ? "جارٍ التسجيل" : audio.requestingPermission ? "انتظار إذن الميكروفون" : "متوقف")
            RecordingReadout(activity: audio.activity, recording: audio.recording, waiting: audio.requestingPermission)
        }
        .padding(.horizontal, 12).padding(.vertical, 3)
        .background(TayyaTheme.mutedSurface)
        .overlay(alignment: .bottom) { TayyaTheme.separator.frame(height: 1).allowsHitTesting(false) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recordingStrip")
    }
}

private struct RecordingReadout: View {
    @ObservedObject var activity: RecordingActivity
    let recording: Bool
    let waiting: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var rowHeight: CGFloat = 44
    @ScaledMetric(relativeTo: .caption) private var timeWidth: CGFloat = 72

    private var status: String {
        recording ? "جارٍ التسجيل" : waiting ? "انتظار إذن الميكروفون" : "تسجيل مرتبط بالكتابة"
    }
    private var duration: String {
        let seconds = Int(activity.elapsed)
        if seconds >= 3600 {
            return String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
        }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if dynamicTypeSize.isAccessibilitySize {
                statusLabel
                HStack(spacing: 8) { elapsedLabel; meter }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) { statusLabel; Spacer(minLength: 0); elapsedLabel }
                meter
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: rowHeight)
    }
    private var statusLabel: some View {
        Text(status).font(.caption.weight(.medium)).foregroundStyle(TayyaTheme.detail)
            .lineLimit(1).accessibilityLabel(status)
            .accessibilityIdentifier("recordingStatus")
    }
    private var elapsedLabel: some View {
        Text(duration).font(.caption.monospacedDigit()).foregroundStyle(TayyaTheme.text)
            .frame(width: timeWidth, alignment: .trailing).lineLimit(1).minimumScaleFactor(0.7)
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityLabel("مدة التسجيل").accessibilityValue(duration)
            .accessibilityIdentifier("recordingElapsed")
    }
    private var meter: some View {
        RecordingMeter(samples: activity.samples)
            .frame(height: 16)
            .accessibilityElement().accessibilityLabel("مستوى الميكروفون")
            .accessibilityValue("\(Int(activity.level * 100))٪")
            .accessibilityIdentifier("recordingLevel")
    }
}

private struct RecordingMeter: View {
    let samples: [Double]
    var body: some View {
        Canvas { context, size in
            let step = size.width / CGFloat(max(1, samples.count))
            for (index, sample) in samples.enumerated() {
                // A square-root display scale makes quiet, real input visible.
                let height = max(2, size.height * CGFloat(sqrt(sample)))
                let rect = CGRect(x: CGFloat(index) * step, y: (size.height - height) / 2,
                                  width: max(1, step - 3), height: height)
                context.fill(Path(roundedRect: rect, cornerSize: CGSize(width: 1.5, height: 1.5)), with: .color(TayyaTheme.copper))
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .allowsHitTesting(false)
    }
}
