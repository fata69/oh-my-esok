"""Create OTA metadata from the final signed APK; never rebuild for publication."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apk", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--aapt", required=True)
    parser.add_argument("--apksigner", required=True)
    parser.add_argument("--java", help="Java executable when --apksigner is a JAR")
    parser.add_argument("--source-commit", required=True)
    args = parser.parse_args()
    badging = subprocess.check_output(
        [args.aapt, "dump", "badging", str(args.apk)], text=True, encoding="utf-8"
    )
    package = re.search(
        r"package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'",
        badging,
    )
    minimum = re.search(r"sdkVersion:'(\d+)'", badging)
    if not package or not minimum:
        raise SystemExit("Cannot determine final APK identity/version/minSdk")
    app_id, code, version = package.groups()
    if app_id != "io.github.fata69.ohmyesok":
        raise SystemExit("Refusing to package an APK with another applicationId")
    native = re.search(r"^native-code:(.+)$", badging, re.MULTILINE)
    abis = set(re.findall(r"'([^']+)'", native.group(1))) if native else set()
    if not {"armeabi-v7a", "arm64-v8a", "x86_64"}.issubset(abis):
        raise SystemExit(f"APK is missing required universal ABIs: {sorted(abis)}")
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    if args.source_commit != commit:
        raise SystemExit("Source commit must match the checked-out revision")
    signer = [args.java, "-jar", args.apksigner] if args.java else [args.apksigner]
    cert = subprocess.check_output(
        [*signer, "verify", "--print-certs", str(args.apk)],
        text=True,
        encoding="utf-8",
    )
    if "CN=Android Debug" in cert:
        raise SystemExit("Refusing to publish an Android debug certificate")
    digest = hashlib.sha256(args.apk.read_bytes()).hexdigest()
    args.output.mkdir(parents=True, exist_ok=True)
    name = "oh-my-esok-universal.apk"
    shutil.copyfile(args.apk, args.output / name)
    preview = "-" in version
    metadata = {
        "schema": 1,
        "channel": "preview" if preview else "stable",
        "tag": "v" + version,
        "applicationId": app_id,
        "versionName": version,
        "versionCode": int(code),
        "minSdk": int(minimum.group(1)),
        "apk": {"name": name, "sizeBytes": args.apk.stat().st_size, "sha256": digest},
    }
    (args.output / "ota-android.json").write_text(
        json.dumps(metadata, indent=2) + "\n", encoding="utf-8"
    )
    (args.output / "SHA256SUMS").write_text(f"{digest}  {name}\n", encoding="utf-8")
    (args.output / "signing-certificate.txt").write_text(cert, encoding="utf-8")
    (args.output / "source-commit.txt").write_text(
        commit + "\n", encoding="utf-8"
    )
    print(f"Prepared {app_id} {version} ({code}) SHA-256 {digest}")


if __name__ == "__main__":
    main()
