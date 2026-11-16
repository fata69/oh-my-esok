import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:jadwal/update/update_controller.dart';

class _Headers extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.statusCode, Object body)
    : bytes = utf8.encode(jsonEncode(body));
  @override
  final int statusCode;
  final List<int> bytes;
  @override
  int get contentLength => bytes.length;
  @override
  HttpHeaders get headers => _Headers();
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request extends Fake implements HttpClientRequest {
  _Request(this.response);
  final HttpClientResponse response;
  @override
  set followRedirects(bool value) {}
  @override
  HttpHeaders get headers => _Headers();
  @override
  Future<HttpClientResponse> close() async => response;
}

class _Client extends Fake implements HttpClient {
  _Client(this.responses);
  final List<HttpClientResponse> responses;
  final requested = <Uri>[];
  @override
  set connectionTimeout(Duration? value) {}
  @override
  Future<HttpClientRequest> getUrl(Uri uri) async {
    requested.add(uri);
    return _Request(responses.removeAt(0));
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Oh My Esok',
      packageName: 'io.github.fata69.ohmyesok',
      version: '2.0.0-preview.1',
      buildNumber: '20',
      buildSignature: 'test',
    );
  });
  test('no stable GitHub release is accurately displayed', () async {
    final client = _Client([
      _Response(404, {'message': 'Not Found'}),
    ]);
    final controller = UpdateController.withClient(() => client);
    addTearDown(controller.dispose);
    await controller.check();
    expect(controller.phase, UpdatePhase.noRelease);
    expect(
      client.requested.single.toString(),
      'https://api.github.com/repos/fata69/oh-my-esok/releases/latest',
    );
    expect(controller.release, isNull);
  });
  test(
    'preview is opt-in and an empty release list is not up-to-date',
    () async {
      final client = _Client([_Response(200, [])]);
      final controller = UpdateController.withClient(() => client)
        ..allowPreview = true;
      addTearDown(controller.dispose);
      await controller.check();
      expect(controller.phase, UpdatePhase.noRelease);
      expect(client.requested.single.path, '/repos/fata69/oh-my-esok/releases');
    },
  );
  test('rate limit cannot be reported as latest version', () async {
    final controller = UpdateController.withClient(
      () => _Client([_Response(403, {})]),
    );
    addTearDown(controller.dispose);
    await controller.check();
    expect(controller.phase, UpdatePhase.failed);
    expect(controller.message, contains('GitHub'));
  });
  Map<String, Object> release() => {
    'draft': false,
    'prerelease': false,
    'tag_name': 'v2.1.0',
    'body': 'Catatan rilis sintetis',
    'assets': [
      {
        'name': 'ota-android.json',
        'browser_download_url': 'https://github.com/fata69/oh-my-esok/releases/download/v2.1.0/ota-android.json',
      },
      {
        'name': 'oh-my-esok-universal.apk',
        'size': 123,
        'browser_download_url': 'https://github.com/fata69/oh-my-esok/releases/download/v2.1.0/oh-my-esok-universal.apk',
      },
    ],
  };
  Map<String, Object> metadata() => {
    'schema': 1,
    'channel': 'stable',
    'tag': 'v2.1.0',
    'applicationId': 'io.github.fata69.ohmyesok',
    'versionName': '2.1.0',
    'versionCode': 21,
    'minSdk': 24,
    'apk': {
      'name': 'oh-my-esok-universal.apk',
      'sizeBytes': 123,
      'sha256': List.filled(64, 'a').join(),
    },
  };
  test(
    'new validated release becomes available with its release notes',
    () async {
      final client = _Client([
        _Response(200, release()),
        _Response(200, metadata()),
      ]);
      final controller = UpdateController.withClient(() => client);
      addTearDown(controller.dispose);
      await controller.check();
      expect(controller.phase, UpdatePhase.available);
      expect(controller.release?.versionCode, 21);
      expect(controller.notes, 'Catatan rilis sintetis');
      expect(client.requested.last.path, endsWith('/ota-android.json'));
    },
  );
  test('same or older builds never expose a download', () async {
    final info = metadata()..['versionCode'] = 19;
    final controller = UpdateController.withClient(
      () => _Client([_Response(200, release()), _Response(200, info)]),
    );
    addTearDown(controller.dispose);
    await controller.check();
    expect(controller.phase, UpdatePhase.upToDate);
    expect(controller.release, isNull);
  });
  test('metadata identity mismatch fails without offering the APK', () async {
    final info = metadata()..['applicationId'] = 'com.habib.jadwal';
    final controller = UpdateController.withClient(
      () => _Client([_Response(200, release()), _Response(200, info)]),
    );
    addTearDown(controller.dispose);
    await controller.check();
    expect(controller.phase, UpdatePhase.failed);
    expect(controller.release, isNull);
  });
}
