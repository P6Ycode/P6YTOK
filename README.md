# P6YTOK

P6YTOK is a black-and-red TikTok enhancement project being revived for TikTok 46.1.0 (build 461034).

## Current revival scope

- Highest-available-quality video downloads
- Original photo-file downloads, including full-quality photo batches
- Original audio downloads and Share Sheet export
- Full-quality profile-photo download when TikTok exposes the avatar URL
- Save original video/photo resources to Photos without UIImage re-encoding
- Direct media-link and description copying
- Feed ad filtering and Pure Mode
- LIVE pinch zoom in `IESLiveMTAudienceViewController`, including after clearing controls
- Story posted time and live remaining-time countdown in 24-hour format
- Locally observed follower-count gains/losses since the previous profile visit
- Observed follower-change timeline with 24-hour timestamps
- Likes-tab unavailable-placeholder detection, selection of loaded posts, and full-quality batch download
- Download progress overlay
- Like, comment, and follow confirmations
- Profile follow status, video count, upload date, like count, and sensitive-mask options
- Feed comment transparency, cleaned links, warning suppression, recommendation filtering, playback behavior, and startup-page selection
- P6YTOK settings page with black-and-red styling

## Important limits

- TikTok does not expose the exact time an individual account followed or unfollowed another account. P6YTOK records when a follower-count change was **observed** during a profile visit.
- TikTok 46.1.0 exposes a remove-unavailable API for Favorites, but this audit did not confirm a safe bulk-unlike API for the Likes tab. Likes removal is intentionally not sent through an unverified endpoint.
- Likes selection covers posts loaded by TikTok's Likes data manager. More posts become selectable as TikTok loads additional pages.
- “Full quality” means the largest/original media variant TikTok exposes to the app. P6YTOK cannot recover quality TikTok does not provide.

## Removed from the old project

- Face ID, Touch ID, and device-passcode lock
- Fake verification and fake account statistics
- Region changing
- Destructive “Fix Interactions” behavior
- Broad jailbreak, receipt, and sideload bypass hooks
- Legacy watermark toggle
- Donation links and old branding
- “Remove Just Watched” — TikTok's Just Watched label is left unchanged
- Always Upload in HD
- Upload-country display and country flag/code placement
- Pull-to-refresh disabling
- Username replacement
- LIVE filtering

## Target

- TikTok 46.1.0
- iOS 15 or newer
- arm64

The branch requires an actual Theos build and device test against the target decrypted IPA before release. Internal TikTok classes and response models can change between app builds.
