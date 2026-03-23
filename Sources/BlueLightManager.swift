import CoreGraphics
import Foundation

enum BlueLightManager {

    /// Sets the display gamma to match a given color temperature in Kelvin.
    /// 6500 K = standard daylight (no change). Lower = warmer / more amber.
    static func setColorTemperature(_ kelvin: Int) {
        let (r, g, b) = gammaMultipliers(forKelvin: kelvin)
        let displayID = CGMainDisplayID()
        CGSetDisplayTransferByFormula(
            displayID,
            0, r, 1.0,
            0, g, 1.0,
            0, b, 1.0
        )
    }

    /// Darkroom mode: red-only output to preserve night vision.
    static func setDarkroom() {
        let displayID = CGMainDisplayID()
        CGSetDisplayTransferByFormula(
            displayID,
            0, 0.8, 1.0,
            0, 0.0, 1.0,
            0, 0.0, 1.0
        )
    }

    static func reset() {
        CGDisplayRestoreColorSyncSettings()
    }

    // MARK: - Kelvin → gamma multipliers

    /// Returns per-channel max values for CGSetDisplayTransferByFormula,
    /// normalized so that 6500 K produces (1, 1, 1).
    static func gammaMultipliers(forKelvin kelvin: Int) -> (r: Float, g: Float, b: Float) {
        let k = max(1000, min(6500, kelvin))
        let target = rawRGB(kelvin: k)
        let ref    = rawRGB(kelvin: 6500)
        return (
            min(target.0 / ref.0, 1.0),
            min(target.1 / ref.1, 1.0),
            min(target.2 / ref.2, 1.0)
        )
    }

    /// Tanner Helland's algorithm: color temperature → un-clamped RGB (0-255 scale).
    private static func rawRGB(kelvin: Int) -> (Float, Float, Float) {
        let t = Float(kelvin) / 100.0
        var r: Float, g: Float, b: Float

        if t <= 66 {
            r = 255
            g = 99.4708025861 * log(t) - 161.1195681661
        } else {
            r = 329.698727446 * pow(t - 60, -0.1332047592)
            g = 288.1221695283 * pow(t - 60, -0.0755148492)
        }

        if t >= 66 {
            b = 255
        } else if t <= 19 {
            b = 0
        } else {
            b = 138.5177312231 * log(t - 10) - 305.0447927307
        }

        return (max(r, 0), max(g, 0), max(b, 0))
    }

    // MARK: - Human-readable label

    static func label(forKelvin kelvin: Int) -> String {
        switch kelvin {
        case 6200...6500: return "Daylight"
        case 5000..<6200: return "Bright White"
        case 4000..<5000: return "Fluorescent"
        case 3200..<4000: return "Halogen"
        case 2500..<3200: return "Incandescent"
        case 1800..<2500: return "Candle"
        default:          return "Ember"
        }
    }
}
