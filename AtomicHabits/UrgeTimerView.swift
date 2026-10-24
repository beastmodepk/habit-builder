import SwiftUI

struct UrgeTimerView: View {
    private let totalSeconds = 10 * 60
    @State private var secondsLeft = 10 * 60
    @State private var isRunning = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - secondsLeft) / Double(totalSeconds)
    }

    private var timeText: String {
        String(format: "%02d:%02d", secondsLeft / 60, secondsLeft % 60)
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Ride out the urge")
                .font(.title2).bold()
            Text("Most urges peak and fade. Give it 10 minutes before you decide.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.25), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(timeText)
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
            }
            .frame(width: 200, height: 200)
            .padding()

            if secondsLeft == 0 {
                Text("You did it. The urge passed — log what you did instead.")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                Button(isRunning ? "Pause" : (secondsLeft == totalSeconds ? "Start" : "Resume")) {
                    if secondsLeft > 0 { isRunning.toggle() }
                }
                .buttonStyle(.borderedProminent)

                Button("Reset") {
                    isRunning = false
                    secondsLeft = totalSeconds
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .navigationTitle("Urge Timer")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(ticker) { _ in
            guard isRunning, secondsLeft > 0 else { return }
            secondsLeft -= 1
            if secondsLeft == 0 { isRunning = false }
        }
    }
}
