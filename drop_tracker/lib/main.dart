import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/auth_controller.dart';
import 'data/drop_store.dart';
import 'data/notification_service.dart';
import 'data/remote/supabase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();

  // Must finish before DropStore/AuthController.init() run — both check for a
  // live Supabase session, and initializing the client is a no-op when no
  // project is configured (see data/remote/supabase_config.dart).
  await SupabaseBootstrap.init();

  final store = DropStore();
  final auth = AuthController();
  await Future.wait([store.init(), auth.init()]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: auth),
      ],
      child: const DropTrackerApp(),
    ),
  );
}
