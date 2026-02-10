# ApertureSDK

A powerful Swift SDK for managing and processing data across iOS, macOS, tvOS, and watchOS platforms.

## Features

- 🚀 Easy to integrate and use
- 📱 Cross-platform support (iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+)
- ⚙️ Configurable settings
- 🧪 Fully tested
- 📦 Swift Package Manager support

## Installation

### Swift Package Manager

Add ApertureSDK to your project using Swift Package Manager by adding it to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/Mannydefreitas7/ApertureSDK.git", from: "1.0.0")
]
```

Or add it directly in Xcode:
1. File > Add Packages...
2. Enter the repository URL: `https://github.com/Mannydefreitas7/ApertureSDK.git`
3. Select the version you want to use

## Usage

### Basic Setup

```swift
import ApertureSDK

// Get the shared instance
let sdk = ApertureSDK.shared

// Configure the SDK
let config = Configuration(
    apiKey: "your-api-key",
    debugMode: true,
    timeoutInterval: 60
)
sdk.configure(with: config)

// Initialize the SDK
do {
    try sdk.initialize()
} catch {
    print("Failed to initialize SDK: \(error)")
}
```

### Configuration Options

The SDK can be configured with the following options:

- `apiKey`: Optional API key for authentication
- `debugMode`: Enable/disable debug logging (default: `false`)
- `timeoutInterval`: Network request timeout in seconds (default: `30`)

### Error Handling

ApertureSDK uses the `ApertureError` enum for error handling:

```swift
do {
    try sdk.initialize()
} catch ApertureError.invalidConfiguration {
    print("Invalid configuration")
} catch ApertureError.networkError(let error) {
    print("Network error: \(error)")
} catch {
    print("Unknown error: \(error)")
}
```

## Requirements

- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+
- Swift 5.9+
- Xcode 15.0+

## Building

To build the package:

```bash
swift build
```

To run tests:

```bash
swift test
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.