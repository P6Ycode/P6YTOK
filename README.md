# P6YTOK

A TikTok tweak project based on BHTikTok Plus, currently being updated for IPA-injected TikTok builds.

<p align="center">
<img src="https://github-production-user-asset-6210df.s3.amazonaws.com/38832025/265550639-c8a15d0e-1649-4172-8dd9-37152a5611cb.png?raw=true" />
</p>

## Current focus

The active compatibility target is a patched TikTok IPA with P6YTOK injected into the app bundle.

The first login-fix pass is **login-safe mode**:

1. Let the P6YTOK dylib load when TikTok starts.
2. Keep tweak feature groups disabled during login, onboarding, verification, and account-recovery screens.
3. Enable feature groups only after the normal TikTok app UI is visible.
4. Avoid hooks that touch login requests, tokens, cookies, Keychain, TLS, device identifiers, install identifiers, carrier state, or region state.

See [`P6YCompat/README.md`](P6YCompat/README.md) for the new compatibility module and integration notes.

See [`INTEGRITY_COMPATIBILITY_PLAN.md`](INTEGRITY_COMPATIBILITY_PLAN.md) for the broader testing plan and limitations.
