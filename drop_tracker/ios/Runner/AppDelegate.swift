import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // BGTaskScheduler requires a launch handler to be registered during
    // didFinishLaunching, in EVERY process lifetime, before any
    // BGTaskScheduler.submit() call will succeed — including the first one,
    // which workmanager_apple's own re-registration (keyed off a previous
    // session's UserDefaults) can't cover since nothing has been scheduled
    // yet. Skipping this crashes hard (NSInternalInconsistencyException,
    // not a catchable Dart/Swift error) the first time
    // BackgroundScheduler.schedulePeriodic() runs. Must match
    // BackgroundScheduler.taskUniqueName in
    // lib/data/background_scheduler.dart.
    if #available(iOS 13.0, *) {
      WorkmanagerPlugin.registerPeriodicTask(
        withIdentifier: "com.eyedropshop.droptracker.reminderRefresh")
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
