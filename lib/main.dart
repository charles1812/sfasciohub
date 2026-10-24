import 'package:flutter/material.dart';

import 'data/repository.dart';
import 'ui/explore/explore_app.dart';

/// SfascioHub Esplora: app pubblica e sito web per chi cerca ricambi.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Repository.init();
  runApp(const ExploreApp());
}
