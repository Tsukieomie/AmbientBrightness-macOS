//
// AutoBrightnessEngine.swift
// AmbientBrightness
//
// Polls ambient sensor and applies display + keyboard brightness.
//

import Foundation
import AppKit

final class AutoBrightnessEngine: ObservableObject {
    
    @Published var isRunning = false
    @Published var lastAmbient: Float?
    @Published var displayMin: Float = 0.15
    @Published var displayMax: Float = 0.95
    @Published var keyboardMin: Float = 0
    @Published var keyboardMax: Float = 1.0
    @Published var pollIntervalSeconds: Double = 5.0
    @Published var adjustDisplay = true
    @Published var adjustKeyboard = true
    @Published var sensorAvailable = false
    @Published var keyboardControlAvailable = false
    
    private var controller: BrightnessController?
    private var timer: Timer?
    private let threshold: Float = 0.03  // avoid tiny updates
    
    init() {
        controller = BrightnessController()
        if let c = controller {
            sensorAvailable = c.isSensorAvailable
            keyboardControlAvailable = c.isKeyboardControlAvailable
        }
    }
    
    static let shared: AutoBrightnessEngine = AutoBrightnessEngine()
    
    func start() {
        guard let c = controller, sensorAvailable else { return }
        stop()
        isRunning = true
        applyOnce()
        timer = Timer.scheduledTimer(withTimeInterval: pollIntervalSeconds, repeats: true) { [weak self] _ in
            self?.applyOnce()
        }
        timer?.tolerance = pollIntervalSeconds * 0.2
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }
    
    private func applyOnce() {
        guard let c = controller, let ambient = c.readAmbientLevel() else {
            lastAmbient = nil
            return
        }
        lastAmbient = ambient
        
        if adjustDisplay {
            let targetDisplay = BrightnessController.map(ambient: ambient, minBrightness: displayMin, maxBrightness: displayMax)
            let currentDisplay = c.getDisplayBrightness()
            if currentDisplay == nil || abs(currentDisplay! - targetDisplay) > threshold {
                _ = c.setDisplayBrightness(targetDisplay)
            }
        }
        
        if adjustKeyboard && keyboardControlAvailable {
            let targetKbd = BrightnessController.map(ambient: ambient, minBrightness: keyboardMin, maxBrightness: keyboardMax)
            let currentKbd = c.getKeyboardBrightness()
            if currentKbd == nil || abs(currentKbd! - targetKbd) > threshold {
                _ = c.setKeyboardBrightness(targetKbd)
            }
        }
    }
}
