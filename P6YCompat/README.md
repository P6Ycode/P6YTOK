# P6YCompat Login-Safe Mode

P6YCompat is the compatibility layer for the IPA-injected P6YTOK target.

It is intentionally not a broad login, token, TLS, Keychain, device-ID, or server-integrity bypass. Its job is narrower: keep the existing tweak payload completely unloaded while TikTok is on login-sensitive UI, then load it only after normal app UI has been verified.

## Runtime architecture

The IPA contains two dylibs:

```text
TikTok launches
      ↓
P6YBootstrap.dylib loads from an LC_LOAD_DYLIB command
      ↓
Bootstrap observes UIKit only
      ↓
Login / onboarding / verification runs without the legacy tweak payload
      ↓
Normal TikTok UI remains stable for the verification grace period
      ↓
Bootstrap dlopen()s the original P6YTOK feature dylib
      ↓
Existing tweak hooks initialize
```

This is stronger than adding guard checks inside every old hook: the feature dylib and its hooks do not exist in the process during initial login.

## Files

- `P6YCompatCore.h` / `P6YCompatCore.m`
  - login-safe state
  - strict login/main-UI classification
  - two-second main-UI stability verification
  - TikTok version and safe environment diagnostics
  - class/selector availability helpers

- `P6YDelayedInit.xm`
  - the only always-loaded Logos observer
  - hooks `UIViewController viewDidAppear:` to observe navigation

- `P6YDelayedGroups.xm`
  - locates the generated legacy feature payload name
  - calls `dlopen(..., RTLD_NOW | RTLD_GLOBAL)` after verified main UI
  - logs missing-payload and dynamic-loader errors

- `P6YFeaturePayloadName.h`
  - generated during CI with the original Theos target dylib name

- `P6YFeatureGate.h`
  - retained for future per-feature controls after the basic two-dylib build is proven

## Build integration

Run:

```bash
scripts/wire_p6ycompat.sh .
```

The script finds the actual Theos tweak Makefile, identifies its primary `TWEAK_NAME`, and converts the build into:

- the original target as the delayed feature payload
- a new `P6YBootstrap` target containing the compat files

When the source is compatible, the original payload is compiled with Logos' internal generator so the IPA does not require a jailbreak-only hook runtime. `%hookf` or an explicitly forced MobileSubstrate/libhooker generator is detected and reported as a blocking condition.

The script changes the working-tree Makefile during CI; it does not need to commit a generated Makefile to the branch.

## IPA packaging

`scripts/package_p6ytok_ipa.sh` requires:

- a user-provided decrypted TikTok IPA
- `P6YBootstrap.dylib`
- the original feature payload dylib
- optional unpacked package resources
- Python with LIEF installed

It performs real Mach-O injection by adding:

```text
@executable_path/Frameworks/P6YBootstrap.dylib
```

to TikTok's main executable, places both dylibs in `Frameworks/`, copies resource bundles/frameworks, removes stale signatures, and emits an unsigned injected IPA.

The resulting IPA must still be signed with the user's own signing method before installation.

## Login and logout behavior

The feature payload is loaded only once per process. A dynamic library cannot be safely treated as fully removable after its hooks initialize.

Therefore:

- initial launch and login occur with only the bootstrap loaded
- after normal UI is verified, the feature payload loads
- after logging out, fully close and relaunch TikTok before attempting another login

That restart returns the process to bootstrap-only login-safe mode.

## Runtime flags

All flags live in `NSUserDefaults`.

| Key | Default | Purpose |
| --- | --- | --- |
| `P6YCompatEnabled` | `YES` | Master switch for the compatibility layer. |
| `P6YCompatForceLoginSafeMode` | `NO` | Prevents the feature payload from loading. |
| `P6YCompatManualFeatureEnable` | `NO` | Bypasses automatic UI classification for controlled debugging only. |
| `P6YCompatDebugLogging` | `YES` | Emits safe controller/version/state logs through `os_log`. |

## Build outputs

The workflow uploads diagnostics even when a later step fails:

- resolved Makefile
- source file map
- wire-script output and selected Logos generator
- complete `make package` log
- file architecture reports
- `otool -L` dependency reports
- generated `.deb` / dylibs when compilation succeeds
- unsigned injected IPA when a user-provided IPA URL was supplied

## Explicit non-goals

This module does not hook, inspect, or alter:

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
- App Store receipts or server-side attestation

Those areas remain out of scope for the IPA login-safe build.
