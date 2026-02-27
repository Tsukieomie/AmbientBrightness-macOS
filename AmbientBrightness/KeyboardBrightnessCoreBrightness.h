//
// KeyboardBrightnessCoreBrightness.h
// AmbientBrightness
//
// Optional keyboard backlight control via CoreBrightness (private) for
// MacBook Air M4 and other Apple Silicon Macs where LMU is not available.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KeyboardBrightnessCoreBrightness : NSObject

/// Returns YES if CoreBrightness keyboard control is available and working.
+ (BOOL)isAvailable;

/// Current keyboard brightness 0.0..1.0, or -1 if unavailable.
+ (float)getBrightness;

/// Set keyboard brightness 0.0..1.0. Returns YES on success.
+ (BOOL)setBrightness:(float)value;

@end

// C API for Swift
int KeyboardBrightnessCB_IsAvailable(void);
float KeyboardBrightnessCB_Get(void);
int KeyboardBrightnessCB_Set(float value);

NS_ASSUME_NONNULL_END
