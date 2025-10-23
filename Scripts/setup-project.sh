#!/bin/bash

# NapSync Project Setup Script
# This script sets up the development environment for the NapSync app

echo "🌙 Setting up NapSync development environment..."

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode is not installed. Please install Xcode from the App Store."
    exit 1
fi

# Create necessary directories if they don't exist
echo "📁 Creating project structure..."
mkdir -p "NapSync-iOS/Resources/Sounds"
mkdir -p "NapSync-iOS/Resources/Data"
mkdir -p "Documentation"
mkdir -p "Scripts"

# Set executable permissions for scripts
echo "🔧 Setting up permissions..."
chmod +x Scripts/*.sh

# Install dependencies (if using CocoaPods)
if [ -f "Podfile" ]; then
    echo "📦 Installing CocoaPods dependencies..."
    pod install
fi

# Build the shared framework
echo "🔨 Building shared framework..."
cd NapSync-Shared
swift build
cd ..

echo "✅ NapSync development environment setup complete!"
echo ""
echo "Next steps:"
echo "1. Open NapSync.xcworkspace in Xcode"
echo "2. Configure your development team in project settings"
echo "3. Add HealthKit and WatchConnectivity entitlements"
echo "4. Build and test on device (Apple Watch required for full functionality)"
echo ""
echo "Happy coding! 🚀"