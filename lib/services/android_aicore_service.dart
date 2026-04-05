import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AicoreStatus {
  static const int unavailable = 0;
  static const int downloadable = 1;
  static const int downloading = 2;
  static const int available = 3;

  final int code;
  final String label;
  final bool platformSupported;
  final bool modelReady;
  final String? message;

  const AicoreStatus({
    required this.code,
    required this.label,
    required this.platformSupported,
    required this.modelReady,
    this.message,
  });

  bool get canDownload => code == downloadable || code == downloading;

  static AicoreStatus fromMap(Map<dynamic, dynamic> map) {
    final code = (map['statusCode'] as num?)?.toInt() ?? unavailable;
    final label = (map['statusLabel'] as String?) ?? 'UNAVAILABLE';
    final platformSupported = (map['platformSupported'] as bool?) ?? false;
    final modelReady = code == available;
    final message = map['message'] as String?;
    return AicoreStatus(
      code: code,
      label: label,
      platformSupported: platformSupported,
      modelReady: modelReady,
      message: message,
    );
  }

  factory AicoreStatus.unsupported(String message) {
    return AicoreStatus(
      code: unavailable,
      label: 'UNSUPPORTED',
      platformSupported: false,
      modelReady: false,
      message: message,
    );
  }
}

class AndroidAicoreService {
  static const MethodChannel _channel = MethodChannel('dayvault/aicore');

  bool get _isAndroid => Platform.isAndroid;

  Future<AicoreStatus> getStatus() async {
    if (!_isAndroid) {
      return AicoreStatus.unsupported('AICore is only available on Android.');
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'checkStatus',
      );
      if (result == null) {
        return AicoreStatus.unsupported('AICore status unavailable.');
      }
      return AicoreStatus.fromMap(result);
    } on PlatformException catch (e) {
      return AicoreStatus.unsupported(e.message ?? 'AICore status failed.');
    }
  }

  Future<AicoreStatus> requestDownload() async {
    if (!_isAndroid) {
      return AicoreStatus.unsupported('AICore is only available on Android.');
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'downloadModel',
      );
      if (result == null) {
        return AicoreStatus.unsupported('AICore download request failed.');
      }
      return AicoreStatus.fromMap(result);
    } on PlatformException catch (e) {
      return AicoreStatus.unsupported(e.message ?? 'AICore download failed.');
    }
  }

  Future<bool> ensureReady({bool autoDownload = true}) async {
    var status = await getStatus();
    if (status.modelReady) return true;
    if (!autoDownload || !status.canDownload) return false;

    await requestDownload();

    // Poll briefly so callers can proceed when the model becomes ready quickly.
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      status = await getStatus();
      if (status.modelReady) return true;
    }
    return false;
  }

  Future<String> generate(
    String prompt, {
    double? temperature,
    int? topK,
    int? maxOutputTokens,
  }) async {
    if (!_isAndroid) {
      throw StateError('AICore generation is only available on Android.');
    }

    final payload = <String, dynamic>{
      'prompt': prompt,
      if (temperature != null) 'temperature': temperature,
      if (topK != null) 'topK': topK,
      if (maxOutputTokens != null) 'maxOutputTokens': maxOutputTokens,
    };

    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'generate',
      payload,
    );
    if (result == null) {
      throw StateError('AICore generation returned no result.');
    }
    final text = (result['text'] as String?)?.trim() ?? '';
    if (text.isEmpty) {
      throw StateError('AICore generation returned empty output.');
    }
    return text;
  }
}

final androidAicoreServiceProvider = Provider<AndroidAicoreService>((ref) {
  return AndroidAicoreService();
});
