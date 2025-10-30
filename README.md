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

1. **Open Project**: Open `Good-Nap.xcodeproj` in Xcode 16.0 or newer
2. **Configure Signing**: Set your development team for the *Good-Nap*, *Good-NapTests*, and *Good-NapUITests* targets if you plan to run on device
3. **Run the App**: Select an iOS simulator (iPhone 15 or later recommended) and press **Run** to launch the SwiftUI application
4. **Train the Model**: On first launch the ML training screen appears; allow it to complete to experience the full UI flow

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