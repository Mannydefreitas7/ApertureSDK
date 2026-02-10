#if canImport(CoreImage)
import Foundation
import CoreImage
import VideoEditorCore

/// Loads and applies LUT (Look-Up Table) color grading files
@available(iOS 15.0, macOS 12.0, *)
public class LUTLoader {
    
    public init() {}
    
    /// Load a LUT from a cube file URL
    /// - Parameter url: URL to the .cube LUT file
    /// - Returns: A CIFilter that applies the LUT
    public func loadCubeLUT(from url: URL) throws -> CIFilter? {
        let data = try String(contentsOf: url, encoding: .utf8)
        return parseCubeLUT(data)
    }
    
    /// Load a LUT from the bundle
    /// - Parameter name: The name of the LUT file (without extension)
    /// - Returns: A CIFilter that applies the LUT
    public func loadBundledLUT(named name: String) throws -> CIFilter? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "cube") else {
            throw VideoEditorError.invalidAsset
        }
        return try loadCubeLUT(from: url)
    }
    
    /// Apply a LUT filter to a CIImage
    /// - Parameters:
    ///   - lutFilter: The LUT filter
    ///   - image: The source image
    /// - Returns: The color-graded image
    public func apply(lutFilter: CIFilter, to image: CIImage) -> CIImage {
        lutFilter.setValue(image, forKey: kCIInputImageKey)
        return lutFilter.outputImage ?? image
    }
    
    // MARK: - Private
    
    private func parseCubeLUT(_ cubeData: String) -> CIFilter? {
        var size = 0
        var data: [Float] = []
        
        let lines = cubeData.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("LUT_3D_SIZE") {
                let parts = trimmed.components(separatedBy: .whitespaces)
                if parts.count >= 2, let s = Int(parts.last ?? "") {
                    size = s
                }
            } else if trimmed.hasPrefix("#") || trimmed.hasPrefix("TITLE") || trimmed.isEmpty {
                continue
            } else {
                let values = trimmed.components(separatedBy: .whitespaces)
                    .compactMap { Float($0) }
                if values.count >= 3 {
                    data.append(contentsOf: [values[0], values[1], values[2], 1.0])
                }
            }
        }
        
        guard size > 0, data.count == size * size * size * 4 else { return nil }
        
        let lutData = data.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
        
        guard let filter = CIFilter(name: "CIColorCubeWithColorSpace") else { return nil }
        filter.setValue(size, forKey: "inputCubeDimension")
        filter.setValue(lutData, forKey: "inputCubeData")
        
        return filter
    }
}
#endif
