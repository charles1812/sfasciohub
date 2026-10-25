import 'package:flutter/material.dart';

import 'data/error_reporter.dart';
import 'data/repository.dart';
import 'ui/admin/admin_app.dart';

/// SfascioHub Admin: per chi gestisce la piattaforma (account, piazzali, costi AI).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Repository.init();
  ErrorReporter.install('admin');
  runApp(const AdminApp());
}
