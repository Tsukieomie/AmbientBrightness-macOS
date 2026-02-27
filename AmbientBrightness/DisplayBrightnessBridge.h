//
// DisplayBrightnessBridge.h
// AmbientBrightness
//
// C bridge for IODisplay brightness (IOKit/graphics may not be in Swift module).
//

#ifndef DisplayBrightnessBridge_h
#define DisplayBrightnessBridge_h

#include <IOKit/IOKitLib.h>
#include <CoreFoundation/CoreFoundation.h>

#ifdef __cplusplus
extern "C" {
#endif

int DisplayBrightnessBridgeGet(io_service_t service, float *outValue);
int DisplayBrightnessBridgeSet(io_service_t service, float value);

#ifdef __cplusplus
}
#endif

#endif /* DisplayBrightnessBridge_h */
