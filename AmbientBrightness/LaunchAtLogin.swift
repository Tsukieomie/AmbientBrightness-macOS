//
// LaunchAtLogin.swift
// AmbientBrightness
//
// Registers the app as a login item so it starts automatically.
//

import Foundation
import ServiceManagement

enum LaunchAtLogin {
    private static let key = "launchAtLogin"
    
    static var enabled: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            }
            return UserDefaults.standard.bool(forKey: key)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    UserDefaults.standard.set(!newValue, forKey: key)
                }
            }
        }
    }
    
    static var isSupportedOnCurrentOS: Bool {
        if #available(macOS 13.0, *) { return true }
        return false
    }
}
