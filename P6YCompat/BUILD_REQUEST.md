# Login-Safe Artifact Build Request

This file intentionally bumps `agent/login-safe-compat` after `.github/workflows/build-login-safe-tweak.yml` was added, so the branch push workflow can build the login-safe P6YTOK tweak artifacts.

Requested build path:

1. Locate the active Theos Makefile.
2. Wire `P6YCompat/P6YCompatCore.m`, `P6YCompat/P6YDelayedInit.xm`, and `P6YCompat/P6YDelayedGroups.xm` into the detected tweak target during CI.
3. Build the package with Theos.
4. Upload `.deb`, extracted `.dylib`, unpacked layout, and packaging helper artifacts.
5. Use the artifact with a user-provided decrypted TikTok IPA and local signing flow for device testing.

Requested: 2026-07-25 03:15 America/New_York
