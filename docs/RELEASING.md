# Releasing Oh My Esok

The Android application ID is `io.github.fata69.ohmyesok`. Preserve it and the
release signing certificate across all future updates. Esok's application ID
belongs to upstream; never install a candidate over it.

## Candidate

1. Integrate reviewed changes on a release branch and record the full commit.
2. Use Flutter 3.50.0 / Dart 3.14, Java 17, Android platform 37.0 and the checked-in
   Gradle wrapper. Public GitHub workflows run dependency resolution, analysis
   and tests with read-only repository permission and no signing credentials.
   They do not sign APKs, create tags, upload release assets or publish releases.
   A green source check is not the separate `QA / Android` acceptance status.
3. On the trusted Windows signing host, use PowerShell 7+, activate the project
   toolchain (including Android Build Tools 36.0.0 and Java 17), and supply
   `OH_MY_ESOK_KEYSTORE`, `OH_MY_ESOK_STORE_PASSWORD`, `OH_MY_ESOK_KEY_ALIAS`,
   and `OH_MY_ESOK_KEY_PASSWORD` through the process environment. Keep the
   keystore and its protected backup outside the repository, SDK caches and
   build directories. Never print or commit the values.
4. Run `./scripts/build-android.ps1` from a clean reviewed checkout. It consumes
   and removes those four variables before invoking any child process. It runs
   `pub get --enforce-lockfile`, analysis and tests, then compiles with
   `OH_MY_ESOK_UNSIGNED_BUILD=true`. Gradle has no release keystore
   configuration and refuses a release build without this opt-in. The script
   produces a universal APK and three standalone APKs for ARMv7, ARM64 and
   x86-64. Flutter's ABI version offset is disabled for the standalone APKs
   so every package uses the same versionCode.
5. The script checks that each fresh APK is unsigned and checks its ZIP
   alignment before signing. It launches the Android `apksigner` JAR
   directly with the project JDK. The passwords go only into that child's
   environment via `--ks-pass env:...` and `--key-pass env:...`. They are
   absent from the command line, the parent environment, and later tools.
   The original signing variables remain cleared on success or failure.
6. The script verifies ZIP alignment again on each signed APK. The metadata
   script checks the expected ABIs, matching package identity, version, minSdk
   and release signer across all APKs, and writes the four `dist/oh-my-esok-*.apk`,
   `ota-android.json`, `SHA256SUMS`, public certificate details and the source
   commit. Use these files only after a successful run; a failed run may leave
   earlier assets in `dist/`. Compare the signer SHA-256 with the last accepted
   candidate. Never rebuild or re-sign after QA approval.

Keep production signing secrets out of GitHub repository, organization and
environment settings. This workflow does not use GitHub environments or hosted
signing.

Removing environment variables is a process-inheritance boundary, not a sandbox
against hostile code running under the same Windows account. Inspect source,
workflow and dependency changes before building on the signing host. Test
untrusted PR code in a disposable, unprivileged environment without access to
the signing account, vault, key files or shared writable caches. See
[SECURITY.md](../SECURITY.md) for the complete trust boundary.

## QA and publication

QA checks the exact candidate APK with synthetic data, including installation
alongside upstream, launch, light/dark floating navigation, large text/keyboard,
notes, money transfers, backup/import with item details, and the changed
features. Include the commit, APK SHA-256, certificate, device/API, observed
results and any limitations. Route failures to the owning UI/UX or middleware
chat, integrate fixes, and repeat the affected checks on the new candidate.

The `main` ruleset requires a pull request, resolved conversations, an
up-to-date branch, and the `QA / Android` status on its candidate commit.
Keep it pending while testing. Record success on the exact PR head only after
the QA evidence above is complete, whether the build ran in Actions or locally.
Do not bypass the rule or reuse a success status after changing the candidate.

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

Keep the Esok Git history and credit `notSeraphimXD/esok`. JSON backups without
recurring agendas retain the upstream v5 format. Backups with recurring agendas
use v6, which preserves the series and per-date changes. Backups with undated
notes or a payday plan use v7. The fork imports all three formats. Fork
automatic backups use a different folder and file so they cannot
replace upstream backups. Do not add an app-wide
license over inherited code without the rights holder's grant. Font licensing
remains with the bundled font notices.
