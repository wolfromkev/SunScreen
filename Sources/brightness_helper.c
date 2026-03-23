#include <IOKit/graphics/IOGraphicsLib.h>
#include <IOKit/IOKitLib.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>

/*
 * Uses Apple's private DisplayServices framework (the same API the
 * keyboard brightness keys invoke) for true hardware backlight control.
 * Falls back to IOKit for external displays or older Macs.
 */

typedef int (*DSSetBrightness)(CGDirectDisplayID, float);
typedef int (*DSGetBrightness)(CGDirectDisplayID, float *);

static void *ds_handle(void) {
    static void *h = NULL;
    static int tried = 0;
    if (!tried) {
        tried = 1;
        h = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_LAZY
        );
    }
    return h;
}

static CFStringRef brightness_key(void) {
    return CFSTR("brightness");
}

/* ── Read brightness ─────────────────────────────────────────────── */

float get_display_brightness(void) {
    /* Try DisplayServices first (built-in display) */
    void *h = ds_handle();
    if (h) {
        DSGetBrightness fn = (DSGetBrightness)dlsym(h, "DisplayServicesGetBrightness");
        if (fn) {
            float level = 0;
            if (fn(CGMainDisplayID(), &level) == 0) {
                return level;
            }
        }
    }

    /* Fallback: IOKit (external displays, older systems) */
    float brightness = 1.0f;
    io_iterator_t iterator;
    kern_return_t result = IOServiceGetMatchingServices(
        kIOMainPortDefault,
        IOServiceMatching("IODisplayConnect"),
        &iterator
    );
    if (result != kIOReturnSuccess) return brightness;

    io_object_t service;
    while ((service = IOIteratorNext(iterator)) != 0) {
        float level;
        kern_return_t err = IODisplayGetFloatParameter(
            service, 0, brightness_key(), &level
        );
        if (err == kIOReturnSuccess) {
            brightness = level;
        }
        IOObjectRelease(service);
    }
    IOObjectRelease(iterator);
    return brightness;
}

/* ── Set brightness ──────────────────────────────────────────────── */

void set_display_brightness(float level) {
    if (level < 0.0f) level = 0.0f;
    if (level > 1.0f) level = 1.0f;

    /* Try DisplayServices first (built-in display) */
    void *h = ds_handle();
    if (h) {
        DSSetBrightness fn = (DSSetBrightness)dlsym(h, "DisplayServicesSetBrightness");
        if (fn) {
            if (fn(CGMainDisplayID(), level) == 0) {
                return;
            }
        }
    }

    /* Fallback: IOKit */
    io_iterator_t iterator;
    kern_return_t result = IOServiceGetMatchingServices(
        kIOMainPortDefault,
        IOServiceMatching("IODisplayConnect"),
        &iterator
    );
    if (result != kIOReturnSuccess) return;

    io_object_t service;
    while ((service = IOIteratorNext(iterator)) != 0) {
        IODisplaySetFloatParameter(service, 0, brightness_key(), level);
        IOObjectRelease(service);
    }
    IOObjectRelease(iterator);
}
