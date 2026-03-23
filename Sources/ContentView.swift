import SwiftUI

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

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: headerColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: headerIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("SunScreen")
                    .font(.system(size: 14, weight: .semibold))
                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $manager.isAutoMode)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .onChange(of: manager.isAutoMode) { _, _ in
                    manager.update()
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Color indicator bar

    private var warmthBar: some View {
        let progress = Double(6500 - manager.colorTemp) / Double(6500 - 1200)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .cyan, .yellow, .orange, .red],
                            startPoint: .trailing,
                            endPoint: .leading
                        )
                    )
                    .opacity(0.3)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .orange],
                            startPoint: .trailing,
                            endPoint: .leading
                        )
                    )
                    .frame(width: max(8, geo.size.width * CGFloat(manager.isDarkroom ? 1.0 : progress)))
            }
        }
        .frame(height: 4)
        .clipShape(Capsule())
    }

    // MARK: - Brightness & color temp sliders

    private var sliderSection: some View {
        VStack(spacing: 14) {
            // Brightness
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Brightness", systemImage: "sun.min.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(manager.brightness * 100))%")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { Double(manager.brightness) },
                        set: { manager.setBrightness(Float($0)) }
                    ),
                    in: 0.05...1.0
                )
                .disabled(manager.isAutoMode)
                .opacity(manager.isAutoMode ? 0.5 : 1.0)
            }

            // Color Temperature
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Color Temperature", systemImage: "thermometer.medium")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(manager.isDarkroom ? "Darkroom" : "\(manager.colorTemp)K")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(manager.isDarkroom ? .red : .secondary)
                }

                Slider(
                    value: Binding(
                        get: { Double(manager.colorTemp) },
                        set: { manager.setColorTemp(Int($0)) }
                    ),
                    in: 1200...6500,
                    step: 100
                )
                .tint(.orange)
                .disabled(manager.isAutoMode || manager.isDarkroom)
                .opacity(manager.isAutoMode || manager.isDarkroom ? 0.5 : 1.0)

                if !manager.isDarkroom {
                    Text(BlueLightManager.label(forKelvin: manager.colorTemp))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Presets

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Presets")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                presetButton("Daylight",     6500, .cyan)
                presetButton("Halogen",      3400, .yellow)
                presetButton("Incandescent", 2700, .orange)
                presetButton("Candle",       1900, Color(red: 1.0, green: 0.6, blue: 0.2))
                presetButton("Ember",        1200, Color(red: 1.0, green: 0.3, blue: 0.1))
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func presetButton(_ name: String, _ kelvin: Int, _ color: Color) -> some View {
        let isActive = !manager.isDarkroom && manager.colorTemp == kelvin
        return Button {
            manager.applyPreset(kelvin)
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(isActive ? 0.8 : 0), lineWidth: 2)
                    )
                Text(name)
                    .font(.system(size: 9))
                    .foregroundStyle(isActive ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Darkroom

    private var darkroomSection: some View {
        Button {
            manager.toggleDarkroom()
        } label: {
            HStack {
                Image(systemName: manager.isDarkroom ? "eye.slash.fill" : "eye.slash")
                    .foregroundStyle(manager.isDarkroom ? .red : .secondary)
                    .frame(width: 20)

                Text("Darkroom Mode")
                    .font(.system(size: 12, weight: .medium))

                Spacer()

                Text(manager.isDarkroom ? "ON" : "OFF")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(manager.isDarkroom ? Color.red : Color.gray)
            }
            .padding(14)
            .background(
                manager.isDarkroom
                    ? Color.red.opacity(0.1)
                    : Color.clear
            )
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        VStack(spacing: 0) {
            DisclosureGroup(isExpanded: $showingSchedule) {
                VStack(spacing: 14) {
                    timeRow(
                        icon: "sunrise.fill", color: .orange,
                        label: "Sunrise",
                        time: Binding(
                            get: { manager.sunriseDate },
                            set: { manager.sunriseDate = $0 }
                        )
                    )
                    timeRow(
                        icon: "sunset.fill", color: .pink,
                        label: "Sunset",
                        time: Binding(
                            get: { manager.sunsetDate },
                            set: { manager.sunsetDate = $0 }
                        )
                    )

                    Divider()

                    scheduleSlider(
                        label: "Day Brightness",
                        value: $manager.dayBrightness,
                        range: 0.1...1.0,
                        format: { "\(Int($0 * 100))%" }
                    )
                    scheduleSlider(
                        label: "Night Brightness",
                        value: $manager.nightBrightness,
                        range: 0.05...1.0,
                        format: { "\(Int($0 * 100))%" }
                    )
                    nightTempSlider
                }
                .padding(.top, 10)
            } label: {
                Label("Schedule", systemImage: "clock.fill")
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var nightTempSlider: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Night Color Temp")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(manager.nightColorTemp)K")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            Slider(
                value: Binding(
                    get: { Double(manager.nightColorTemp) },
                    set: {
                        manager.nightColorTemp = Int($0)
                        manager.update()
                    }
                ),
                in: 1200...6500,
                step: 100
            )
            .tint(.orange)

            Text(BlueLightManager.label(forKelvin: manager.nightColorTemp))
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Reset") {
                manager.resetToDefaults()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)

            Spacer()

            Button("Quit SunScreen") {
                BlueLightManager.reset()
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Reusable pieces

    private func timeRow(
        icon: String, color: Color,
        label: String, time: Binding<Date>
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 12))
            Spacer()
            DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .frame(width: 100)
        }
    }

    private func scheduleSlider(
        label: String,
        value: Binding<Float>,
        range: ClosedRange<Double>,
        format: @escaping (Float) -> String,
        tint: Color = .accentColor
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(format(value.wrappedValue))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: {
                        value.wrappedValue = Float($0)
                        manager.update()
                    }
                ),
                in: range
            )
            .tint(tint)
        }
    }

    // MARK: - Helpers

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
