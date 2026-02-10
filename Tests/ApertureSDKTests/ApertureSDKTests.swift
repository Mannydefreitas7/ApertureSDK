import XCTest
@testable import ApertureSDK

final class ApertureSDKTests: XCTestCase {
    
    func testSDKVersion() {
        XCTAssertEqual(ApertureSDK.version, "1.0.0")
    }
    
    func testSharedInstance() {
        let instance1 = ApertureSDK.shared
        let instance2 = ApertureSDK.shared
        XCTAssertTrue(instance1 === instance2, "Shared instance should be a singleton")
    }
    
    func testConfiguration() {
        let config = Configuration(apiKey: "test-key", debugMode: true, timeoutInterval: 60)
        XCTAssertEqual(config.apiKey, "test-key")
        XCTAssertTrue(config.debugMode)
        XCTAssertEqual(config.timeoutInterval, 60)
    }
    
    func testDefaultConfiguration() {
        let config = Configuration()
        XCTAssertNil(config.apiKey)
        XCTAssertFalse(config.debugMode)
        XCTAssertEqual(config.timeoutInterval, 30)
    }
    
    func testConfigureSDK() {
        let sdk = ApertureSDK.shared
        let config = Configuration(apiKey: "new-key")
        sdk.configure(with: config)
        XCTAssertEqual(sdk.configuration.apiKey, "new-key")
    }
    
    func testInitialize() throws {
        let sdk = ApertureSDK.shared
        XCTAssertNoThrow(try sdk.initialize())
    }
}
