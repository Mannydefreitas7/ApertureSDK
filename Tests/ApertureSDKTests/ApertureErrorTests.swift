import XCTest
@testable import ApertureSDK

final class ApertureErrorTests: XCTestCase {
    
    func testInvalidAssetError() {
        let error = ApertureError.invalidAsset
        XCTAssertEqual(error.localizedDescription, "Invalid video asset or cannot be loaded")
    }
    
    func testExportFailedError() {
        let error = ApertureError.exportFailed
        XCTAssertEqual(error.localizedDescription, "Video export operation failed")
    }
    
    func testUnsupportedFormatError() {
        let error = ApertureError.unsupportedFormat
        XCTAssertEqual(error.localizedDescription, "Unsupported video format")
    }
    
    func testInsufficientPermissionsError() {
        let error = ApertureError.insufficientPermissions
        XCTAssertEqual(error.localizedDescription, "Insufficient permissions to access the resource")
    }
    
    func testInvalidTimeRangeError() {
        let error = ApertureError.invalidTimeRange
        XCTAssertEqual(error.localizedDescription, "Invalid time range specified")
    }
    
    func testErrorEquality() {
        XCTAssertEqual(ApertureError.invalidAsset, ApertureError.invalidAsset)
        XCTAssertEqual(ApertureError.exportFailed, ApertureError.exportFailed)
        XCTAssertEqual(ApertureError.unsupportedFormat, ApertureError.unsupportedFormat)
        XCTAssertEqual(ApertureError.insufficientPermissions, ApertureError.insufficientPermissions)
        XCTAssertEqual(ApertureError.invalidTimeRange, ApertureError.invalidTimeRange)
        
        XCTAssertNotEqual(ApertureError.invalidAsset, ApertureError.exportFailed)
        XCTAssertNotEqual(ApertureError.unsupportedFormat, ApertureError.invalidTimeRange)
    }
}
