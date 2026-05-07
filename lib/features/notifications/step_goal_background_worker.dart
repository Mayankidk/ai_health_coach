import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'notification_service.dart';
import 'step_goal_monitor_service.dart';

const String stepGoalTaskName = 'neuralis.stepGoalCheck';
const String stepGoalUniqueWorkName = 'neuralis.stepGoalCheck.periodic';

@pragma('vm:entry-point')
void stepGoalCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    if (task != stepGoalTaskName) return Future.value(true);

    try {
      final notifications = NotificationService();
      await notifications.init(requestPermissions: false);
      await StepGoalMonitorService(notificationService: notifications)
          .checkGoalFromHealthConnect();
      return Future.value(true);
    } catch (e) {
      if (kDebugMode) {
        print('Step goal background task failed: $e');
      }
      return Future.value(false);
    }
  });
}

Future<void> initializeStepGoalBackgroundWorker() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

  try {
    await Workmanager().initialize(stepGoalCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      stepGoalUniqueWorkName,
      stepGoalTaskName,
      frequency: const Duration(minutes: 60),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  } catch (e) {
    if (kDebugMode) {
      print('Step goal worker registration failed: $e');
    }
  }
}
