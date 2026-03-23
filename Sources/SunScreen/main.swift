import AppKit
import SwiftUI
import IOKit
import CoreGraphics

// MARK: - Brightness (pure Swift via IOKit)

enum BrightnessManager {
    private static let displayServicesPath =
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"

    private typealias DSGetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias DSSetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let handle: UnsafeMutableRawPointer? = dlopen(displayServicesPath, RTLD_LAZY)

    static func get() -> Float {
        if let h = handle,
           let sym = dlsym(h, "DisplayServicesGetBrightness") {
            let fn = unsafeBitCast(sym, to: DSGetBrightness.self)
            var level: Float = 0
            if fn(CGMainDisplayID(), &level) == 0 { return level }
        }
        return iokitGet()
    }

    static func set(_ level: Float) {
        let clamped = min(max(level, 0), 1)
        if let h = handle,
           let sym = dlsym(h, "DisplayServicesSetBrightness") {
            let fn = unsafeBitCast(sym, to: DSSetBrightness.self)
            if fn(CGMainDisplayID(), clamped) == 0 { return }
        }
        iokitSet(clamped)
    }

    private static func iokitGet() -> Float {
        var brightness: Float = 1
        var iter: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
                IOServiceMatching("IODisplayConnect"), &iter) == kIOReturnSuccess else { return brightness }
        var service = IOIteratorNext(iter)
        while service != 0 {
            var level: Float = 0
            if IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &level) == kIOReturnSuccess {
                brightness = level
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iter)
        }
        IOObjectRelease(iter)
        return brightness
    }

    private static func iokitSet(_ level: Float) {
        var iter: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
                IOServiceMatching("IODisplayConnect"), &iter) == kIOReturnSuccess else { return }
        var service = IOIteratorNext(iter)
        while service != 0 {
            IODisplaySetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, level)
            IOObjectRelease(service)
            service = IOIteratorNext(iter)
        }
        IOObjectRelease(iter)
    }
}

// MARK: - Blue Light / Color Temperature

enum BlueLightManager {

    static func setColorTemperature(_ kelvin: Int) {
        let (r, g, b) = gammaMultipliers(forKelvin: kelvin)
        CGSetDisplayTransferByFormula(CGMainDisplayID(),
                                     0, r, 1, 0, g, 1, 0, b, 1)
    }

    static func setDarkroom() {
        CGSetDisplayTransferByFormula(CGMainDisplayID(),
                                     0, 0.8, 1, 0, 0, 1, 0, 0, 1)
    }

    static func reset() {
        CGDisplayRestoreColorSyncSettings()
    }

    static func gammaMultipliers(forKelvin kelvin: Int) -> (r: Float, g: Float, b: Float) {
        let k = max(1000, min(6500, kelvin))
        let target = rawRGB(kelvin: k)
        let ref = rawRGB(kelvin: 6500)
        return (min(target.0 / ref.0, 1), min(target.1 / ref.1, 1), min(target.2 / ref.2, 1))
    }

    private static func rawRGB(kelvin: Int) -> (Float, Float, Float) {
        let t = Float(kelvin) / 100
        var r: Float, g: Float, b: Float

        if t <= 66 {
            r = 255
            g = 99.4708025861 * log(t) - 161.1195681661
        } else {
            r = 329.698727446 * pow(t - 60, -0.1332047592)
            g = 288.1221695283 * pow(t - 60, -0.0755148492)
        }

        if t >= 66 { b = 255 }
        else if t <= 19 { b = 0 }
        else { b = 138.5177312231 * log(t - 10) - 305.0447927307 }

        return (max(r, 0), max(g, 0), max(b, 0))
    }

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

// MARK: - Schedule Manager

final class ScheduleManager: ObservableObject {

    @Published var brightness: Float
    @Published var colorTemp: Int
    @Published var isDarkroom: Bool

