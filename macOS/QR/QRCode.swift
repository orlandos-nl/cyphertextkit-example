import Cocoa
import Foundation

struct QRCode {

    // The reference to this values can be found at 
    // https://developer.apple.com/library/archive/documentation/GraphicsImaging/Reference/CoreImageFilterReference/index.html#//apple_ref/doc/filter/ci/CIQRCodeGenerator
    enum Quality {
        case low
        case medium
        case high
        case highest
        
        var singleLetter: String {
            switch self {
            case .low: return "L"
            case .medium: return "M"
            case .high: return "Q"
            case .highest: return "H"
            }
        }
    }
    
    struct Color {
        var pointStart: NSColor
        var pointEnd: NSColor?
        var backgroundStart: NSColor
        var backgroundEnd: NSColor?
    }
}
