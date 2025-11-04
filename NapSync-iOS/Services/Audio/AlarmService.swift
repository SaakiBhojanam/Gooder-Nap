import Foundation
import AVFoundation
import UserNotifications
import NapSyncShared

@MainActor
class AlarmService: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private var hapticManager = HapticManager()
    
    func triggerAlarm(for wakeTime: OptimalWakeTime) async {
        // Start haptic feedback
        await hapticManager.startWakeSequence()
        
        // Play alarm sound
        await playAlarmSound()
        
        // Send notification
        await sendWakeNotification(for: wakeTime)
        
        // Gradually increase intensity over 30 seconds
        await gradualWakeSequence()
    }
    
    private func playAlarmSound() async {
        guard let soundURL = Bundle.main.url(forResource: "gentle-alarm", withExtension: "wav") else {
            print("Alarm sound file not found")
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                print("Failed to configure audio session: \(error)")
                return
            }

            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = 0.3 // Start at low volume
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Failed to play alarm sound: \(error)")
        }
    }
    
    private func sendWakeNotification(for wakeTime: OptimalWakeTime) async {
        let content = UNMutableNotificationContent()
        content.title = "Time to Wake Up!"
        content.body = "Your optimal wake time has arrived (\(wakeTime.reason.description))"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "nap-wake-alarm",
            content: content,
            trigger: nil // Immediate
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to send wake notification: \(error)")
        }
    }
    
    private func gradualWakeSequence() async {
        // Gradually increase alarm intensity over 30 seconds
        for i in 1...30 {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            let progress = Float(i) / 30.0
            audioPlayer?.volume = min(1.0, 0.3 + (progress * 0.7))
            
            // Increase haptic intensity every 10 seconds
            if i % 10 == 0 {
                await hapticManager.increaseMintensity()
            }
        }
    }
    
    func stopAlarm() {
        audioPlayer?.stop()
        audioPlayer = nil
        hapticManager.stopFeedback()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

class HapticManager {
    private var hapticTimer: Timer?
    private var currentIntensity: Float = 0.5
    
    @MainActor
    func startWakeSequence() async {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            impactFeedback.impactOccurred(intensity: CGFloat(self.currentIntensity))
        }
    }
    
    @MainActor
    func increaseMintensity() async {
        currentIntensity = min(1.0, currentIntensity + 0.2)
    }
    
    func stopFeedback() {
        hapticTimer?.invalidate()
        hapticTimer = nil
    }
}