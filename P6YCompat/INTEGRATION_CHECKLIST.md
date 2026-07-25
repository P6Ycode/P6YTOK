# P6YCompat Integration Checklist

Use this checklist when wiring `P6YCompat/` into the active Theos target.

## 1. Add source files

Add these files to the tweak target source list:

```make
P6YCompat/P6YCompatCore.m
P6YCompat/P6YDelayedInit.xm
P6YCompat/P6YDelayedGroups.xm
```

Do not add `P6YFeatureGate.h`; it is a header imported by migrated hooks.

## 2. Build login-safe only

Before moving any existing hooks, build once with only the compat files included.

Expected behavior:

- TikTok launches.
- Login/onboarding screens behave normally.
- `os_log` shows `bootstrapped login-safe compat`.
- Feature groups remain disabled until normal app UI is observed.

## 3. Move hooks by feature group

Migrate one group at a time:

1. settings shell
2. downloads
3. feed UI
4. profile
5. ad filtering
6. browser redirects

Avoid mixing groups in the same test build. Fog belongs in noir movies, not debugging.

## 4. Keep these out of scope

Do not add hooks for:

- Keychain
- Apple Passwords / password autofill
- login requests
- tokens
- cookies
- `NSURLSession`
- TLS / cert validation
- device identifiers
- install identifiers
- carrier state
- region state

## 5. Test matrix

For each IPA build, record:

- TikTok version
- P6YTOK commit
- sideload/signing method
- enabled P6YCompat groups
- whether login succeeds
- whether Apple Passwords works
- exact login error, if any
- first normal TikTok controller class logged after login
