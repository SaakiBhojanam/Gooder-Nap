import Foundation
import Combine

/// Observable controller that encapsulates the state of a nap session on Apple Watch.
/// The view model focuses on presenting responsive UI feedback for the watch front end.
final class NapSessionViewModel: ObservableObject {
    enum SessionState: Equatable {
        case idle
        case running
        case analyzing
        case completed
    }

    /// Maximum nap duration expressed in minutes. Adjusted via the Digital Crown.
    @Published var targetDurationMinutes: Double = 90 {
        didSet {
            targetDurationMinutes = min(max(targetDurationMinutes, durationBounds.lowerBound), durationBounds.upperBound)
        }
    }

    /// Total number of seconds elapsed since the nap started.
    @Published private(set) var elapsedTime: TimeInterval = 0

    /// The current state of the nap session.
    @Published private(set) var state: SessionState = .idle

    /// Stores the date when the nap began.
    @Published private(set) var startDate: Date?

    private var timerCancellable: AnyCancellable?

    /// Bounds for the maximum nap duration (15 minutes to 2 hours).
    let durationBounds: ClosedRange<Double> = 15...120

    /// Formatter used for presenting timers in the UI.
    private lazy var timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    deinit {
        timerCancellable?.cancel()
    }

    /// Initiates a nap session and starts tracking the elapsed time.
    func startNap() {
        guard state != .running else { return }
        elapsedTime = 0
        startDate = Date()
        state = .running

        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    /// Stops the nap session and transitions the view model to the analyzing state.
    func stopNap() {
        guard state == .running else { return }
        timerCancellable?.cancel()
        timerCancellable = nil
        state = .analyzing

        // Simulate a brief analysis before completing the session.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.state = .completed
        }
    }

    /// Resets the nap session to its idle state.
    func resetNap() {
        timerCancellable?.cancel()
        timerCancellable = nil
        elapsedTime = 0
        startDate = nil
        state = .idle
    }

    private func tick() {
        guard state == .running else { return }
        elapsedTime = Date().timeIntervalSince(startDate ?? Date())

        if elapsedTime >= targetDurationSeconds {
            stopNap()
        }
    }

    /// Returns the nap duration configured by the user in seconds.
    var targetDurationSeconds: TimeInterval {
        targetDurationMinutes * 60
    }

    /// Percentage progress for the active session.
    var progress: Double {
        guard targetDurationSeconds > 0 else { return 0 }
        return min(elapsedTime / targetDurationSeconds, 1)
    }

    /// Remaining time before the configured nap duration is reached.
    var remainingTime: TimeInterval {
        max(targetDurationSeconds - elapsedTime, 0)
    }

    /// A simulated optimal wake window that begins once 60% of the nap duration has elapsed.
    var optimalWakeWindow: ClosedRange<Date>? {
        guard let startDate else { return nil }
        let lowerBound = startDate.addingTimeInterval(targetDurationSeconds * 0.6)
        let upperBound = startDate.addingTimeInterval(targetDurationSeconds)
        return lowerBound...upperBound
    }

    /// The next recommended wake-up time within the optimal window.
    var nextOptimalWakeDate: Date? {
        guard let window = optimalWakeWindow else { return nil }
        let now = Date()
        if now <= window.lowerBound {
            return window.lowerBound
        } else if now <= window.upperBound {
            return now
        } else {
            return nil
        }
    }

    /// A formatted string representing the remaining time.
    var remainingTimeString: String {
        timeFormatter.string(from: remainingTime) ?? "--"
    }

    /// A formatted string representing the elapsed time.
    var elapsedTimeString: String {
        timeFormatter.string(from: elapsedTime) ?? "--"
    }

    /// A formatted string that communicates the optimal wake window.
    var optimalWindowDescription: String {
        guard let window = optimalWakeWindow else { return "Optimal wake window will appear once your nap begins." }
        let lower = window.lowerBound.formatted(date: .omitted, time: .shortened)
        let upper = window.upperBound.formatted(date: .omitted, time: .shortened)
        return "Wake between \(lower) – \(upper) for a refreshed feeling."
    }

    /// A countdown string for the next recommended wake moment.
    var optimalWakeCountdown: String {
        guard let optimalDate = nextOptimalWakeDate else { return "--" }
        let interval = max(optimalDate.timeIntervalSinceNow, 0)
        return timeFormatter.string(from: interval) ?? "--"
    }
}
