import 'package:flutter/material.dart';

import 'data/error_reporter.dart';
import 'data/repository.dart';
import 'ui/yard/yard_app.dart';

/// SfascioHub Gestione: app per chi lavora nello sfasciacarrozze.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Repository.init();
  ErrorReporter.install('gestione');
  runApp(const YardApp());
}
