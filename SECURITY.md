# Security and release trust

## Public contributions

Submitting a pull request does not grant write or release permission. Require
review and `QA / Android` on the candidate revision before merging to `main`.
Check repository permissions and rulesets separately; GitHub settings are
not controlled by these files. Review code, dependencies, workflows and build/release scripts
for malicious behavior as well as functional defects. Tests alone cannot
prove that a change is safe.

GitHub source-check workflows have read-only contents permission, do not
persist a checkout credential, and do not receive production signing secrets.
They never auto-merge, sign or publish. Do not add `pull_request_target` or a
privileged `workflow_run` that executes untrusted PR code. A contributor can
change a workflow in their PR but cannot thereby obtain the owner's local key
or publish an official signed update.

## Signing boundary

Keep the production key outside the repository, build outputs and hosted
Actions. Do not put its bytes or passwords in GitHub repository, organization
or environment secrets.

The local build script removes signing variables before starting Git, Flutter,
Gradle, tests or dependency tools. It builds an unsigned APK, checks the source
revision, and invokes trusted Android `apksigner` only after compilation.
Passwords are set only in the signer's child environment. They do not
appear in command-line arguments or reach the verification and metadata
processes. Gradle has no release signing configuration, and debug signing
is limited to debug builds.

This does not isolate malicious code running as the same Windows user. That
code can access files or processes permitted to that account, including local
keys. Review before promotion, and run arbitrary contributor code in a
disposable environment with no access to the signing host/account or its
shared caches. For stronger isolation, compile on a separate unprivileged
machine and transfer the reviewed unsigned artifact to an offline signer.

## Publication and OTA

The owner publishes only the exact APK accepted by device QA, with its commit,
SHA-256 and certificate evidence. Verify that release immutability and
protection against force updates or deletion of `v*` tags are enabled before
publication. To replace a failed release, issue a new version.

OTA fetches only fixed asset names from `fata69/oh-my-esok` on GitHub, validates
HTTPS redirect hosts and checks byte count and SHA-256. Android-side checks
repeat integrity verification and require the fork application ID, a higher
version code and the installed app's signing certificate before opening the
system installer. Metadata is data, never shell commands or executable code.
An attacker who can replace release metadata but does not hold the production
key cannot supply a newly signed update accepted over an authentic install.
The initial installation must still come from the official release; signer
trust for later updates derives from that installed APK.

Do not post API keys, signing material, private receipts or financial data in
public issues. Report a suspected vulnerability privately to the repository
owner before publishing reproduction details that affect users.
