import Testing
@testable import ApertureSDK

struct ApertureSDKTests {
    
    @Test func sdkVersion() {
        #expect(ApertureSDK.version == "1.0.0")
    }
    
    @Test func sharedInstance() {
        let instance1 = ApertureSDK.shared
        let instance2 = ApertureSDK.shared
        #expect(instance1 === instance2, "Shared instance should be a singleton")
    }
    
    @Test func configuration() {
        let config = Configuration(apiKey: "test-key", debugMode: true, timeoutInterval: 60)
        #expect(config.apiKey == "test-key")
        #expect(config.debugMode)
        #expect(config.timeoutInterval == 60)
    }
    
    @Test func defaultConfiguration() {
        let config = Configuration()
        #expect(config.apiKey == nil)
        #expect(!config.debugMode)
        #expect(config.timeoutInterval == 30)
    }
    
    @Test func configureSDK() {
        let sdk = ApertureSDK.shared
        let config = Configuration(apiKey: "new-key")
        sdk.configure(with: config)
        #expect(sdk.configuration.apiKey == "new-key")
    }
    
    @Test func initialize() throws {
        let sdk = ApertureSDK.shared
        #expect(throws: Never.self) { try sdk.initialize() }
    }
    
    @Test func configurationValidation() {
        let validConfig = Configuration(timeoutInterval: 60)
        #expect(validConfig.isValid)
        
        let invalidConfig = Configuration(timeoutInterval: -10)
        #expect(!invalidConfig.isValid)
    }
    
    @Test func invalidConfigurationThrows() {
        let sdk = ApertureSDK.shared
        let invalidConfig = Configuration(timeoutInterval: 0)
        sdk.configure(with: invalidConfig)
        
        #expect(throws: ApertureError.invalidConfiguration) {
            try sdk.initialize()
        }
    }
}
