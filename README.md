# P6YTOK

P6YTOK is a clean revival of the former TikTok tweak codebase for TikTok 46.1.0 and iOS 15 or newer.

## Current revival status

Phase 1 is focused on removing obsolete or risky behavior before the modern feature implementations are rebuilt.

### Removed

- Fake verification badge
- Fake follower and following counts
- Region and carrier spoofing
- Destructive interaction-reset tools
- Broad jailbreak and sideload detection overrides
- Unverified watermark override
- Legacy donation and developer links
- Former project branding and package identity

### Safe core retained

- P6YTOK settings entry
- Disable ads
- TikTok progress bar override
- Like, comment, and follow confirmations
- Extended bio and comment limits
- Passcode lock
- Open links in the external browser

### Next

The downloader, photo saving, music saving, sharing, copy actions, Pure Mode, profile tools, and modern progress UI will be rebuilt for TikTok 46.1.0.

See `REVIVAL_AUDIT.md` for compatibility details.
