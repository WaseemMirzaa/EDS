import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/drop_store.dart';
import 'data/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();

  final store = DropStore();
  await store.init();

  runApp(
    ChangeNotifierProvider.value(
      value: store,
      child: const DropTrackerApp(),
    ),
  );
}
