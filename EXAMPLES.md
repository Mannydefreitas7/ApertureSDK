# Examples

This directory contains usage examples for ApertureSDK.

## Basic Usage Example

```swift
import ApertureSDK

// Initialize the SDK
let sdk = ApertureSDK.shared

// Configure with your API key
let config = Configuration(
    apiKey: "your-api-key-here",
    debugMode: true,
    timeoutInterval: 60
)
sdk.configure(with: config)

// Initialize
do {
    try sdk.initialize()
    print("SDK initialized successfully!")
} catch {
    print("Initialization failed: \(error)")
}
```

## Custom Configuration Example

```swift
import ApertureSDK

// Create a production configuration
let productionConfig = Configuration(
    apiKey: ProcessInfo.processInfo.environment["APERTURE_API_KEY"],
    debugMode: false,
    timeoutInterval: 30
)

// Apply the configuration
ApertureSDK.shared.configure(with: productionConfig)

// Initialize the SDK
do {
    try ApertureSDK.shared.initialize()
} catch ApertureError.invalidConfiguration {
    print("Invalid configuration - check your settings")
} catch {
    print("Unexpected error: \(error)")
}
```

## Error Handling Example

```swift
import ApertureSDK

func setupSDK() {
    let sdk = ApertureSDK.shared
    
    do {
        try sdk.initialize()
    } catch ApertureError.invalidConfiguration {
        print("Configuration is invalid")
        // Handle invalid configuration
    } catch ApertureError.networkError(let underlyingError) {
        print("Network error occurred: \(underlyingError.localizedDescription)")
        // Handle network errors
    } catch ApertureError.unsupportedOperation {
        print("Operation not supported")
        // Handle unsupported operations
    } catch {
        print("Unexpected error: \(error)")
        // Handle other errors
    }
}
```

## Testing Example

```swift
import XCTest
@testable import ApertureSDK

class MyAppTests: XCTestCase {
    func testSDKConfiguration() {
        let config = Configuration(apiKey: "test-key")
        ApertureSDK.shared.configure(with: config)
        
        XCTAssertEqual(ApertureSDK.shared.configuration.apiKey, "test-key")
    }
    
    func testSDKInitialization() {
        XCTAssertNoThrow(try ApertureSDK.shared.initialize())
    }
}
```
