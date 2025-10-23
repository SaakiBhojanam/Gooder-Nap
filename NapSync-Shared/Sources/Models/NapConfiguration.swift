import Foundation

/// Configuration settings for a nap session
public struct NapConfiguration: Codable {
    public let alarmTone: AlarmTone
    public let hapticIntensity: HapticIntensity
    public let wakeWindowMinutes: Int // How early before target time to start looking for optimal wake
    public let monitoringInterval: TimeInterval // How often to collect biometric data
    public let sleepStageConfidenceThreshold: Double
    public let enableGentleWake: Bool
    public let enableProgressiveAlarm: Bool
    
    public static let `default` = NapConfiguration(
        alarmTone: .gentleChime,
        hapticIntensity: .medium,
        wakeWindowMinutes: 10,
        monitoringInterval: 30.0,
        sleepStageConfidenceThreshold: 0.7,
        enableGentleWake: true,
        enableProgressiveAlarm: true
    )
    
    public init(
        alarmTone: AlarmTone = .gentleChime,
        hapticIntensity: HapticIntensity = .medium,
        wakeWindowMinutes: Int = 10,
        monitoringInterval: TimeInterval = 30.0,
        sleepStageConfidenceThreshold: Double = 0.7,
        enableGentleWake: Bool = true,
        enableProgressiveAlarm: Bool = true
    ) {
        self.alarmTone = alarmTone
        self.hapticIntensity = hapticIntensity
        self.wakeWindowMinutes = wakeWindowMinutes
        self.monitoringInterval = monitoringInterval
        self.sleepStageConfidenceThreshold = sleepStageConfidenceThreshold
        self.enableGentleWake = enableGentleWake
        self.enableProgressiveAlarm = enableProgressiveAlarm
    }
}

/// Available alarm tones
public enum AlarmTone: String, CaseIterable, Codable {
    case gentleChime = "gentle_chime"
    case natureSounds = "nature_sounds"
    case softBell = "soft_bell"
    case progressiveTone = "progressive_tone"
    
    public var displayName: String {
        switch self {
        case .gentleChime: return "Gentle Chime"
        case .natureSounds: return "Nature Sounds"
        case .softBell: return "Soft Bell"
        case .progressiveTone: return "Progressive Tone"
        }
    }
    
    public var fileName: String {
        return "\(rawValue).wav"
    }
}

/// Haptic feedback intensity levels
public enum HapticIntensity: String, CaseIterable, Codable {
    case light = "light"
    case medium = "medium"
    case strong = "strong"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}