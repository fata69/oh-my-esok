import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jadwal/update/update_availability.dart';
import 'package:jadwal/update/update_controller.dart';

class _Headers extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.statusCode, Object body)
    : bytes = utf8.encode(jsonEncode(body));
  _Response.bytes(this.statusCode, this.bytes);
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
    'automatic availability uses validation and is cached for six hours',
    () async {
      SharedPreferences.setMockInitialValues({});
      var now = DateTime.utc(2026, 11, 18);
      final client = _Client([
        _Response(200, release()),
        _Response(200, metadata()),
      ]);
      final first = UpdateAvailability(
        controllerFactory: () => UpdateController.withClient(() => client),
        now: () => now,
      );
      addTearDown(first.dispose);
      await Future.wait([
        first.checkAutomatically(),
        first.checkAutomatically(),
      ]);
      expect(first.available, isTrue);
      expect(client.requested, hasLength(2));

      final failure = _Client([_Response(403, {})]);
      final restored = UpdateAvailability(
        controllerFactory: () => UpdateController.withClient(() => failure),
        now: () => now,
      );
      addTearDown(restored.dispose);
      now = now.add(const Duration(hours: 5));
      await restored.checkAutomatically();
      expect(restored.available, isTrue);
      expect(failure.requested, isEmpty);
      now = now.add(const Duration(hours: 1));
      var changes = 0;
      restored.addListener(() => changes++);
      await restored.checkAutomatically();
      await restored.checkAutomatically();
      expect(failure.requested, hasLength(1));
      expect(restored.available, isTrue);
      expect(changes, 0);
    },
  );

  test(
    'first failed automatic check stays invisible and persists attempt',
    () async {
      SharedPreferences.setMockInitialValues({});
      final client = _Client([_Response(403, {})]);
      UpdateAvailability state() => UpdateAvailability(
        controllerFactory: () => UpdateController.withClient(() => client),
        now: () => DateTime.utc(2026, 11, 18),
      );
      final first = state();
      final restarted = state();
      addTearDown(first.dispose);
      addTearDown(restarted.dispose);
      await first.checkAutomatically();
      await restarted.checkAutomatically();
      expect(first.available, isFalse);
      expect(restarted.available, isFalse);
      expect(client.requested, hasLength(1));
    },
  );

  test(
    'preview opt-in survives restart and opt-out clears the preview hint',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preview = release()..['prerelease'] = true;
      final manifest = metadata()..['channel'] = 'preview';
      final client = _Client([
        _Response(200, [preview]),
        _Response(200, manifest),
      ]);
      UpdateAvailability state() => UpdateAvailability(
        controllerFactory: () => UpdateController.withClient(() => client),
        now: () => DateTime.utc(2026, 11, 18),
      );
      final first = state();
      final restarted = state();
      final optedOut = state();
      for (final availability in [first, restarted, optedOut]) {
        addTearDown(availability.dispose);
      }
      await first.load();
      expect(first.allowPreview, isFalse);
      await first.setAllowPreview(true);
      await restarted.checkAutomatically();
      expect(restarted.allowPreview, isTrue);
      expect(client.requested.first.queryParameters, {'per_page': '20'});
      expect(restarted.available, isTrue);
      await restarted.setAllowPreview(false);
      await optedOut.load();
      expect(restarted.available, isFalse);
      expect(optedOut.allowPreview, isFalse);
      expect(optedOut.available, isFalse);
    },
  );
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

  test('selects and downloads a compatible standalone APK', () async {
    const name = 'oh-my-esok-arm64-v8a.apk';
    final bytes = [1, 2, 3];
    final hash = sha256.convert(bytes).toString();
    final info = metadata()
      ..['apkByAbi'] = {
        'arm64-v8a': {'name': name, 'sizeBytes': bytes.length, 'sha256': hash},
      };
    final tag = info['tag'];
    final url =
        'https://github.com/fata69/oh-my-esok/releases/download/$tag/$name';
    final releaseData = release();
    (releaseData['assets']! as List).add({
      'name': name,
      'size': bytes.length,
      'digest': 'sha256:$hash',
      'browser_download_url': url,
    });
    final client = _Client([
      _Response(200, releaseData),
      _Response(200, info),
      _Response.bytes(200, bytes),
    ]);
    final cache = await Directory.systemTemp.createTemp('oh-my-esok-abi-test');
    addTearDown(() => cache.delete(recursive: true));
    const bridge = MethodChannel('ohmyesok/update');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(bridge, (call) async {
      expect(call.method, 'checkApk');
      expect(call.arguments['versionCode'], 21);
      expect(call.arguments['sha256'], hash);
      expect(call.arguments['sizeBytes'], bytes.length);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(bridge, null));
    final controller = UpdateController.withClient(
      () => client,
      supportedAbis: () async => ['arm64-v8a', 'armeabi-v7a'],
      temporaryDirectory: () async => cache,
    );
    addTearDown(controller.dispose);
    await controller.check();
    expect(controller.release?.assetName, name);
    await controller.download();
    expect(client.requested.last.toString(), url);
    expect(controller.phase, UpdatePhase.ready);
  });

  test(
    'falls back to universal if a compatible asset is absent or invalid',
    () async {
      const name = 'oh-my-esok-arm64-v8a.apk';
      final info = metadata()
        ..['apkByAbi'] = {
          'arm64-v8a': {'name': name, 'sizeBytes': 3, 'sha256': 'b' * 64},
        };
      for (final invalidAsset in [
        null,
        {
          'name': name,
          'size': 3,
          'browser_download_url': 'https://example.org/$name',
        },
      ]) {
        final releaseData = release();
        if (invalidAsset != null) {
          (releaseData['assets']! as List).add(invalidAsset);
        }
        final controller = UpdateController.withClient(
          () => _Client([_Response(200, releaseData), _Response(200, info)]),
          supportedAbis: () async => ['arm64-v8a'],
        );
        addTearDown(controller.dispose);
        await controller.check();
        expect(controller.phase, UpdatePhase.available);
        expect(controller.release?.assetName, 'oh-my-esok-universal.apk');
      }
    },
  );
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

  test(
    'installer failure unlocks the page without a lifecycle change',
    () async {
      const bridge = MethodChannel('ohmyesok/update');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final cache = await Directory.systemTemp.createTemp(
        'oh-my-esok-install-test',
      );
      addTearDown(() => cache.delete(recursive: true));
      final binary = List<int>.generate(123, (index) => index);
      final info = metadata();
      (info['apk']! as Map)['sha256'] = sha256.convert(binary).toString();
      final firstPoll = Completer<void>();
      final nextPoll = Completer<void>();
      var installCalls = 0;
      var statusCalls = 0;
      var nativeStatus = 'pending';
      messenger.setMockMethodCallHandler(bridge, (call) async {
        switch (call.method) {
          case 'checkApk':
            return null;
          case 'canInstall':
            return true;
          case 'install':
            installCalls++;
            return null;
          case 'installStatus':
            statusCalls++;
            if (statusCalls == 1) firstPoll.complete();
            if (statusCalls == 2) nextPoll.complete();
            return nativeStatus;
        }
        throw StateError('Unexpected method: ${call.method}');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(bridge, null));
      final responses = [
        _Response(200, release()),
        _Response(200, info),
        _Response.bytes(200, binary),
      ];
      final controller = UpdateController.withClient(
        () => _Client(responses),
        temporaryDirectory: () async => cache,
        installPollInterval: const Duration(milliseconds: 5),
      );
      addTearDown(controller.dispose);
      await controller.check();
      await controller.download();
      expect(controller.phase, UpdatePhase.ready);
      await Future.wait([controller.install(), controller.install()]);
      await firstPoll.future.timeout(const Duration(seconds: 2));
      await nextPoll.future.timeout(const Duration(seconds: 2));
      expect(controller.phase, UpdatePhase.awaitingAndroid);
      expect(installCalls, 1);

      final unlocked = Completer<void>();
      controller.addListener(() {
        if (controller.phase == UpdatePhase.ready && !unlocked.isCompleted) {
          unlocked.complete();
        }
      });
      nativeStatus = 'failed';
      await unlocked.future.timeout(const Duration(seconds: 2));
      expect(controller.busy, isFalse);
      expect(controller.message, contains('ditolak Android'));
      expect(installCalls, 1);
    },
  );
}
