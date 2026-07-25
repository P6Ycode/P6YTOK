# P6YCompat Login-Safe Mode

P6YCompat is the first-pass compatibility layer for the IPA-injected P6YTOK target.

It is intentionally not a DouX-style all-in bypass port. The goal is narrower and safer:

1. Let the injected P6YTOK dylib load at TikTok startup.
2. Keep tweak feature groups asleep while TikTok is on login, onboarding, verification, or account-recovery screens.
3. Enable P6YTOK feature groups only after the normal TikTok app UI is visible.
4. Log safe diagnostics about version, IPA-style injection, visible controller class names, and feature-group state.

## Files

- `P6YCompatCore.h` / `P6YCompatCore.m`
  - login-safe state
  - delayed feature-group state
  - TikTok version detection
  - IPA-style injection detection
  - class/selector availability helpers
  - safe logging

- `P6YDelayedInit.xm`
  - always-loaded Logos observer
  - hooks `UIViewController viewDidAppear:` only to watch screen transitions
  - flips out of login-safe mode when the visible controller looks like main TikTok UI

- `P6YDelayedGroups.xm`
  - coordinator that fires when delayed feature groups become eligible
  - placeholder for `%init(P6YDownloads)`, `%init(P6YFeedUI)`, and other migrated groups

- `P6YFeatureGate.h`
  - bridge helpers for existing hooks while moving them into delayed Logos groups

## Build integration

Add the compat files to the tweak target's source list:

```make
P6YTOK_FILES += P6YCompat/P6YCompatCore.m P6YCompat/P6YDelayedInit.xm P6YCompat/P6YDelayedGroups.xm
```

If the project still uses the original BHTikTok target name, use that variable instead:

```make
BHTikTok_FILES += P6YCompat/P6YCompatCore.m P6YCompat/P6YDelayedInit.xm P6YCompat/P6YDelayedGroups.xm
```

The repo connector did not expose the current source Makefile path during this pass, so this branch adds the module and integration instructions without guessing a build-file location.

## Moving hooks to Option B delayed groups

Preferred shape:

```logos
#import "P6YCompat/P6YCompatCore.h"

%group P6YDownloads

%hook SomeTikTokDownloadClass
// existing download hook body
%end

%end
```

Then initialize that group from `P6YDelayedGroups.xm` only after `P6YCompatDidEnableFeatureGroupsNotification` fires:

```logos
if (P6YCompatShouldRunFeatureGroup(P6YCompatFeatureGroupDownloads)) {
    %init(P6YDownloads);
}
```

For hooks that cannot be moved immediately, use `P6YFeatureGate.h` as a bridge:

```logos
#import "P6YCompat/P6YFeatureGate.h"

%hook SomeExistingFeedClass
- (void)someMethod {
    if (!P6Y_COMPAT_CAN_RUN_FEED_UI()) {
        return %orig;
    }

    // existing tweak behavior
}
%end
```

This bridge is less clean than delayed `%group` initialization, but it keeps the first migration manageable.

## Runtime flags

All flags live in `NSUserDefaults` and default to login-safe behavior.

| Key | Default | Purpose |
| --- | --- | --- |
| `P6YCompatEnabled` | `YES` | Master switch for the compat layer. |
| `P6YCompatForceLoginSafeMode` | `NO` | Keeps all delayed feature groups off even after main UI detection. |
| `P6YCompatManualFeatureEnable` | `NO` | Allows manually enabling delayed groups without main-UI detection. Useful for early test builds. |
| `P6YCompatDebugLogging` | `YES` | Emits safe controller/version/state logs through `os_log`. |
| `P6YCompatGroup.<group>.enabled` | `YES` | Per-group feature toggle, where `<group>` is `settings`, `downloads`, `feed-ui`, `profile`, `ad-filtering`, or `browser-redirects`. |

## Explicit non-goals

This module does not hook or alter:

- Keychain
- Apple Passwords / password autofill
- login request bodies
- authentication tokens
- cookies
- `NSURLSession`
- TLS or certificate validation
- device identifiers
- install identifiers
- carrier state
- region state

Those areas are deliberately out of scope for the IPA login-safe build.
