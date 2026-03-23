import Foundation

enum BrightnessManager {

    static func get() -> Float {
        get_display_brightness()
    }

    static func set(_ level: Float) {
        set_display_brightness(min(max(level, 0.0), 1.0))
    }
}
