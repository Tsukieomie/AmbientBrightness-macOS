//
// AmbientLightHID.c
// AmbientBrightness
//
// Uses BezelServices (private) via dlopen to read ambient light on Macs
// where AppleLMUController is not available (e.g. some Apple Silicon).
//

#include "AmbientLightHID.h"
#include <dlfcn.h>
#include <stdlib.h>
#include <CoreFoundation/CoreFoundation.h>

#define kAmbientLightSensorEvent 12
#define IOHIDEventFieldBase(type) ((type) << 16)

typedef const struct __IOHIDServiceClient* IOHIDServiceClientRef;
typedef const struct __IOHIDEvent* IOHIDEventRef;

typedef IOHIDServiceClientRef (*ALCALSCopyALSServiceClientFunc)(void);
typedef IOHIDEventRef (*IOHIDServiceClientCopyEventFunc)(IOHIDServiceClientRef, int64_t, int32_t, int64_t);
typedef double (*IOHIDEventGetFloatValueFunc)(IOHIDEventRef, int32_t);

static void* s_bezelHandle;
static void* s_hidHandle;
static ALCALSCopyALSServiceClientFunc s_ALCopy;
static IOHIDServiceClientCopyEventFunc s_copyEvent;
static IOHIDEventGetFloatValueFunc s_getFloat;
static IOHIDServiceClientRef s_client;

int AmbientLightHIDInit(void) {
    if (s_client != NULL) return 0;
    s_bezelHandle = dlopen("/System/Library/PrivateFrameworks/BezelServices.framework/BezelServices", RTLD_LAZY);
    if (!s_bezelHandle) return -1;
    s_ALCopy = (ALCALSCopyALSServiceClientFunc)dlsym(s_bezelHandle, "ALCALSCopyALSServiceClient");
    if (!s_ALCopy) { dlclose(s_bezelHandle); s_bezelHandle = NULL; return -1; }
    s_client = s_ALCopy();
    if (!s_client) { dlclose(s_bezelHandle); s_bezelHandle = NULL; return -1; }
    s_hidHandle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    if (!s_hidHandle) { CFRelease((CFTypeRef)s_client); s_client = NULL; dlclose(s_bezelHandle); s_bezelHandle = NULL; return -1; }
    s_copyEvent = (IOHIDServiceClientCopyEventFunc)dlsym(s_hidHandle, "IOHIDServiceClientCopyEvent");
    s_getFloat = (IOHIDEventGetFloatValueFunc)dlsym(s_hidHandle, "IOHIDEventGetFloatValue");
    if (!s_copyEvent || !s_getFloat) {
        AmbientLightHIDShutdown();
        return -1;
    }
    return 0;
}

int AmbientLightHIDRead(float* outValue) {
    if (!outValue || !s_client || !s_copyEvent || !s_getFloat) return -1;
    IOHIDEventRef event = s_copyEvent(s_client, kAmbientLightSensorEvent, 0, 0);
    if (!event) return -1;
    double raw = s_getFloat(event, IOHIDEventFieldBase(kAmbientLightSensorEvent));
    CFRelease(event);
    if (raw < 0) raw = 0;
    if (raw > 1) raw = raw / 400.0;
    if (raw > 1) raw = 1;
    *outValue = (float)raw;
    return 0;
}

void AmbientLightHIDShutdown(void) {
    if (s_client) { CFRelease((CFTypeRef)s_client); s_client = NULL; }
    if (s_bezelHandle) { dlclose(s_bezelHandle); s_bezelHandle = NULL; }
    if (s_hidHandle) { dlclose(s_hidHandle); s_hidHandle = NULL; }
    s_ALCopy = NULL;
    s_copyEvent = NULL;
    s_getFloat = NULL;
}
