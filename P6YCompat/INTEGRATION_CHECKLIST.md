# P6YCompat Build and Test Checklist

## 1. Resolve the existing Theos target

Run:

```bash
scripts/wire_p6ycompat.sh .
```

Confirm the output includes:

```text
project_dir=...
makefile=...
target_name=...
payload_dylib=...
bootstrap_dylib=P6YBootstrap.dylib
payload_generator=internal
```

`payload_generator=internal` is required for the current self-contained IPA build. If the script reports MobileSubstrate, inspect the listed `%hookf` or forced-generator source files before continuing.

## 2. Build the two dylibs

The generated build has:

- `P6YBootstrap.dylib` — loaded at TikTok launch
- `<original-target>.dylib` — delayed feature payload loaded after verified normal UI

Run:

```bash
make clean
make package FINALPACKAGE=1
```

Confirm both dylibs exist in the package layout and are arm64-compatible.

## 3. Validate dependencies

Run `otool -L` on both dylibs.

The IPA build must not retain dependencies on jailbreak-only paths or runtimes such as:

```text
/Library/MobileSubstrate
/var/jb
CydiaSubstrate
libhooker
```

System frameworks and dylibs are expected. Any additional project-specific framework must be copied into the IPA and use a load path that resolves inside the app bundle.

## 4. Build an unsigned injected IPA

Install LIEF and run:

```bash
python3 -m pip install lief

scripts/package_p6ytok_ipa.sh \
  --ipa TikTok-46.1.0-decrypted.ipa \
  --bootstrap P6YBootstrap.dylib \
  --payload <original-target>.dylib \
  --layout <unpacked-deb-layout> \
  --output P6YTOK-login-safe-unsigned.ipa
```

Verify TikTok's main executable contains:

```text
@executable_path/Frameworks/P6YBootstrap.dylib
```

The feature payload should not be an `LC_LOAD_DYLIB` dependency of the main executable; the bootstrap loads it later with `dlopen`.

## 5. Sign and install

Sign the unsigned IPA using the user's existing certificate/profile or sideloading service. Do not commit certificates, provisioning profiles, passwords, TikTok IPAs, or account data.

## 6. First-device test

Start with a clean install and record:

- TikTok version
- P6YTOK branch/commit
- signing and install method
- whether TikTok reaches login
- whether Apple Passwords/autofill works
- whether login succeeds
- the first controller classes logged by `P6YBootstrap`
- whether the feature payload logs a successful post-login load
- whether settings and one low-risk feature work
- exact crash or login message, if any

## 7. Logout behavior

After the feature payload has loaded, logging out does not remove already-installed hooks from that process. Fully close and relaunch TikTok before another login attempt so startup returns to bootstrap-only mode.

## Explicit boundaries

Do not add hooks for:

- Keychain or password autofill
- login requests, tokens, or cookies
- `NSURLSession`
- TLS / certificate validation
- device or install identifiers
- carrier or region state
- App Store receipts or server-side attestation
