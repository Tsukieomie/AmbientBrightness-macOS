//
// AmbientLightHID.h
// AmbientBrightness
//
// HID-based ambient light sensor (BezelServices) for Macs that don't expose AppleLMUController.
//

#ifndef AmbientLightHID_h
#define AmbientLightHID_h

#ifdef __cplusplus
extern "C" {
#endif

// Returns 0 on success. Call before Read.
int AmbientLightHIDInit(void);

// Returns 0 on success; outValue is set to 0.0..1.0 (or -1 if unavailable).
int AmbientLightHIDRead(float* outValue);

void AmbientLightHIDShutdown(void);

#ifdef __cplusplus
}
#endif

#endif /* AmbientLightHID_h */
