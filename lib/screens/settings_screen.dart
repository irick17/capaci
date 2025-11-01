import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// *** 警告修正: 'app_strings.dart' はこのファイルで使われていないため削除 ***
// import '../constants/app_strings.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart'; // [TODO 3] 通知の再スケジュールのため
import '../utils/logger.dart';

/// [TODO 3] 設定画面 (P3)
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final settingsNotifier = ref.read(appSettingsProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // TimeOfDay を 'HH:mm' 形式（24時間表記）の文字列にフォーマットするヘルパー
    String formatTimeOfDay(TimeOfDay tod) {
      // BuildContext を使わずにフォーマットする
      final String hour = tod.hour.toString().padLeft(2, '0');
      final String minute = tod.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          // --- 通知設定セクション ---
          ListTile(
            title: Text("通知設定",
                style: textTheme.labelLarge
                    ?.copyWith(color: colorScheme.primary)),
          ),
          SwitchListTile(
            title: const Text('検査リマインダー通知'),
            subtitle: const Text('毎日決まった時刻に通知を送ります'),
            value: settings.notificationsEnabled,
            onChanged: (bool value) async {
              // [TODO 3] 設定を更新
              await settingsNotifier.updateNotificationsEnabled(value);
              // [TODO 3] 設定変更を通知スケジュールに即時反映
              _rescheduleNotifications(ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.wb_sunny_outlined),
            title: const Text('午前のリマインド時刻'),
            // *** エラー修正: reminderTimeMorning -> morningTime ***
            subtitle: Text(formatTimeOfDay(settings.morningTime)),
            // [TODO 3] 通知がOFFなら無効化
            enabled: settings.notificationsEnabled,
            onTap: () async {
              final TimeOfDay? newTime = await showTimePicker(
                context: context,
                // *** エラー修正: reminderTimeMorning -> morningTime ***
                initialTime: settings.morningTime,
              );
              if (newTime != null) {
                // [TODO 3] 設定を更新
                // *** エラー修正: updateReminderTimeMorning -> updateMorningTime ***
                await settingsNotifier.updateMorningTime(newTime);
                _rescheduleNotifications(ref);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.nightlight_outlined),
            title: const Text('午後のリマインド時刻'),
            // *** エラー修正: reminderTimeEvening -> eveningTime ***
            subtitle: Text(formatTimeOfDay(settings.eveningTime)),
            // [TODO 3] 通知がOFFなら無効化
            enabled: settings.notificationsEnabled,
            onTap: () async {
              final TimeOfDay? newTime = await showTimePicker(
                context: context,
                // *** エラー修正: reminderTimeEvening -> eveningTime ***
                initialTime: settings.eveningTime,
              );
              if (newTime != null) {
                // [TODO 3] 設定を更新
                // *** エラー修正: updateReminderTimeEvening -> updateEveningTime ***
                await settingsNotifier.updateEveningTime(newTime);
                _rescheduleNotifications(ref);
              }
            },
          ),

          // --- データ管理セクション ---
          const Divider(),
          ListTile(
            title: Text("データ管理",
                style: textTheme.labelLarge
                    ?.copyWith(color: colorScheme.primary)),
          ),
          ListTile(
            // *** エラー修正: delete_forever_outline -> delete_forever_outlined ***
            leading: Icon(Icons.delete_forever_outlined, color: colorScheme.error),
            title: Text('全データをリセット',
                style: TextStyle(color: colorScheme.error)),
            subtitle: const Text('周期データ、記録、設定がすべて削除されます'),
            // *** 警告修正: withOpacity(0.05) -> withAlpha(13) ***
            tileColor: colorScheme.error.withAlpha(13), // 警告色
            onTap: () {
              // TODO: リセット確認ダイアログ表示
              logger.w("Data reset tapped (confirmation dialog not yet implemented).");
              // (仮実装: 確認なしでリセット)
              // ref.read(appSettingsProvider.notifier).reset();
              // ref.read(onboardingProvider.notifier).reset();
              // ref.read(coachMarkShownProvider.notifier).reset();
              // ref.read(cycleDataProvider.notifier).deleteAllCycles(); // (CycleDataNotifierにdeleteAllCyclesを実装する必要あり)
            },
          ),
        ],
      ),
    );
  }

  /// [TODO 3] 設定変更時に通知を再スケジュールする
  void _rescheduleNotifications(WidgetRef ref) {
    logger.d("SettingsScreen: Rescheduling notifications due to settings change.");
    try {
      final notificationService = ref.read(notificationServiceProvider);
      // 最新の設定を読み直す
      final settings = ref.read(appSettingsProvider); 
      // サービスにスケジュール更新を依頼
      notificationService.scheduleTestReminders(settings);
    } catch (e, stackTrace) {
      logger.e("Failed to reschedule notifications from SettingsScreen", error: e, stackTrace: stackTrace);
    }
  }
}

