"""Create OTA metadata from the final signed APKs."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess


ANDROID_ABIS = {"armeabi-v7a", "arm64-v8a", "x86_64"}


def inspect_apk(args, apk, expected_abis):
    badging = subprocess.check_output(
        [args.aapt, "dump", "badging", str(apk)], text=True, encoding="utf-8"
    )
    package = re.search(
        r"^package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'(.*)$",
        badging,
        re.MULTILINE,
    )
    minimum = re.search(r"^sdkVersion:'(\d+)'", badging, re.MULTILINE)
    if not package or not minimum or " split=" in package.group(4):
        raise SystemExit(f"Cannot identify a standalone APK: {apk.name}")
    app_id, code, version, _ = package.groups()
    if app_id != "io.github.fata69.ohmyesok":
        raise SystemExit("Refusing to package an APK with another applicationId")
    native = re.search(r"^native-code:(.+)$", badging, re.MULTILINE)
    abis = set(re.findall(r"'([^']+)'", native.group(1))) if native else set()
    if abis != expected_abis:
        raise SystemExit(
            f"{apk.name} contains {sorted(abis)}, expected {sorted(expected_abis)}"
        )
    signer = [args.java, "-jar", args.apksigner] if args.java else [args.apksigner]
    cert = subprocess.check_output(
        [*signer, "verify", "--print-certs", str(apk)],
        text=True,
        encoding="utf-8",
    )
    if "CN=Android Debug" in cert:
        raise SystemExit("Refusing to publish an Android debug certificate")
    signer_digests = frozenset(
        re.findall(
            r"^Signer #\d+ certificate SHA-256 digest: ([0-9a-fA-F]{64})$",
            cert,
            re.MULTILINE,
        )
    )
    if not signer_digests:
        raise SystemExit(f"Cannot identify the signing certificate for {apk.name}")
    return (app_id, int(code), version, int(minimum.group(1)), signer_digests), cert


def asset_metadata(apk, variant):
    with apk.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    return {
        "name": f"oh-my-esok-{variant}.apk",
        "sizeBytes": apk.stat().st_size,
        "sha256": digest,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apk", required=True, type=Path)
    parser.add_argument("--abi-apk", nargs=2, action="append", default=[], metavar=("ABI", "APK"))
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--aapt", required=True)
    parser.add_argument("--apksigner", required=True)
    parser.add_argument("--java", help="Java executable when --apksigner is a JAR")
    parser.add_argument("--source-commit", required=True)
    args = parser.parse_args()

    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    if args.source_commit != commit:
        raise SystemExit("Source commit must match the checked-out revision")
    variants = {abi: Path(apk) for abi, apk in args.abi_apk}
    if variants and (set(variants) != ANDROID_ABIS or len(variants) != len(args.abi_apk)):
        parser.error("Provide exactly one APK per supported ABI when specifying --abi-apk")
    identity, cert = inspect_apk(args, args.apk, ANDROID_ABIS)
    for abi, apk in variants.items():
        variant_identity, _ = inspect_apk(args, apk, {abi})
        if variant_identity != identity:
            raise SystemExit(f"Package, version, minSdk or signer differs for {abi}")

    artifacts = {"universal": args.apk, **variants}
    assets = {variant: asset_metadata(apk, variant) for variant, apk in artifacts.items()}
    app_id, code, version, minimum, _ = identity
    preview = "-" in version
    metadata = {
        "schema": 1,
        "channel": "preview" if preview else "stable",
        "tag": "v" + version,
        "applicationId": app_id,
        "versionName": version,
        "versionCode": code,
        "minSdk": minimum,
        "apk": assets["universal"],
    }
    if variants:
        metadata["apkByAbi"] = {abi: assets[abi] for abi in variants}
    args.output.mkdir(parents=True, exist_ok=True)
    sums = []
    for variant, apk in artifacts.items():
        name = assets[variant]["name"]
        digest = assets[variant]["sha256"]
        shutil.copyfile(apk, args.output / name)
        sums.append(f"{digest}  {name}\n")
        print(f"Prepared {app_id} {version} ({code}) {name} SHA-256 {digest}")
    (args.output / "ota-android.json").write_text(
        json.dumps(metadata, indent=2) + "\n", encoding="utf-8"
    )
    (args.output / "SHA256SUMS").write_text("".join(sums), encoding="utf-8")
    (args.output / "signing-certificate.txt").write_text(cert, encoding="utf-8")
    (args.output / "source-commit.txt").write_text(
        commit + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
