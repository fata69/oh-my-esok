import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/update/release_manifest.dart';
import 'package:jadwal/update/update_controller.dart';

void main() {
  Map<String, dynamic> metadata() => {
    'schema': 1, 'channel': 'stable', 'tag': 'v2.0.0',
    'applicationId': ReleaseManifest.applicationId,
    'versionName': '2.0.0', 'versionCode': 20, 'minSdk': 24,
    'apk': {'name': ReleaseManifest.apkName, 'sizeBytes': 3,
      'sha256': sha256.convert([1, 2, 3]).toString()},
  };
  ReleaseManifest parse(Map<String, dynamic> value, {bool prerelease = false,
    bool allowPreview = false}) => ReleaseManifest.parse(value,
      releaseTag: 'v2.0.0', prerelease: prerelease, allowPreview: allowPreview);

  test('versionCode rather than display version determines update', () {
    final release = parse(metadata());
    expect(release.newerThan(19), isTrue);
    expect(release.newerThan(20), isFalse);
    expect(release.newerThan(21), isFalse);
  });
  test('wrong application identity and tag are rejected', () {
    expect(() => parse(metadata()..['applicationId'] = 'com.habib.jadwal'), throwsFormatException);
    expect(() => parse(metadata()..['tag'] = 'other'), throwsFormatException);
  });
  test('preview requires explicit opt-in and matching release type', () {
    final value = metadata()..['channel'] = 'preview';
    expect(() => parse(value, prerelease: true), throwsFormatException);
    expect(() => parse(value, allowPreview: true), throwsFormatException);
    expect(parse(value, prerelease: true, allowPreview: true).preview, isTrue);
    expect(() => parse(metadata(), prerelease: true, allowPreview: true), throwsFormatException);
  });
  test('missing schema, noninteger build, unsafe hash and size are rejected', () {
    expect(() => parse(metadata()..remove('schema')), throwsFormatException);
    expect(() => parse(metadata()..['versionCode'] = 20.5), throwsFormatException);
    final wrongHash = metadata();
    (wrongHash['apk'] as Map)['sha256'] = 'not-a-hash';
    expect(() => parse(wrongHash), throwsFormatException);
    final tooBig = metadata();
    (tooBig['apk'] as Map)['sizeBytes'] = ReleaseManifest.maximumApkBytes + 1;
    expect(() => parse(tooBig), throwsFormatException);
  });
  test('asset source is restricted to this repository and fixed filenames', () {
    final trusted = ReleaseManifest.assetUri('v2.0.0', ReleaseManifest.apkName);
    expect(ReleaseManifest.trustedAssetUri(trusted), isTrue);
    for (final address in [
      'http://github.com/fata69/oh-my-esok/releases/download/v2.0.0/oh-my-esok-universal.apk',
      'https://github.com/attacker/oh-my-esok/releases/download/v2.0.0/oh-my-esok-universal.apk',
      'https://github.com/fata69/oh-my-esok/releases/download/v2.0.0/random.apk',
      '${trusted.toString()}?url=https://example.com',
      'https://github.com.evil.test/fata69/oh-my-esok/releases/download/v2.0.0/oh-my-esok-universal.apk',
    ]) { expect(ReleaseManifest.trustedAssetUri(Uri.parse(address)), isFalse); }
  });
  test('redirects accept only exact GitHub CDN hosts with HTTPS', () {
    expect(ReleaseManifest.trustedRedirectUri(Uri.parse('https://release-assets.githubusercontent.com/a?token=temporary')), isTrue);
    expect(ReleaseManifest.trustedRedirectUri(Uri.parse('https://objects.githubusercontent.com/a')), isTrue);
    expect(ReleaseManifest.trustedRedirectUri(Uri.parse('https://githubusercontent.com.evil.test/a')), isFalse);
    expect(ReleaseManifest.trustedRedirectUri(Uri.parse('http://objects.githubusercontent.com/a')), isFalse);
  });
  test('download verification rejects changed and truncated bytes', () async {
    final directory = await Directory.systemTemp.createTemp('ohmyesok-ota-test');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/candidate.apk');
    final release = parse(metadata());
    await file.writeAsBytes([1, 2, 3]);
    await verifyDownloadedApk(file, release);
    await file.writeAsBytes([1, 2, 4]);
    await expectLater(verifyDownloadedApk(file, release), throwsFormatException);
    await file.writeAsBytes([1, 2]);
    await expectLater(verifyDownloadedApk(file, release), throwsFormatException);
  });
}
