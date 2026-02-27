//
// AmbientBrightnessApp.swift
// AmbientBrightness
//
// Menu bar app: auto-adjust built-in display and keyboard from ambient light.
//

import SwiftUI
import AppKit

@main
struct AmbientBrightnessApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "Ambient Brightness")
            button.action = #selector(showMenu)
            button.target = self
        }
        let engine = AutoBrightnessEngine.shared
        if engine.sensorAvailable && !engine.isRunning {
            engine.start()
        }
    }
    
    @objc private func showMenu() {
        guard let item = statusItem else { return }
        let menu = NSMenu()
        let e = AutoBrightnessEngine.shared
        if e.sensorAvailable {
            let title = e.isRunning ? "Pause automation" : "Start automation"
            let runItem = NSMenuItem(title: title, action: #selector(toggleRunning), keyEquivalent: "")
            runItem.target = self
            menu.addItem(runItem)
            menu.addItem(NSMenuItem.separator())
            if let ambient = e.lastAmbient {
                menu.addItem(NSMenuItem(title: String(format: "Ambient: %.0f%%", ambient * 100), action: nil, keyEquivalent: ""))
            }
            let kbdLine = e.keyboardControlAvailable ? "Keyboard: \(e.adjustKeyboard ? "On" : "Off")" : "Keyboard: display only (N/A on this Mac)"
            menu.addItem(NSMenuItem(title: "Display: \(e.adjustDisplay ? "On" : "Off")", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: kbdLine, action: nil, keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: "No ambient sensor found", action: nil, keyEquivalent: ""))
        }
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        for mi in menu.items where mi.action != nil {
            mi.target = self
        }
        item.menu = menu
    }
    
    @objc private func toggleRunning() {
        let e = AutoBrightnessEngine.shared
        if e.isRunning { e.stop() } else { e.start() }
    }
    
    @objc private func openSettings() {
        if settingsWindow == nil {
            let content = SettingsView()
            let hosting = NSHostingView(rootView: content)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "AmbientBrightness"
            window.contentView = hosting
            window.center()
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 440, height: 480)
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
