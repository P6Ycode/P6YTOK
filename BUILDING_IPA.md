# Building P6YTOK Artifacts and IPA Test Builds

This repo is set up to produce P6YTOK tweak artifacts first. The IPA step should stay separate and explicit because it depends on a user-provided TikTok IPA and signing method.

## What GitHub Actions Builds

The `Build P6YTOK tweak artifacts` workflow compiles the Theos project and uploads:

- `deb/` — packaged tweak output when the project produces a `.deb`.
- `dylib/` — extracted dynamic libraries for separate injection/packaging.
- `layout/` — unpacked package layout for inspection.

The workflow does **not** download, store, or distribute TikTok IPAs.

## Running the Build

1. Open the repository on GitHub.
2. Go to **Actions**.
3. Select **Build P6YTOK tweak artifacts**.
4. Choose **Run workflow**.
5. Download the `p6ytok-tweak-artifacts` artifact after the run completes.

If the workflow fails at `Locate Theos project`, the repository is missing a Theos `Makefile` in the expected project tree. If it fails during `make package`, the next step is to fix the tweak source or build settings before touching IPA packaging.

## IPA Packaging Boundary

A test IPA should be created only from an IPA and signing assets you are allowed to use. Keep these out of git:

- TikTok `.ipa` files
- Apple certificates
- provisioning profiles
- signing passwords
- session tokens, cookies, or account data

A clean local IPA packaging flow is:

```text
Build P6YTOK tweak artifact
        ↓
Extract the compiled P6YTOK dylib and required bundles
        ↓
Inject those files into a user-provided TikTok IPA
        ↓
Re-sign the resulting IPA with your own signing method
        ↓
Install and test on a device
```

Do the final IPA packaging locally or in a private workflow that receives the IPA and signing material at runtime. Do not commit those files.

## Testing Order

Use small test steps so one broken thing does not wear a fake mustache and pretend to be five broken things:

1. Stock user-provided TikTok IPA, no P6YTOK injection.
2. TikTok IPA with only the compiled P6YTOK dylib injected.
3. TikTok IPA with P6YTOK dylib plus required bundles/resources.
4. TikTok IPA with one compatibility or feature-gating change at a time.

For each build, record:

- TikTok version
- P6YTOK commit
- signing method
- install method
- whether launch succeeds
- whether settings open
- whether Apple Passwords works
- exact error message, if any

## Compatibility Work

Keep compatibility work local and diagnostic. Do not add hooks that inspect, modify, or intercept:

- Keychain data
- passwords
- login request bodies
- authentication tokens
- cookies
- TLS or certificate validation
- private account data

The useful next implementation is a small diagnostics/feature-gating module that checks whether expected TikTok classes and selectors exist before enabling fragile features. That helps identify crashes and broken hooks without turning the project into a haunted elevator full of auth hacks.