    @Published var isAutoMode: Bool
    @Published var sunriseTime: Int
    @Published var sunsetTime: Int
    @Published var dayBrightness: Float
    @Published var nightBrightness: Float
    @Published var nightColorTemp: Int

    private var scheduleTimer: Timer?
    private var syncTimer: Timer?

    init() {
        let d = UserDefaults.standard
        isAutoMode      = d.object(forKey: "isAutoMode") as? Bool  ?? true
        sunriseTime     = d.object(forKey: "sunriseTime") as? Int  ?? 420
        sunsetTime      = d.object(forKey: "sunsetTime") as? Int   ?? 1200
        dayBrightness   = d.object(forKey: "dayBrightness") as? Float   ?? 1.0
        nightBrightness = d.object(forKey: "nightBrightness") as? Float ?? 0.4
        nightColorTemp  = d.object(forKey: "nightColorTemp") as? Int    ?? 2700
        brightness      = d.object(forKey: "brightness") as? Float      ?? 1.0
        colorTemp       = d.object(forKey: "colorTemp") as? Int         ?? 6500
        isDarkroom      = d.object(forKey: "isDarkroom") as? Bool       ?? false
    }

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
        let sys = BrightnessManager.get()
        if abs(sys - brightness) > 0.01 {
            brightness = sys
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

    func setBrightness(_ value: Float) {
        brightness = value
        BrightnessManager.set(value)
        save()
    }

    func setColorTemp(_ kelvin: Int) {
        colorTemp = kelvin
        if isDarkroom { isDarkroom = false }
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

    func apply() {
        BrightnessManager.set(brightness)
        if isDarkroom { BlueLightManager.setDarkroom() }
        else { BlueLightManager.setColorTemperature(colorTemp) }
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

    private func calculateLevels() -> (Float, Int) {
        let cal = Calendar.current
        let now = Date()
        let mins = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let half = 30

        let riseStart = sunriseTime - half
        let riseEnd   = sunriseTime + half
        let setStart  = sunsetTime - half
        let setEnd    = sunsetTime + half

        if mins >= riseEnd && mins <= setStart {
            return (dayBrightness, 6500)
        }
        if mins >= setEnd || mins <= riseStart {
            return (nightBrightness, nightColorTemp)
        }
        if mins > riseStart && mins < riseEnd {
            let t = Float(mins - riseStart) / Float(riseEnd - riseStart)
            return (nightBrightness + (dayBrightness - nightBrightness) * t,
                    nightColorTemp + Int(Float(6500 - nightColorTemp) * t))
        }
        let t = Float(mins - setStart) / Float(setEnd - setStart)
        return (dayBrightness + (nightBrightness - dayBrightness) * t,
                6500 - Int(Float(6500 - nightColorTemp) * t))
    }

    var sunriseDate: Date {
        get { dateFromMinutes(sunriseTime) }
        set { sunriseTime = minutesFromDate(newValue); update() }
    }
    var sunsetDate: Date {
        get { dateFromMinutes(sunsetTime) }
        set { sunsetTime = minutesFromDate(newValue); update() }
    }

    private func dateFromMinutes(_ m: Int) -> Date {
        Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
    }
    private func minutesFromDate(_ d: Date) -> Int {
        Calendar.current.component(.hour, from: d) * 60 + Calendar.current.component(.minute, from: d)
    }

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

// MARK: - SwiftUI Content View

struct ContentView: View {
    @ObservedObject var manager: ScheduleManager
    @State private var showingSchedule = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 14) {
                    warmthBar
                    sliderSection
                    presetsSection
                    darkroomSection
                    scheduleSection
                }
                .padding(16)
            }
            Divider()
            footer
        }
        .frame(width: 320)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: headerColors,
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)
                Image(systemName: headerIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("SunScreen").font(.system(size: 14, weight: .semibold))
                Text(statusText).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $manager.isAutoMode)
                .toggleStyle(.switch).controlSize(.small).labelsHidden()
                .onChange(of: manager.isAutoMode) { _, _ in manager.update() }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var warmthBar: some View {
        let progress = Double(6500 - manager.colorTemp) / Double(6500 - 1200)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(LinearGradient(colors: [.blue, .cyan, .yellow, .orange, .red],
                                              startPoint: .trailing, endPoint: .leading)).opacity(0.3)
                Capsule().fill(LinearGradient(colors: [.blue, .orange],
                                              startPoint: .trailing, endPoint: .leading))
                    .frame(width: max(8, geo.size.width * CGFloat(manager.isDarkroom ? 1.0 : progress)))
            }
        }
        .frame(height: 4).clipShape(Capsule())
    }

    private var sliderSection: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Brightness", systemImage: "sun.min.fill")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(manager.brightness * 100))%")
                        .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                }
                Slider(value: Binding(get: { Double(manager.brightness) },
                                      set: { manager.setBrightness(Float($0)) }), in: 0.05...1.0)
                    .disabled(manager.isAutoMode).opacity(manager.isAutoMode ? 0.5 : 1)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Color Temperature", systemImage: "thermometer.medium")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    Spacer()
                    Text(manager.isDarkroom ? "Darkroom" : "\(manager.colorTemp)K")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(manager.isDarkroom ? .red : .secondary)
                }
                Slider(value: Binding(get: { Double(manager.colorTemp) },
                                      set: { manager.setColorTemp(Int($0)) }),
                       in: 1200...6500, step: 100)
                    .tint(.orange)
                    .disabled(manager.isAutoMode || manager.isDarkroom)
                    .opacity(manager.isAutoMode || manager.isDarkroom ? 0.5 : 1)
                if !manager.isDarkroom {
                    Text(BlueLightManager.label(forKelvin: manager.colorTemp))
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(14).background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Presets").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                presetButton("Daylight", 6500, .cyan)
                presetButton("Halogen", 3400, .yellow)
                presetButton("Incandescent", 2700, .orange)
                presetButton("Candle", 1900, Color(red: 1, green: 0.6, blue: 0.2))
                presetButton("Ember", 1200, Color(red: 1, green: 0.3, blue: 0.1))
            }
        }
        .padding(14).background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func presetButton(_ name: String, _ kelvin: Int, _ color: Color) -> some View {
        let isActive = !manager.isDarkroom && manager.colorTemp == kelvin
        return Button { manager.applyPreset(kelvin) } label: {
            VStack(spacing: 4) {
                Circle().fill(color).frame(width: 20, height: 20)
                    .overlay(Circle().strokeBorder(.white.opacity(isActive ? 0.8 : 0), lineWidth: 2))
                Text(name).font(.system(size: 9))
                    .foregroundStyle(isActive ? .primary : .secondary)
            }.frame(maxWidth: .infinity)
        }.buttonStyle(.plain)
    }

    private var darkroomSection: some View {
        Button { manager.toggleDarkroom() } label: {
            HStack {
                Image(systemName: manager.isDarkroom ? "eye.slash.fill" : "eye.slash")
                    .foregroundStyle(manager.isDarkroom ? .red : .secondary).frame(width: 20)
                Text("Darkroom Mode").font(.system(size: 12, weight: .medium))
                Spacer()
                Text(manager.isDarkroom ? "ON" : "OFF")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(manager.isDarkroom ? .red : .gray)
            }
            .padding(14)
            .background(manager.isDarkroom ? Color.red.opacity(0.1) : .clear)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain)
    }

    private var scheduleSection: some View {
        VStack(spacing: 0) {
            DisclosureGroup(isExpanded: $showingSchedule) {
                VStack(spacing: 14) {
                    timeRow(icon: "sunrise.fill", color: .orange, label: "Sunrise",
                            time: Binding(get: { manager.sunriseDate }, set: { manager.sunriseDate = $0 }))
                    timeRow(icon: "sunset.fill", color: .pink, label: "Sunset",
                            time: Binding(get: { manager.sunsetDate }, set: { manager.sunsetDate = $0 }))
                    Divider()
                    scheduleSlider(label: "Day Brightness", value: $manager.dayBrightness,
                                   range: 0.1...1.0, format: { "\(Int($0 * 100))%" })
                    scheduleSlider(label: "Night Brightness", value: $manager.nightBrightness,
                                   range: 0.05...1.0, format: { "\(Int($0 * 100))%" })
                    nightTempSlider
                }.padding(.top, 10)
            } label: {
                Label("Schedule", systemImage: "clock.fill")
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .padding(14).background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var nightTempSlider: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Night Color Temp").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Text("\(manager.nightColorTemp)K").font(.system(size: 11, design: .rounded)).foregroundStyle(.tertiary)
            }
            Slider(value: Binding(get: { Double(manager.nightColorTemp) },
                                  set: { manager.nightColorTemp = Int($0); manager.update() }),
                   in: 1200...6500, step: 100).tint(.orange)
            Text(BlueLightManager.label(forKelvin: manager.nightColorTemp))
                .font(.system(size: 10)).foregroundStyle(.quaternary)
        }
    }

    private var footer: some View {
        HStack {
            Button("Reset") { manager.resetToDefaults() }
                .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
            Button("Quit SunScreen") {
                BlueLightManager.reset()
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.red)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private func timeRow(icon: String, color: Color, label: String, time: Binding<Date>) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(color).frame(width: 20)
            Text(label).font(.system(size: 12))
            Spacer()
            DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                .labelsHidden().frame(width: 100)
        }
    }

    private func scheduleSlider(label: String, value: Binding<Float>,
                                range: ClosedRange<Double>,
                                format: @escaping (Float) -> String,
                                tint: Color = .accentColor) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Text(format(value.wrappedValue)).font(.system(size: 11, design: .rounded)).foregroundStyle(.tertiary)
            }
            Slider(value: Binding(get: { Double(value.wrappedValue) },
                                  set: { value.wrappedValue = Float($0); manager.update() }),
                   in: range).tint(tint)
        }
    }

    private var headerIcon: String {
        if manager.isDarkroom { return "eye.slash.fill" }
        if manager.colorTemp < 3000 { return "moon.stars.fill" }
        if manager.colorTemp < 5000 { return "moon.fill" }
        return "sun.max.fill"
    }

    private var headerColors: [Color] {
        if manager.isDarkroom { return [.red, Color(red: 0.5, green: 0, blue: 0)] }
        if manager.colorTemp < 3000 { return [.orange, .yellow] }
        if manager.colorTemp < 5000 { return [.orange, .cyan] }
        return [.blue, .cyan]
    }

    private var statusText: String {
        if manager.isDarkroom { return "Darkroom mode" }
        let tempLabel = "\(manager.colorTemp)K · \(BlueLightManager.label(forKelvin: manager.colorTemp))"
        if manager.isAutoMode {
            if manager.colorTemp < 3000 { return "Night mode · \(manager.colorTemp)K" }
            if manager.colorTemp < 6500 { return "Transitioning · \(manager.colorTemp)K" }
            return "Daytime · 6500K"
        }
        return "Manual · \(tempLabel)"
    }
}

// MARK: - App Delegate (mirrors SnipTool's pattern)

class SunScreenApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let scheduleManager = ScheduleManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.scheduleManager.start()
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self?.scheduleManager.update() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        BlueLightManager.reset()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.isVisible = true
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "SunScreen")
        }

        let menu = NSMenu()

        let viewItem = NSMenuItem()
        let hosting = NSHostingController(rootView: ContentView(manager: scheduleManager))
        hosting.view.frame = NSRect(x: 0, y: 0, width: 320, height: 520)
        viewItem.view = hosting.view
        menu.addItem(viewItem)

        statusItem.menu = menu
    }
}

// MARK: - Launch (exactly like SnipTool)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = SunScreenApp()
app.delegate = delegate
app.run()
