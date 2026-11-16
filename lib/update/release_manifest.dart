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
  });

  static const applicationId = 'io.github.fata69.ohmyesok';
  static const apkName = 'oh-my-esok-universal.apk';
  static const maximumApkBytes = 300 * 1024 * 1024;
  final String tag;
  final String versionName;
  final int versionCode;
  final int minSdk;
  final int sizeBytes;
  final String sha256;
  final bool preview;

  factory ReleaseManifest.parse(
    Object? value, {
    required String releaseTag,
    required bool prerelease,
    required bool allowPreview,
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
    final apk = value['apk'];
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
        apk is! Map<String, dynamic> ||
        apk['name'] != apkName ||
        apk['sizeBytes'] is! int ||
        (apk['sizeBytes'] as int) < 1 ||
        (apk['sizeBytes'] as int) > maximumApkBytes ||
        apk['sha256'] is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(apk['sha256'] as String)) {
      throw const FormatException(
        'Metadata APK tidak lengkap atau tidak valid.',
      );
    }
    return ReleaseManifest(
      tag: releaseTag,
      versionName: versionName,
      versionCode: versionCode,
      minSdk: minSdk,
      sizeBytes: apk['sizeBytes'] as int,
      sha256: (apk['sha256'] as String).toLowerCase(),
      preview: preview,
    );
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
      {'ota-android.json', apkName}.contains(uri.pathSegments[5]) &&
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
