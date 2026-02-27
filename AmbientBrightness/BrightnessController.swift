//
// BrightnessController.swift
// AmbientBrightness
//
// Reads ambient light via AppleLMUController, maps to display and keyboard
// brightness. Based on LightKit and QMKAmbientBacklight/DarkModeBuddy approaches.
//

import Foundation
import IOKit
import AppKit

// C bridge for display brightness (DisplayBrightnessBridge.c)
@_silgen_name("DisplayBrightnessBridgeGet")
private func _displayGet(_ service: io_service_t, _ outValue: UnsafeMutablePointer<Float>) -> Int32
@_silgen_name("DisplayBrightnessBridgeSet")
private func _displaySet(_ service: io_service_t, _ value: Float) -> Int32

private func getDisplayBrightnessFromService(_ service: io_service_t) -> Float? {
    var value: Float = 0
    return _displayGet(service, &value) == 0 ? value : nil
}
private func setDisplayBrightnessOnService(_ service: io_service_t, _ value: Float) -> Bool {
    return _displaySet(service, value) == 0
}

// C bridge for HID ambient sensor (BezelServices path)
@_silgen_name("AmbientLightHIDInit")
private func _hidSensorInit() -> Int32
@_silgen_name("AmbientLightHIDRead")
private func _hidSensorRead(_ outValue: UnsafeMutablePointer<Float>) -> Int32
@_silgen_name("AmbientLightHIDShutdown")
private func _hidSensorShutdown()

// C bridge for CoreBrightness keyboard (e.g. M4 MacBook Air)
@_silgen_name("KeyboardBrightnessCB_IsAvailable")
private func _cbKeyboardAvailable() -> Int32
@_silgen_name("KeyboardBrightnessCB_Get")
private func _cbKeyboardGet() -> Float
@_silgen_name("KeyboardBrightnessCB_Set")
private func _cbKeyboardSet(_ value: Float) -> Int32

final class BrightnessController {
    
    // MARK: - LMU (sensor + keyboard)
    
    private var lmuDataPort: io_connect_t = 0
    private let kGetSensorReadingID: UInt32 = 0
    private let kGetLEDBrightnessID: UInt32 = 1
    private let kSetLEDBrightnessID: UInt32 = 2
    
    private func initLMU() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleLMUController"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        let kr = IOServiceOpen(service, mach_task_self_, 0, &lmuDataPort)
        return kr == KERN_SUCCESS
    }
    
    private func callScalar(selector: UInt32, inputs: [UInt64], outputCount: Int) -> [UInt64]? {
        var outCount = UInt32(outputCount)
        let outPtr = UnsafeMutablePointer<UInt64>.allocate(capacity: outputCount)
        defer { outPtr.deallocate() }
        let kr: kern_return_t
        if inputs.isEmpty {
            kr = IOConnectCallScalarMethod(lmuDataPort, selector, nil, 0, outPtr, &outCount)
        } else {
            var ins = inputs
            kr = ins.withUnsafeMutableBufferPointer { buf in
                IOConnectCallScalarMethod(lmuDataPort, selector, buf.baseAddress, UInt32(buf.count), outPtr, &outCount)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }
        return (0..<Int(outCount)).map { outPtr[$0] }
    }
    
    /// Ambient level 0...1 from LMU. Nil if not available.
    private func readAmbientFromLMU() -> Float? {
        guard let outputs = callScalar(selector: kGetSensorReadingID, inputs: [], outputCount: 2),
              outputs.count >= 2 else { return nil }
        let left = Float(outputs[0]) / 2000.0
        let right = Float(outputs[1]) / 2000.0
        let level = (left + right) / 2.0
        return max(0, min(1, level))
    }
    
    /// Ambient level 0...1 (LMU or HID). Nil if no sensor.
    func readAmbientLevel() -> Float? {
        if hasLMU, let level = readAmbientFromLMU() { return level }
        if hasHID {
            var value: Float = -1
            return _hidSensorRead(&value) == 0 ? max(0, min(1, value)) : nil
        }
        return nil
    }
    
    func getKeyboardBrightness() -> Float? {
        if hasLMU {
            guard let outputs = callScalar(selector: kGetLEDBrightnessID, inputs: [0], outputCount: 1),
                  let raw = outputs.first else { return nil }
            return Float(raw) / 4095.0
        }
        if hasCoreBrightnessKeyboard {
            let v = _cbKeyboardGet()
            return v >= 0 ? v : nil
        }
        return nil
    }
    
    func setKeyboardBrightness(_ value: Float) -> Bool {
        let clamped = max(0, min(1, value))
        if hasLMU {
            let raw = UInt64(clamped * 4095.0)
            let outputs = callScalar(selector: kSetLEDBrightnessID, inputs: [0, raw], outputCount: 1)
            return outputs != nil
        }
        if hasCoreBrightnessKeyboard {
            return _cbKeyboardSet(clamped) != 0
        }
        return false
    }
    
    // MARK: - Display
    
    func getDisplayBrightness() -> Float? {
        var iter: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iter)
        guard kr == kIOReturnSuccess else { return nil }
        defer { IOObjectRelease(iter) }
        var service = IOIteratorNext(iter)
        while service != 0 {
            defer { IOObjectRelease(service) }
            if let brightness = getDisplayBrightnessFromService(service) {
                return max(0, min(1, brightness))
            }
            service = IOIteratorNext(iter)
        }
        return nil
    }
    
    func setDisplayBrightness(_ value: Float) -> Bool {
        let clamped = max(0, min(1, value))
        var iter: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iter)
        guard kr == kIOReturnSuccess else { return false }
        defer { IOObjectRelease(iter) }
        var service = IOIteratorNext(iter)
        var ok = false
        while service != 0 {
            defer { IOObjectRelease(service) }
            if setDisplayBrightnessOnService(service, clamped) { ok = true }
            service = IOIteratorNext(iter)
        }
        return ok
    }
    
    // MARK: - Lifecycle
    
    private var hasLMU = false
    private var hasHID = false
    private var hasCoreBrightnessKeyboard = false
    
    var isSensorAvailable: Bool { hasLMU || hasHID }
    
    /// Keyboard: LMU (older Macs) or CoreBrightness (e.g. M4 MacBook Air).
    var isKeyboardControlAvailable: Bool {
        if hasLMU, getKeyboardBrightness() != nil { return true }
        if hasCoreBrightnessKeyboard { return true }
        return false
    }
    
    init?() {
        if initLMU() {
            hasLMU = true
            if getKeyboardBrightness() == nil, _cbKeyboardAvailable() != 0 {
                hasCoreBrightnessKeyboard = true
            }
        } else if _hidSensorInit() == 0 {
            hasHID = true
            if _cbKeyboardAvailable() != 0 {
                hasCoreBrightnessKeyboard = true
            }
        } else {
            return nil
        }
    }
    
    deinit {
        if lmuDataPort != 0 {
            IOConnectRelease(lmuDataPort)
        }
        if hasHID {
            _hidSensorShutdown()
        }
    }
    
    // MARK: - Mapping (ambient 0...1 -> brightness 0...1)
    
    /// Linear map: ambient [0,1] -> [minBrightness, maxBrightness].
    static func map(ambient: Float, minBrightness: Float, maxBrightness: Float) -> Float {
        let t = max(0, min(1, ambient))
        return minBrightness + t * (maxBrightness - minBrightness)
    }
}
