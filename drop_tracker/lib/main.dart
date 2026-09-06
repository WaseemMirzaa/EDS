// Firebase push notifications (FCM) are disabled — see the commented-out
// init block below. Local scheduling (NotificationService) remains the
// reminder backbone on its own; re-enable by uncommenting these three
// imports and the block in main().
// import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/auth_controller.dart';
import 'data/background_scheduler.dart';
import 'data/drop_store.dart';
import 'data/notification_service.dart';
// import 'data/remote/fcm_service.dart';
import 'data/remote/supabase_bootstrap.dart';
// import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  // Registers the background-task callback with the OS. Actually scheduling
  // the periodic run happens once there's data worth refreshing — see
  // DropStore's calls to BackgroundScheduler.schedulePeriodic().
  await BackgroundScheduler.initialize();

  // Firebase push notifications / FCM setup — disabled for now. Local
  // notifications (NotificationService, above) keep working unaffected;
  // this only drops the cross-device/fallback push layer described in
  // data/remote/fcm_service.dart. To re-enable, uncomment this block and
  // the three imports above.
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // await FcmService.instance.init();

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
