# Releasing Oh My Esok

The Android application ID is `io.github.fata69.ohmyesok`. Preserve it and the
release signing certificate across all future updates. Esok's application ID
belongs to upstream; never install a candidate over it.

## Candidate

1. Integrate reviewed changes on a release branch and record the full commit.
2. Use Flutter 3.50.0 / Dart 3.14, Java 17, Android platform 37.0 and the checked-in
   Gradle wrapper. Run `flutter pub get --enforce-lockfile`, `flutter analyze`,
   and `flutter test` before `flutter build apk --release`.
3. Supply `OH_MY_ESOK_KEYSTORE`, `OH_MY_ESOK_STORE_PASSWORD`,
   `OH_MY_ESOK_KEY_ALIAS`, and `OH_MY_ESOK_KEY_PASSWORD` through the process
   environment. Never commit keys or secrets. Debug certificates are rejected
   by the release metadata script.
4. Run `scripts/release_metadata.py` with the APK, output directory, and paths
   to the Android `aapt` and `apksigner` executables and the source commit captured
   before building. It rejects artifacts missing a universal ABI and creates the
   APK, `ota-android.json`, `SHA256SUMS`, public certificate details, and the
   source commit. Metadata is derived from the final signed APK.

The GitHub candidate workflow performs the same steps and stores an artifact.
A successful build is a candidate, not QA approval and not an automatic release.
If hosted Actions cannot run, execute the same commands locally and record
their versions and results in the QA report.

## QA and publication

QA checks the exact candidate APK with synthetic data, including installation
alongside upstream, launch, light/dark floating navigation, large text/keyboard,
notes, money transfers, backup/import with item details, and the changed
features. Include the commit, APK SHA-256, certificate, device/API, observed
results and any limitations. Route failures to the owning UI/UX or middleware
chat, integrate fixes, and repeat the affected checks on the new candidate.

For the OTA path, install a lower-version fork APK signed by the same key and
verify updating to the candidate preserves synthetic data. Cancelling or
rejecting an installer must preserve the old version. Corrupt, wrong-ID and
wrong-signer APKs must stop before installer handoff.

After QA accepts a candidate, create a prerelease tag matching its version
(`v0.1.0-preview.1` for example), referencing the tested source commit. Upload
the exact tested bytes with metadata, checksum and the QA report. Do not rebuild
or re-sign them. The first review release is marked prerelease, never stable
latest. Publish stable only after the intended release has passed its checks.

The app uses the public GitHub Releases API without an embedded access token.
Stable and preview channels are explicit. A repository with no release is
shown as such; an offline check is not reported as up to date.

## Upstream

Keep the Esok Git history and credit `notSeraphimXD/esok`. Manual JSON backups
retain the upstream v5 format. Fork automatic backups use a different folder
and file so they cannot replace upstream backups. Do not add an app-wide
license over inherited code without the rights holder's grant. Font licensing
remains with the bundled font notices.
