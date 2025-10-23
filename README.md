# NapSync - Smart Nap Optimization App

## Overview
NapSync is an iOS + watchOS companion app that uses biometric data from Apple Watch to optimize nap wake times using sleep stage detection.

## Architecture Summary

### 📱 iOS App (NapSync-iOS)
- **MVVM Architecture** with SwiftUI
- **Home Module**: Duration picker, connection status, nap configuration
- **Monitoring Module**: Real-time nap tracking with timer and sleep stage display
- **Summary Module**: Post-nap analytics with heart rate charts and feedback
- **Services**: HealthKit, WatchConnectivity, Audio/Haptics, CoreData

### ⌚ Apple Watch App (NapSync-Watch)
- **Minimal UI** optimized for sleep monitoring
- **Background Monitoring**: Continuous biometric data collection
- **Real-time Communication** with iPhone app
- **Progressive Alarm System** with haptic feedback

### 🔧 Shared Framework (NapSync-Shared)
- **Core Models**: NapSession, SleepStage, BiometricData, OptimalWakeTime
- **Sleep Algorithm**: MVP heuristics using HRV and motion analysis
- **Processing Services**: BiometricProcessor, SleepStageEstimator, OptimalWakeCalculator

## Key Features Implemented

✅ **Smart Sleep Detection**: Uses heart rate variability and motion patterns  
✅ **Optimal Wake Windows**: Finds light sleep phases for gentle awakening  
✅ **Real-time Monitoring**: Live biometric data streaming between devices  
✅ **Progressive Alarms**: Gentle wake sequences with increasing intensity  
✅ **Nap Analytics**: Post-nap summaries with heart rate charts  
✅ **User Feedback**: Rating system for nap quality assessment  

## Development Setup

1. **Open Project**: Use `NapSync.xcworkspace` in Xcode
2. **Configure Teams**: Set development teams for iOS and watchOS targets
3. **Add Entitlements**: HealthKit and WatchConnectivity capabilities
4. **Test on Device**: Apple Watch required for full functionality

## Architecture Highlights

- **Separation of Concerns**: Clear boundaries between UI, business logic, and data
- **Cross-platform Sharing**: Core logic shared between iOS and watchOS
- **Real-time Processing**: Streaming biometric analysis with sliding windows
- **Background Execution**: Continuous monitoring using workout sessions
- **Error Handling**: Comprehensive error states and user feedback

## Next Steps for Production

- Add CoreML sleep stage classification models
- Implement iCloud data synchronization
- Add Apple Shortcuts integration
- Enhanced personalization based on user data
- Advanced sleep pattern analytics

The complete MVP architecture is now ready for development and testing!