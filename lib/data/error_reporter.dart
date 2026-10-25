import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'repository.dart';

/// Manda al server gli errori non gestiti dell'app, così si vedono nell'app Admin (scheda Errori)
/// anche quando succedono sul telefono di un piazzale. In debug li mostra solo in console.
class ErrorReporter {
  static const _maxPerSession = 15;
  static final _sent = <String>{};
  static String _app = 'app';
  static String _version = '';

  static void install(String app) {
    _app = app;
    PackageInfo.fromPlatform().then((i) => _version = i.version).ignore();
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      previous?.call(details);
      _report(details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _report(error, stack);
      return true;
    };
  }

  static void _report(Object error, StackTrace? stack) {
    if (kDebugMode) return;
    final message = error.toString();
    if (_sent.length >= _maxPerSession || !_sent.add(message)) return;
    final lines = (stack?.toString() ?? '').split('\n').take(40).join('\n');
    Repository.instance.reportError({
      'app': _app,
      'version': _version,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'message': message.length > 500 ? message.substring(0, 500) : message,
      'stack': lines,
    });
  }
}
