import Foundation
import Combine

final class ScheduleManager: ObservableObject {

    // MARK: - Current state

    @Published var brightness: Float
    @Published var colorTemp: Int        // Kelvin (1200–6500)
    @Published var isDarkroom: Bool

    // MARK: - User preferences

    @Published var isAutoMode: Bool
    @Published var sunriseTime: Int      // minutes from midnight
    @Published var sunsetTime: Int       // minutes from midnight
    @Published var dayBrightness: Float
    @Published var nightBrightness: Float
    @Published var nightColorTemp: Int   // Kelvin target after sunset

    private var scheduleTimer: Timer?
    private var syncTimer: Timer?

    // MARK: - Init

    init() {
        let d = UserDefaults.standard
        isAutoMode      = d.object(forKey: "isAutoMode") as? Bool  ?? true
        sunriseTime     = d.object(forKey: "sunriseTime") as? Int  ?? 420   // 7:00 AM
        sunsetTime      = d.object(forKey: "sunsetTime") as? Int   ?? 1200  // 8:00 PM
        dayBrightness   = d.object(forKey: "dayBrightness") as? Float   ?? 1.0
        nightBrightness = d.object(forKey: "nightBrightness") as? Float ?? 0.4
        nightColorTemp  = d.object(forKey: "nightColorTemp") as? Int    ?? 2700
        brightness      = d.object(forKey: "brightness") as? Float      ?? 1.0
        colorTemp       = d.object(forKey: "colorTemp") as? Int         ?? 6500
        isDarkroom      = d.object(forKey: "isDarkroom") as? Bool       ?? false
    }

    // MARK: - Lifecycle

    func start() {
        update()
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.update()
        }
        syncTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.syncFromSystem()
        }
    }

    private func syncFromSystem() {
        let systemBrightness = BrightnessManager.get()
        if abs(systemBrightness - brightness) > 0.01 {
            brightness = systemBrightness
            save()
        }
    }

    func update() {
        if isAutoMode && !isDarkroom {
            let (b, k) = calculateLevels()
            brightness = b
            colorTemp = k
        }
        apply()
    }

    // MARK: - Manual controls

    func setBrightness(_ value: Float) {
        brightness = value
        BrightnessManager.set(value)
        save()
    }

    func setColorTemp(_ kelvin: Int) {
        colorTemp = kelvin
        if isDarkroom {
            isDarkroom = false
        }
        BlueLightManager.setColorTemperature(kelvin)
        save()
    }

    func toggleDarkroom() {
        isDarkroom.toggle()
        apply()
    }

    func applyPreset(_ kelvin: Int) {
        isAutoMode = false
        isDarkroom = false
        colorTemp = kelvin
        apply()
    }

    // MARK: - Apply & reset

    func apply() {
        BrightnessManager.set(brightness)
        if isDarkroom {
            BlueLightManager.setDarkroom()
        } else {
            BlueLightManager.setColorTemperature(colorTemp)
        }
        save()
    }

    func resetToDefaults() {
        isDarkroom = false
        BlueLightManager.reset()
        BrightnessManager.set(1.0)
        brightness = 1.0
        colorTemp = 6500
        save()
    }

    // MARK: - Schedule calculation

    /// Interpolates brightness and color temperature based on current time,
    /// sunrise / sunset, and a 60-minute transition window.
    private func calculateLevels() -> (Float, Int) {
        let cal  = Calendar.current
        let now  = Date()
        let mins = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)

        let rise = sunriseTime
        let set  = sunsetTime
        let half = 30

        let riseStart = rise - half
        let riseEnd   = rise + half
        let setStart  = set  - half
        let setEnd    = set  + half

        if mins >= riseEnd && mins <= setStart {
            return (dayBrightness, 6500)
        }

        if mins >= setEnd || mins <= riseStart {
            return (nightBrightness, nightColorTemp)
        }

        if mins > riseStart && mins < riseEnd {
            let t = Float(mins - riseStart) / Float(riseEnd - riseStart)
            return (
                nightBrightness + (dayBrightness - nightBrightness) * t,
                nightColorTemp + Int(Float(6500 - nightColorTemp) * t)
            )
        }

        let t = Float(mins - setStart) / Float(setEnd - setStart)
        return (
            dayBrightness + (nightBrightness - dayBrightness) * t,
            6500 - Int(Float(6500 - nightColorTemp) * t)
        )
    }

    // MARK: - Date helpers for DatePicker bindings

    var sunriseDate: Date {
        get { dateFromMinutes(sunriseTime) }
        set { sunriseTime = minutesFromDate(newValue); update() }
    }

    var sunsetDate: Date {
        get { dateFromMinutes(sunsetTime) }
        set { sunsetTime = minutesFromDate(newValue); update() }
    }

    private func dateFromMinutes(_ mins: Int) -> Date {
        Calendar.current.date(
            bySettingHour: mins / 60, minute: mins % 60, second: 0, of: Date()
        ) ?? Date()
    }

    private func minutesFromDate(_ date: Date) -> Int {
        let cal = Calendar.current
        return cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
    }

    // MARK: - Persistence

    func save() {
        let d = UserDefaults.standard
        d.set(isAutoMode,      forKey: "isAutoMode")
        d.set(sunriseTime,     forKey: "sunriseTime")
        d.set(sunsetTime,      forKey: "sunsetTime")
        d.set(dayBrightness,   forKey: "dayBrightness")
        d.set(nightBrightness, forKey: "nightBrightness")
        d.set(nightColorTemp,  forKey: "nightColorTemp")
        d.set(brightness,      forKey: "brightness")
        d.set(colorTemp,       forKey: "colorTemp")
        d.set(isDarkroom,      forKey: "isDarkroom")
    }
}
