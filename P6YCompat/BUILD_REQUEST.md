# Login-Safe Artifact Build Request

This file records the current default-branch build target for the login-safe two-dylib architecture.

Requested path:

1. Locate the active Theos Makefile and original tweak target.
2. Compile the original target as a delayed feature payload using the self-contained Logos runtime when supported.
3. Compile `P6YBootstrap.dylib` as the only launch-injected dylib.
4. Validate both dylibs for jailbreak-only runtime dependencies.
5. Upload build logs and diagnostics even if compilation fails.
6. Resolve the decrypted TikTok IPA from this repository's published Releases.
7. Inject the bootstrap with LIEF and produce an unsigned IPA artifact.

The workflow is configured for pushes to `main` and `agent/login-safe-compat`.

Explicit workflow rerun requested: July 25, 2026.
