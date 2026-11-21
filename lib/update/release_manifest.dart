/// The release contract contains metadata, never an arbitrary download URL.
class ReleaseManifest {
  const ReleaseManifest({
    required this.tag,
    required this.versionName,
    required this.versionCode,
    required this.minSdk,
    required this.sizeBytes,
    required this.sha256,
    required this.preview,
    this.assetName = apkName,
  });

  static const applicationId = 'io.github.fata69.ohmyesok';
  static const apkName = 'oh-my-esok-universal.apk';
  static const _apkNamesByAbi = {
    'arm64-v8a': 'oh-my-esok-arm64-v8a.apk',
    'armeabi-v7a': 'oh-my-esok-armeabi-v7a.apk',
    'x86_64': 'oh-my-esok-x86_64.apk',
  };
  static const maximumApkBytes = 300 * 1024 * 1024;
  final String tag;
  final String versionName;
  final int versionCode;
  final int minSdk;
  final int sizeBytes;
  final String sha256;
  final bool preview;
  final String assetName;

  factory ReleaseManifest.parse(
    Object? value, {
    required String releaseTag,
    required bool prerelease,
    required bool allowPreview,
    List<String> supportedAbis = const [],
    bool Function(String name, int size, String sha256)? isPublished,
  }) {
    if (value is! Map<String, dynamic> ||
        value['schema'] != 1 ||
        value['applicationId'] != applicationId ||
        value['tag'] != releaseTag ||
        !RegExp(r'^[A-Za-z0-9._+-]{1,100}$').hasMatch(releaseTag)) {
      throw const FormatException('Metadata pembaruan tidak sesuai aplikasi.');
    }
    final preview = value['channel'] == 'preview';
    if ((!preview && value['channel'] != 'stable') ||
        preview != prerelease ||
        (preview && !allowPreview)) {
      throw const FormatException('Saluran pembaruan tidak sesuai.');
    }
    final universal = _readApk(value['apk'], apkName);
    final versionCode = value['versionCode'];
    final minSdk = value['minSdk'];
    final versionName = value['versionName'];
    if (versionCode is! int ||
        versionCode < 1 ||
        minSdk is! int ||
        minSdk < 24 ||
        versionName is! String ||
        versionName.trim().isEmpty ||
        versionName.length > 80 ||
        universal == null) {
      throw const FormatException(
        'Metadata APK tidak lengkap atau tidak valid.',
      );
    }
    if (isPublished != null &&
        !isPublished(apkName, universal.size, universal.sha256)) {
      throw const FormatException('Ukuran atau checksum rilis tidak sesuai.');
    }
    var selected = universal;
    final variants = value['apkByAbi'];
    if (isPublished != null && variants is Map<String, dynamic>) {
      for (final abi in supportedAbis) {
        final name = _apkNamesByAbi[abi];
        if (name == null) continue;
        final apk = _readApk(variants[abi], name);
        if (apk != null && isPublished(name, apk.size, apk.sha256)) {
          selected = apk;
          break;
        }
      }
    }
    return ReleaseManifest(
      tag: releaseTag,
      versionName: versionName,
      versionCode: versionCode,
      minSdk: minSdk,
      sizeBytes: selected.size,
      sha256: selected.sha256,
      preview: preview,
      assetName: selected.name,
    );
  }

  static ({String name, int size, String sha256})? _readApk(
    Object? value,
    String name,
  ) {
    if (value is! Map<String, dynamic> || value['name'] != name) return null;
    final size = value['sizeBytes'];
    final hash = value['sha256'];
    if (size is! int ||
        size < 1 ||
        size > maximumApkBytes ||
        hash is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash)) {
      return null;
    }
    return (name: name, size: size, sha256: hash.toLowerCase());
  }

  bool newerThan(int installedCode) => versionCode > installedCode;

  static Uri assetUri(String tag, String name) => Uri.https(
    'github.com',
    '/fata69/oh-my-esok/releases/download/$tag/$name',
  );

  static bool trustedAssetUri(Uri uri) =>
      uri.scheme == 'https' &&
      !uri.hasPort &&
      uri.userInfo.isEmpty &&
      uri.host == 'github.com' &&
      uri.pathSegments.length == 6 &&
      uri.pathSegments[0] == 'fata69' &&
      uri.pathSegments[1] == 'oh-my-esok' &&
      uri.pathSegments[2] == 'releases' &&
      uri.pathSegments[3] == 'download' &&
      RegExp(r'^[A-Za-z0-9._+-]{1,100}$').hasMatch(uri.pathSegments[4]) &&
      {
        'ota-android.json',
        apkName,
        ..._apkNamesByAbi.values,
      }.contains(uri.pathSegments[5]) &&
      !uri.hasQuery &&
      !uri.hasFragment;

  static bool trustedRedirectUri(Uri uri) =>
      trustedAssetUri(uri) ||
      (uri.scheme == 'https' &&
          !uri.hasPort &&
          uri.userInfo.isEmpty &&
          !uri.hasFragment &&
          {
            'release-assets.githubusercontent.com',
            'objects.githubusercontent.com',
          }.contains(uri.host));
}
