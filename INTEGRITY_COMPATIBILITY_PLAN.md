# P6YTOK Integrity Compatibility Research Plan

> **Status:** Research and planning only. No integrity compatibility layer has been implemented.
>
> **Initial target:** P6YTOK injected into a patched TikTok 46.1.0 IPA.
>
> **Later target:** Evaluate a separate rootless `.deb` only after IPA testing is complete.

## Purpose

This document records the proposed investigation into why a modified TikTok IPA may fail login or behave differently from the official App Store installation.

The goal is to separate three possible causes:

1. A normal P6YTOK feature or hook is interfering with startup or login.
2. TikTok is detecting local differences in the modified application environment.
3. TikTok's backend is rejecting the re-signed installation independently of local application behavior.

## Startup Model

```text
Launch patched TikTok
        ↓
iOS loads the injected P6YTOK dylib
        ↓
P6YTOK initializes its normal feature modules
        ↓
A future compatibility diagnostics module checks available TikTok classes and selectors
        ↓
Unsupported P6YTOK behavior is disabled safely
        ↓
TikTok continues launching
```

## How This Would Differ From Older DouX/BHTikTok Code

Older projects relied on fixed assumptions about TikTok's internal classes and older jailbreak environments. Those assumptions may no longer match TikTok 46.1.0.

A current P6YTOK approach should instead:

- Detect classes and selectors at runtime before enabling related behavior.
- Avoid crashing when TikTok renames or removes internal classes.
- Keep IPA behavior separate from any future rootless `.deb` behavior.
- Test changes in small independent groups rather than enabling many compatibility changes at once.
- Include a single kill switch so the diagnostics or compatibility module can be disabled without rebuilding the whole tweak.

## IPA and Rootless `.deb` Are Different Environments

### Patched IPA

A patched IPA is decrypted, modified, injected, and re-signed. This can change properties that cannot be fully reproduced from inside the running app.

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

A future diagnostics module may record only non-sensitive compatibility information such as:

- Whether an expected TikTok class exists
- Whether an expected selector exists
- Whether a P6YTOK feature module initialized successfully
- Whether a feature was disabled because its target API was unavailable
- The active TikTok application version
- Whether the build is running as a patched IPA or a jailbreak-injected tweak

Diagnostics must never record passwords, tokens, Keychain contents, private messages, login payloads, cookies, or account data.

## Targeted Testing

Changes should be evaluated individually. Large combined changes make it impossible to identify what affected login behavior.

Recommended test order:

```text
1. P6YTOK IPA without any new compatibility module
2. P6YTOK IPA with diagnostics only
3. P6YTOK IPA with runtime feature gating
4. P6YTOK IPA with one individually tested local compatibility change
5. Repeat with each additional change separately
```

For every build, record:

- TikTok version
- P6YTOK commit
- Signing or sideload method
- Whether Apple Passwords works
- Whether login reaches the server
- Exact error message
- Whether the same account works in the official App Store TikTok app

## Important Limitation

Code running inside the patched IPA cannot truly recreate:

- TikTok's original Apple signature
- The original App Store receipt
- Apple server-side attestation
- TikTok backend knowledge that the application was modified or re-signed

Therefore, local compatibility changes cannot guarantee that the IPA will log in. The error **"Maximum number of attempts reached"** may still occur if TikTok's backend rejects the sideloaded installation or signing identity.

## Current Repository State

The current P6YTOK Makefile compiles the normal feature modules only. No `P6YIntegrityCompat` implementation currently exists.

This file documents the IPA-first research plan, testing boundaries, and known limitations. It does not claim that a bypass or compatibility layer has been completed.
