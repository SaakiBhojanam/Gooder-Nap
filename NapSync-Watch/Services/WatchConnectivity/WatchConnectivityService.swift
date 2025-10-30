import Foundation
import WatchConnectivity
import Combine
import NapSyncShared

@MainActor
class WatchConnectivityService: NSObject, ObservableObject {
    @Published var isConnected: Bool = false
    @Published var isReachable: Bool = false
    @Published var receivedStartCommand: NapSession?
    @Published var receivedStopCommand: Bool = false

    private var session: WCSession?
    private var hasSentReadyMessage = false
    
    override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    func sendMessage(_ message: [String: Any]) async {
        guard let session = session, session.isReachable else {
            print("iPhone not reachable")
            return
        }
        
        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                session.sendMessage(message, replyHandler: { reply in
                    continuation.resume(returning: reply)
                }, errorHandler: { error in
                    continuation.resume(throwing: error)
                })
            }
        } catch {
            print("Failed to send message to iPhone: \(error)")
        }
    }

    func notifyCompanionReady() {
        guard let session = session, session.isReachable else { return }
        guard !hasSentReadyMessage else { return }

        hasSentReadyMessage = true

        Task {
            await sendMessage(["command": "watchReady"])
        }
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated
            self.isReachable = session.isReachable

            if session.isReachable {
                self.notifyCompanionReady()
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable

            if session.isReachable {
                self.notifyCompanionReady()
            } else {
                self.hasSentReadyMessage = false
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            self.handleReceivedMessage(message, replyHandler: replyHandler)
        }
    }
    
    private func handleReceivedMessage(_ message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let command = message["command"] as? String else {
            replyHandler(["error": "Invalid command"])
            return
        }
        
        switch command {
        case "startNap":
            handleStartNapCommand(message, replyHandler: replyHandler)
        case "stopNap":
            handleStopNapCommand(replyHandler: replyHandler)
        default:
            replyHandler(["error": "Unknown command"])
        }
    }
    
    private func handleStartNapCommand(_ message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let sessionId = message["sessionId"] as? String,
              let id = UUID(uuidString: sessionId),
              let startTimeInterval = message["startTime"] as? TimeInterval,
              let targetDuration = message["targetDuration"] as? TimeInterval,
              let configData = message["configuration"] as? [String: Any] else {
            replyHandler(["error": "Invalid start nap data"])
            return
        }
        
        let startTime = Date(timeIntervalSince1970: startTimeInterval)
        
        // Create NapSession (simplified - in real app would decode full configuration)
        let session = NapSession(
            id: id,
            startTime: startTime,
            targetDuration: targetDuration,
            configuration: .default
        )
        
        receivedStartCommand = session
        replyHandler(["status": "started"])
    }
    
    private func handleStopNapCommand(replyHandler: @escaping ([String: Any]) -> Void) {
        receivedStopCommand = true
        replyHandler(["status": "stopped"])
    }
}