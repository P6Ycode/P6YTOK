# P6YTOK Revival Audit

## Target app

- TikTok version: **46.1.0**
- Build: **461034**
- Bundle ID: `com.zhiliaoapp.musically`
- Architecture: `arm64`
- Minimum iOS: **15.0**
- SDK used by TikTok: **iPhoneOS 26.0**
- Main application code: `MusicallyCore.framework`

## Repository state

The current `main` branch no longer contains the tweak implementation. It only retains the README and localization resources. The intact source baseline still exists in repository history at commit:

`18b4477ee29581aa99d0851776a58b008b78ede9`

This branch (`revive-tiktok-46.1.0`) was created from that source baseline so the app can be rebuilt without rewriting every feature from zero.

## TikTok 46.1.0 compatibility scan

### Old classes still present

These important v1.2 classes are still present in TikTok 46.1.0 and are candidates for direct modernization:

- `AppDelegate`
- `TTKSettingsBaseCellPlugin`
- `AWESettingsNormalSectionViewModel`
- `AWEAwemeModel`
- `AWEURLModel`
- `AWEVideoModel`
- `AWEMusicModel`
- `AWEPhotoAlbumModel`
- `AWEPhotoAlbumPhoto`
- `AWEFeedViewTemplateCell`
- `AWEFeedCellViewController`
- `AWEAwemeDetailCellViewController`
- `TTKPhotoAlbumFeedCellController`
- `TTKPhotoAlbumDetailCellController`
- `TTKStoryDetailTableViewCell`
- `AWEProfileImagePreviewView`
- `AWEPlayInteractionUserAvatarElement`
- `AWECommentPanelCell`
- `AWETextInputController`
- `AWEProfileEditTextViewController`
- `TTKFeedInteractionLegacyMainContainerElement`
- `AWENewFeedTableViewController`

### Removed or renamed classes

The old hooks below cannot be carried forward unchanged:

- `TIKTOKProfileHeaderViewController`
- `TIKTOKProfileHeaderView`
- `TIKTOKProfileHeaderExtraViewController`
- `TTKStoryContainerViewController`
- `TTKStoryDetailContainerViewController`
- `AWEPlayVideoPlayerController`
- `AWEToast`
- `PIPOIAPStoreManager`
- `HBForceCepheiPrefs`

Likely replacement areas discovered in 46.1.0 include:

- `TTKProfileHeaderView`
- `TTKProfileHeaderAdaptor`
- `TTKProfileHeaderTopContainerView`
- `TTKRelationButton`
- `TTKRelationButtonViewModel`
- `AWEVideoPlayerController`
- `TTKStoryVideoPlayerControllerWrapper`

These require runtime verification before new hooks are enabled.

## Known broken implementation details

### Download extension detection

The old downloader determines file type by checking whether a URL contains strings such as `video_mp4`, `.jpeg`, `.mp3`, or `.m4a`. When none match, it defaults to `m4a`.

Modern TikTok CDN URLs often do not expose a reliable extension in the URL. This can cause a real video to be named or handled as audio. The revived downloader must determine type using the HTTP response MIME type, `UTType`, and media metadata instead of URL text.

### Story downloading

The old story logic depends on `TTKStoryContainerViewController` and `TTKStoryDetailContainerViewController`, which are absent in 46.1.0. Story downloading needs a new model/controller discovery pass.

### Auto-play / end-of-video behavior

The old hook targets `AWEPlayVideoPlayerController`, which is absent. The `playerWillLoopPlaying:` selector still exists elsewhere, but a safe replacement class must be identified before enabling this feature.

### Profile actions

The old profile header controller/view classes and the `relationBtnClicked:` selector are absent. Profile copying and profile follow confirmation need to move to the current `TTKProfileHeader*` and `TTKRelationButton*` architecture.

### Region changing

The legacy `CTCarrier` approach is incomplete on 46.1.0. `setIsoCountryCode:` is absent, and TikTok now relies on more than carrier values. Region changing should remain disabled until it is redesigned and tested.

### Sideload and jailbreak bypasses

The old source globally overrides several jailbreak, receipt, app-extension, and filesystem checks. Some classes still exist, but broad overrides can cause login, upload, payment, analytics, or startup failures in current TikTok. These hooks should be reduced to the smallest confirmed set and separated from normal feature code.

### Repeated gestures

The old feed code adds long-press recognizers whenever a cell is configured. Reused cells can accumulate recognizers. The revived code should attach actions once per cell and avoid overriding TikTok's native long-press menu.

## Recommended first implementation phase

1. Make the source compile with current Theos/Logos and an iOS 15 deployment target.
2. Remove Cephei dependence and obsolete hooks.
3. Restore a stable settings entry.
4. Rebuild downloading for videos, photo posts, music, and profile images using MIME/UTType detection.
5. Use a dedicated download button or menu action instead of taking over the native long press.
6. Keep region changing, fake counts, interaction resets, and broad bypass hooks disabled until individually tested.
7. Add a GitHub Actions workflow that injects the built dylib into a user-supplied decrypted IPA and produces an unsigned test IPA artifact.

## Initial feature status

| Feature | Initial status |
|---|---|
| Settings page | Likely recoverable |
| Remove feed ads | Needs runtime test |
| Video/photo download | Recoverable, downloader rewrite required |
| Music download | Recoverable, MIME handling required |
| Copy media links/description | Likely recoverable |
| Save profile picture | Likely recoverable |
| Pure UI mode | Likely recoverable |
| Comment length / bio length | Hook names still present; needs test |
| Like/comment confirmation | Hook names still present; needs test |
| Follow confirmation | Broken old profile hook |
| Story download | Broken old controller hooks |
| Auto-play next / end behavior | Broken old player class |
| Region changer | Disable pending redesign |
| Fake profile counts/checkmark | Remove or keep disabled pending decision |
| App lock | Can be retained after modernization |
| Jailbreak/sideload bypass | Rewrite and minimize |
