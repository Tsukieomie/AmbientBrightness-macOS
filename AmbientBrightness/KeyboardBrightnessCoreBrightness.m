//
// KeyboardBrightnessCoreBrightness.m
// AmbientBrightness
//
// Uses CoreBrightness.framework KeyboardBrightnessClient (private API).
//

#import "KeyboardBrightnessCoreBrightness.h"

// C exports for Swift (no bridging header dependency)
int KeyboardBrightnessCB_IsAvailable(void) {
    return [KeyboardBrightnessCoreBrightness isAvailable] ? 1 : 0;
}
float KeyboardBrightnessCB_Get(void) {
    return [KeyboardBrightnessCoreBrightness getBrightness];
}
int KeyboardBrightnessCB_Set(float value) {
    return [KeyboardBrightnessCoreBrightness setBrightness:value] ? 1 : 0;
}

static NSObject* _client = nil;
static NSArray* _keyboardIDs = nil;
static BOOL _triedLoad = NO;
static BOOL _available = NO;

@implementation KeyboardBrightnessCoreBrightness

+ (void)loadFrameworkIfNeeded {
    if (_triedLoad) return;
    _triedLoad = YES;
    NSBundle* bundle = [NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/CoreBrightness.framework"];
    if (![bundle load]) return;
    Class cls = NSClassFromString(@"KeyboardBrightnessClient");
    if (!cls) return;
    _client = [[cls alloc] init];
    if (!_client) return;
    SEL copyIDs = NSSelectorFromString(@"copyKeyboardBacklightIDs");
    if (![_client respondsToSelector:copyIDs]) return;
    NSInvocation* inv = [NSInvocation invocationWithMethodSignature:[_client methodSignatureForSelector:copyIDs]];
    [inv setTarget:_client];
    [inv setSelector:copyIDs];
    [inv invoke];
    void* result = nil;
    [inv getReturnValue:&result];
    _keyboardIDs = (__bridge_transfer NSArray*)result;
    if (!_keyboardIDs || _keyboardIDs.count == 0) return;
    NSNumber* firstID = _keyboardIDs.firstObject;
    if (![firstID isKindOfClass:[NSNumber class]]) return;
    unsigned long long kbdID = firstID.unsignedLongLongValue;
    SEL isBuiltIn = NSSelectorFromString(@"isKeyboardBuiltIn:");
    if ([_client respondsToSelector:isBuiltIn]) {
        NSInvocation* inv2 = [NSInvocation invocationWithMethodSignature:[_client methodSignatureForSelector:isBuiltIn]];
        [inv2 setTarget:_client];
        [inv2 setSelector:isBuiltIn];
        [inv2 setArgument:&kbdID atIndex:2];
        [inv2 invoke];
        BOOL builtIn = NO;
        [inv2 getReturnValue:&builtIn];
        if (!builtIn) return;
    }
    _available = YES;
}

+ (BOOL)isAvailable {
    [self loadFrameworkIfNeeded];
    return _available;
}

+ (float)getBrightness {
    if (!_available) [self loadFrameworkIfNeeded];
    if (!_available || !_client || _keyboardIDs.count == 0) return -1.0f;
    NSNumber* firstID = _keyboardIDs.firstObject;
    unsigned long long kbdID = firstID.unsignedLongLongValue;
    SEL sel = NSSelectorFromString(@"brightnessForKeyboard:");
    if (![_client respondsToSelector:sel]) return -1.0f;
    NSInvocation* inv = [NSInvocation invocationWithMethodSignature:[_client methodSignatureForSelector:sel]];
    [inv setTarget:_client];
    [inv setSelector:sel];
    [inv setArgument:&kbdID atIndex:2];
    [inv invoke];
    float value = -1.0f;
    [inv getReturnValue:&value];
    return value;
}

+ (BOOL)setBrightness:(float)value {
    if (!_available) [self loadFrameworkIfNeeded];
    if (!_available || !_client || _keyboardIDs.count == 0) return NO;
    NSNumber* firstID = _keyboardIDs.firstObject;
    unsigned long long kbdID = firstID.unsignedLongLongValue;
    float clamped = value < 0 ? 0 : (value > 1 ? 1 : value);
    SEL sel = NSSelectorFromString(@"setBrightness:forKeyboard:");
    if (![_client respondsToSelector:sel]) return NO;
    NSInvocation* inv = [NSInvocation invocationWithMethodSignature:[_client methodSignatureForSelector:sel]];
    [inv setTarget:_client];
    [inv setSelector:sel];
    [inv setArgument:&clamped atIndex:2];
    [inv setArgument:&kbdID atIndex:3];
    [inv invoke];
    BOOL success = NO;
    [inv getReturnValue:&success];
    return success;
}

@end
