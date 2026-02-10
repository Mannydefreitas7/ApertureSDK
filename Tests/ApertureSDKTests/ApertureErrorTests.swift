import Testing
@testable import ApertureSDK

struct ApertureErrorTests {
    
    @Test func invalidAssetError() {
        let error = ApertureError.invalidAsset
        #expect(error.localizedDescription == "Invalid video asset or cannot be loaded")
    }
    
    @Test func exportFailedError() {
        let error = ApertureError.exportFailed
        #expect(error.localizedDescription == "Video export operation failed")
    }
    
    @Test func unsupportedFormatError() {
        let error = ApertureError.unsupportedFormat
        #expect(error.localizedDescription == "Unsupported video format")
    }
    
    @Test func insufficientPermissionsError() {
        let error = ApertureError.insufficientPermissions
        #expect(error.localizedDescription == "Insufficient permissions to access the resource")
    }
    
    @Test func invalidTimeRangeError() {
        let error = ApertureError.invalidTimeRange
        #expect(error.localizedDescription == "Invalid time range specified")
    }
    
    @Test func errorEquality() {
        #expect(ApertureError.invalidAsset == ApertureError.invalidAsset)
        #expect(ApertureError.exportFailed == ApertureError.exportFailed)
        #expect(ApertureError.unsupportedFormat == ApertureError.unsupportedFormat)
        #expect(ApertureError.insufficientPermissions == ApertureError.insufficientPermissions)
        #expect(ApertureError.invalidTimeRange == ApertureError.invalidTimeRange)
        
        #expect(ApertureError.invalidAsset != ApertureError.exportFailed)
        #expect(ApertureError.unsupportedFormat != ApertureError.invalidTimeRange)
    }
}
