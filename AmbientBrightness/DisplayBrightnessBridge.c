//
// DisplayBrightnessBridge.c
// AmbientBrightness
//

#include "DisplayBrightnessBridge.h"
#include <IOKit/graphics/IOGraphicsLib.h>

/* Use IOKit macro for the key name (IOGraphicsTypes.h defines kIODisplayBrightnessKey as "brightness") */
#define OUR_BRIGHTNESS_KEY kIODisplayBrightnessKey

int DisplayBrightnessBridgeGet(io_service_t service, float *outValue) {
    if (!outValue) return -1;
    CFStringRef key = CFStringCreateWithCString(kCFAllocatorDefault, OUR_BRIGHTNESS_KEY, kCFStringEncodingUTF8);
    if (!key) return -1;
    kern_return_t kr = IODisplayGetFloatParameter(service, 0, key, outValue);
    CFRelease(key);
    return (kr == kIOReturnSuccess) ? 0 : -1;
}

int DisplayBrightnessBridgeSet(io_service_t service, float value) {
    CFStringRef key = CFStringCreateWithCString(kCFAllocatorDefault, OUR_BRIGHTNESS_KEY, kCFStringEncodingUTF8);
    if (!key) return -1;
    kern_return_t kr = IODisplaySetFloatParameter(service, 0, key, value);
    CFRelease(key);
    return (kr == kIOReturnSuccess) ? 0 : -1;
}
