//
// SettingsView.swift
// AmbientBrightness
//

import SwiftUI
import Combine

struct SettingsView: View {
    @ObservedObject var engine = AutoBrightnessEngine.shared
    @State private var launchAtLogin: Bool = LaunchAtLogin.enabled
    @State private var now: Date = Date()
    @State private var timerCancellable: Cancellable?
    
    private let tick = Timer.publish(every: 1, on: .main, in: .common)
    
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { newValue in
                launchAtLogin = newValue
                LaunchAtLogin.enabled = newValue
            }
        )
    }
    
    private let labelWidth: CGFloat = 120
    private let valueWidth: CGFloat = 44
    
    var body: some View {
        Form {
            Section("Status") {
                    if engine.sensorAvailable {
                        statusRow("Ambient sensor", "Available")
                        if let a = engine.lastAmbient {
                            statusRow("Current ambient", "\(Int(a * 100))%")
                        }
                        statusRow("Scan interval", String(format: "every %.0f seconds", engine.pollIntervalSeconds))
                        if let scanDate = engine.lastScanDate {
                            statusRow("Last scanned", relativeTime(scanDate))
                        } else if engine.isRunning {
                            statusRow("Last scanned", "waiting for first scan...")
                        }
                        statusRow(
                            "Keyboard backlight",
                            engine.keyboardControlAvailable ? "Available" : "Not available (display-only)"
                        )
                    } else {
                        Text("No ambient light sensor found. This app only works on MacBooks with a built-in sensor.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Section("Automation") {
                    Toggle("Launch at login", isOn: launchAtLoginBinding)
                        .disabled(!LaunchAtLogin.isSupportedOnCurrentOS)
                    if !LaunchAtLogin.isSupportedOnCurrentOS {
                        Text("Requires macOS 13 or later")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Toggle("Adjust display brightness", isOn: $engine.adjustDisplay)
                    Toggle("Adjust keyboard brightness", isOn: $engine.adjustKeyboard)
                        .disabled(!engine.keyboardControlAvailable)
                    HStack(spacing: 12) {
                        Text("Poll interval (sec)")
                            .frame(width: labelWidth, alignment: .leading)
                        TextField("", value: $engine.pollIntervalSeconds, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 56)
                        Spacer(minLength: 0)
                    }
                }
                Section("Display range") {
                    sliderRow(label: "Min", value: $engine.displayMin)
                    sliderRow(label: "Max", value: $engine.displayMax)
                }
                Section("Keyboard range") {
                    sliderRow(label: "Min", value: $engine.keyboardMin)
                    sliderRow(label: "Max", value: $engine.keyboardMax)
                }
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 460)
        .onAppear {
            launchAtLogin = LaunchAtLogin.enabled
            now = Date()
            timerCancellable = tick.connect()
        }
        .onReceive(tick) { now = $0 }
        .onDisappear { timerCancellable?.cancel() }
    }
    
    private func relativeTime(_ date: Date) -> String {
        let s = Int(-date.timeIntervalSince(now))
        if s < 5 { return "just now" }
        if s < 60 { return "\(s)s ago" }
        let m = s / 60
        if m < 60 { return "\(m)m ago" }
        let h = m / 60
        return "\(h)h ago"
    }
    
    private func statusRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label + ":")
                .frame(width: labelWidth, alignment: .leading)
                .foregroundColor(.secondary)
            Text(value)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
    
    private func sliderRow(label: String, value: Binding<Float>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .frame(width: 32, alignment: .leading)
            Slider(value: value, in: 0...1)
            Text(String(format: "%.0f%%", value.wrappedValue * 100))
                .frame(width: valueWidth, alignment: .trailing)
                .monospacedDigit()
        }
    }
}
