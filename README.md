# P6YTOK

P6YTOK is a black-and-red TikTok enhancement project being revived for TikTok 46.1.0 (build 461034).

## Current revival scope

- Highest-available-quality video downloads
- Original photo-file downloads, including full-quality photo batches
- Original audio downloads and Share Sheet export
- Full-quality profile-photo download when TikTok exposes the avatar URL
- Original video/photo resources saved to Photos without UIImage re-encoding
- Direct media-link and description copying
- Feed ad filtering and Pure Mode
- Download progress overlay
- Like, comment, and follow confirmations
- Profile follow status, video count, upload date, like count, and sensitive-mask options
- Feed comment transparency, cleaned links, warning suppression, recommendation filtering, playback behavior, and startup-page selection
- P6YTOK settings page with black-and-red styling

## Quality behavior

“Full quality” means the largest or original media variant TikTok exposes to the app. P6YTOK ranks available video streams by bitrate and dimensions, prefers original photo resources, and uses the same resolver for multi-photo batches. It cannot recover quality that TikTok does not provide.

## Target

- TikTok 46.1.0
- iOS 15 or newer
- arm64

The branch requires a real Theos build and device test against the target decrypted IPA before release. Internal TikTok classes and media response models can change between app builds.
