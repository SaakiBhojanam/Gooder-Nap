import Foundation
import WatchConnectivity
import Combine
import NapSyncShared

@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {
    @Published var isConnected: Bool = false
    @Published var isReachable: Bool = false
    
    private var session: WCSession?
    private let messageHandler = WatchMessageHandler()
    
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
    
    func startSession() {
        session?.activate()
    }
    
    // MARK: - Communication Methods
    
    func sendStartNapCommand(session napSession: NapSession) async throws {
        guard let wcSession = session, wcSession.isReachable else {
            throw WatchConnectivityError.notReachable
        }
        
        let message: [String: Any] = [
            "command": "startNap",
            "sessionId": napSession.id.uuidString,
            "startTime": napSession.startTime.timeIntervalSince1970,
            "targetDuration": napSession.targetDuration,
            "configuration": try encodeConfiguration(napSession.configuration)
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            wcSession.sendMessage(message, replyHandler: { response in
                continuation.resume()
            }, errorHandler: { error in
                continuation.resume(throwing: error)
            })
        }
    }
    
    func sendStopNapCommand() async throws {
        guard let wcSession = session, wcSession.isReachable else {
            throw WatchConnectivityError.notReachable
        }
        
        let message: [String: Any] = ["command": "stopNap"]
        
        return try await withCheckedThrowingContinuation { continuation in
            wcSession.sendMessage(message, replyHandler: { response in
                continuation.resume()
            }, errorHandler: { error in
                continuation.resume(throwing: error)
            })
        }
    }
    
    private func encodeConfiguration(_ config: NapConfiguration) throws -> [String: Any] {
        let data = try JSONEncoder().encode(config)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        return json as? [String: Any] ?? [:]
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated
            self.isReachable = session.isReachable
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.isReachable = false
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.isReachable = false
        }
        
        // Reactivate the session
        session.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        messageHandler.handleMessage(message, replyHandler: replyHandler)
    }
}

// MARK: - Supporting Classes
class WatchMessageHandler {
    func handleMessage(_ message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let command = message["command"] as? String else {
            replyHandler(["error": "Invalid command"])
            return
        }
        
        switch command {
        case "biometricData":
            handleBiometricData(message, replyHandler: replyHandler)
        case "sleepStageUpdate":
            handleSleepStageUpdate(message, replyHandler: replyHandler)
        case "wakeRequest":
            handleWakeRequest(message, replyHandler: replyHandler)
        default:
            replyHandler(["error": "Unknown command"])
        }
    }
    
    private func handleBiometricData(_ message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // Process incoming biometric data from watch
        NotificationCenter.default.post(name: .biometricDataReceived, object: message)
        replyHandler(["status": "received"])
    }
    
    private func handleSleepStageUpdate(_ message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // Process sleep stage updates from watch
        NotificationCenter.default.post(name: .sleepStageUpdated, object: message)
        replyHandler(["status": "received"])
    }
    
    private func handleWakeRequest(_ message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // Handle wake request from watch
        NotificationCenter.default.post(name: .wakeRequestReceived, object: message)
        replyHandler(["status": "received"])
    }
}

enum WatchConnectivityError: Error {
    case notSupported
    case notReachable
    case sessionNotActive
    
    var localizedDescription: String {
        switch self {
        case .notSupported:
            return "Apple Watch connectivity is not supported"
        case .notReachable:
            return "Apple Watch is not reachable"
        case .sessionNotActive:
            return "Watch connectivity session is not active"
        }
    }
}

extension Notification.Name {
    static let biometricDataReceived = Notification.Name("biometricDataReceived")
    static let sleepStageUpdated = Notification.Name("sleepStageUpdated")
    static let wakeRequestReceived = Notification.Name("wakeRequestReceived")
}