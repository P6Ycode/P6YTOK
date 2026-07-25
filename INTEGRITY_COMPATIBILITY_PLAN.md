# P6YTOK Integrity Compatibility Research Plan

> **Status:** Implementation started in `P6YCompat/`.
>
> **Initial target:** P6YTOK injected into a patched TikTok 46.1.0 IPA.
>
> **Later target:** Evaluate a separate rootless `.deb` only after IPA testing is complete.

## Purpose

This document records the investigation into why a modified TikTok IPA may fail login or behave differently from the official App Store installation.

The goal is to separate three possible causes:

1. A normal P6YTOK feature or hook is interfering with startup or login.
2. TikTok is detecting local differences in the modified application environment.
3. TikTok's backend is rejecting the re-signed installation independently of local application behavior.

## Current Implementation Direction

The first implementation pass is login-safe mode, not a broad DouX-style bypass port.

The new `P6YCompat/` module keeps P6YTOK present but quiet while TikTok is on login-sensitive screens. It loads a tiny observer and safe diagnostics at startup, then enables delayed feature groups only after the app appears to have reached normal TikTok UI.

```text
Launch patched TikTok IPA
        ↓
iOS loads injected P6YTOK dylib
        ↓
P6YCompat bootstraps in login-safe mode
        ↓
Login/onboarding/auth screens run with P6YTOK feature groups off
        ↓
P6YCompat observes main TikTok UI
        ↓
Delayed P6YTOK feature groups become eligible to initialize
        ↓
Tweaks can be enabled in controlled groups
```

## How This Differs From Older DouX/BHTikTok Code

Older projects relied on fixed assumptions about TikTok's internal classes and older jailbreak environments. Those assumptions may no longer match TikTok 46.1.0.

A current P6YTOK approach should instead:

- Detect classes and selectors at runtime before enabling related behavior.
- Avoid crashing when TikTok renames or removes internal classes.
- Keep IPA behavior separate from any future rootless `.deb` behavior.
- Test changes in small independent groups rather than enabling many compatibility changes at once.
- Include a single kill switch so the diagnostics or compatibility module can be disabled without rebuilding the whole tweak.
- Keep feature groups off during login until the normal app UI is visible.

## IPA and Rootless `.deb` Are Different Environments

### Patched IPA

A patched IPA is decrypted, modified, injected, and re-signed. This can change properties that cannot be fully reproduced from inside the running app.

This is the first target for P6YCompat.

### Rootless `.deb`

A rootless tweak can inject into the official App Store installation, allowing the original application signature and receipt to remain present. This creates a different test environment and should be evaluated separately.

The IPA build remains the first priority.

## Required Safety Boundaries

The proposed diagnostics and compatibility work must not modify or intercept:

- Keychain operations
- Password autofill
- Login request bodies
- Authentication tokens
- Cookies
- `NSURLSession` traffic
- TLS or certificate validation
- Device identifiers
- Install identifiers
- Carrier information
- Region information

The previous global Keychain workaround was removed because it could interfere with login and Apple Passwords. It must not be reintroduced.

## Runtime Diagnostics

The diagnostics module may record only non-sensitive compatibility information such as:

- Whether an expected TikTok class exists
- Whether an expected selector exists
- Whether a P6YTOK feature module initialized successfully
- Whether a feature was disabled because its target API was unavailable
- The active TikTok application version
- Whether the build appears to be running as a patched IPA
- Visible controller class names used for login-safe/main-UI detection

Diagnostics must never record passwords, tokens, Keychain contents, private messages, login payloads, cookies, or account data.

## Targeted Testing

Changes should be evaluated individually. Large combined changes make it impossible to identify what affected login behavior.

Recommended test order:

```text
1. P6YTOK IPA without any new compatibility module
2. P6YTOK IPA with P6YCompat login-safe diagnostics only
3. P6YTOK IPA with delayed settings shell only
4. P6YTOK IPA with downloads enabled after login
5. P6YTOK IPA with feed/UI features enabled after login
6. P6YTOK IPA with profile features enabled after login
7. Repeat with each additional group separately
```

For every build, record:

- TikTok version
- P6YTOK commit
- Signing or sideload method
- Whether Apple Passwords works
- Whether login reaches the server
- Exact error message
- Whether the same account works in the official App Store TikTok app
- Which P6YCompat groups were enabled

## Important Limitation

Code running inside the patched IPA cannot truly recreate:

- TikTok's original Apple signature
- The original App Store receipt
- Apple server-side attestation
- TikTok backend knowledge that the application was modified or re-signed

Therefore, local compatibility changes cannot guarantee that the IPA will log in. The error **"Maximum number of attempts reached"** may still occur if TikTok's backend rejects the sideloaded installation or signing identity.

## Current Repository State

`P6YCompat/` now contains the first login-safe compatibility module:

- `P6YCompatCore.h`
- `P6YCompatCore.m`
- `P6YDelayedInit.xm`
- `P6YDelayedGroups.xm`
- `P6YFeatureGate.h`
- `README.md`

The connector did not expose the current source Makefile path during this pass, so the module is added with integration instructions instead of guessing the build-file location.
