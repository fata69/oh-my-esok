import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

abstract final class ReceiptInbox {
  static const _channel = MethodChannel('esok/receipt-inbox');
  static const _events = EventChannel('esok/receipt-inbox/changes');

  static final Stream<void> changes = Platform.isAndroid
      ? _events.receiveBroadcastStream().map<void>((_) {})
      : const Stream<void>.empty();

  static Future<List<File>> pendingImages() async {
    if (!Platform.isAndroid) return const [];
    final paths = await _channel.invokeListMethod<String>('pendingImages');
    return paths?.map(File.new).toList(growable: false) ?? const [];
  }

  static Future<void> discard(File file) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('discard', file.uri.pathSegments.last);
  }
}
