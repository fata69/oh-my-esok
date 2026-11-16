# Android APK updates

`UpdatePage` provides manual checks and an explicit prerelease opt-in. Stable checks
use `GET https://api.github.com/repos/fata69/oh-my-esok/releases/latest`. Preview
checks inspect the most recent 20 published releases and choose the highest
validated `versionCode`. A repository without a release displays that state rather
than claiming an unknown installed version is current.

The release must have two fixed assets. Build metadata from the final signed APK:

```json
{
  "schema": 1,
  "channel": "preview",
  "tag": "v2.0.0-preview.1",
  "applicationId": "io.github.fata69.ohmyesok",
  "versionName": "2.0.0-preview.1",
  "versionCode": 20,
  "minSdk": 24,
  "apk": {
    "name": "oh-my-esok-universal.apk",
    "sizeBytes": 123,
    "sha256": "REPLACE_WITH_64_HEX_CHARACTERS_FROM_THE_SIGNED_APK"
  }
}
```

The metadata filename is `ota-android.json`. The APK filename is
`oh-my-esok-universal.apk`. `channel` must match GitHub's release type:
`preview` for prerelease, `stable` for a full release. Both assets must belong to
the same tag. Never use the illustrative size/checksum above for an actual release.

The app accepts only HTTPS release paths in this repository and exact GitHub CDN
hosts for redirects. Metadata is size bounded; APK downloads are streamed to an
app-private `.part` file with a 300 MiB upper bound and idle timeout. Interrupted
downloads are removed. Size and SHA-256 must match metadata before the native
bridge checks the APK. Native checks repeat SHA-256 and size, enforce the app's
private updates directory, verify package ID, minimum Android version, increasing
versionCode, and the same signing certificate set as the installed app. Only then
is a PackageInstaller session committed with user action required. Key rotation
is deliberately not supported in this first version; continue using the same key.

The installer does not bypass Android's per-source permission or confirmation.
Returning to the app reconciles the installed version and installation callback;
launching an installer is not treated as proof of success. All user data remains
in the existing app sandbox and no uninstall or data clearing is performed.

Integration: route Settings to `const UpdatePage()`; the bridge registration,
private callback receiver, and REQUEST_INSTALL_PACKAGES permission are included.
The identity work must set the release application ID to
`io.github.fata69.ohmyesok` before any APK is installed or distributed.

Automated tests cover manifest validation, channel isolation, version ordering,
URL restrictions, downloaded bytes/hash, and GitHub no-release/rate-limit states
using synthetic responses. Native PackageInstaller behavior, source permission,
cancel, restart, and real signed update preserving data require Android testing
of two builds signed by the same key. They are not established by unit tests.

References: [GitHub Releases API](https://docs.github.com/en/rest/releases/releases),
[PackageInstaller sessions](https://developer.android.com/reference/android/content/pm/PackageInstaller.Session),
[Android app update requirements](https://developer.android.com/google/play/app-updates).
