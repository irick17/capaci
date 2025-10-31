import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// *** TODO 2: timezone と AppStrings をインポート ***
import 'package:timezone/timezone.dart' as tz;
import 'package:capaci/constants/app_strings.dart'; // (パスを修正)
import 'package:capaci/utils/logger.dart'; // (パスを修正)

/// 通知サービスを提供する Riverpod プロバイダー
final notificationServiceProvider = Provider<NotificationService>((ref) {
  // *** 修正: ref は不要になったため、コンストラクタに渡さない ***
  return NotificationService();
});

/// P3: ローカル通知を管理するサービスクラス
class NotificationService {
  // *** 修正: _ref は未使用のため削除 ***
  // final Ref _ref;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  // *** TODO 2: リマインダー用の通知IDを定義 ***
  static const int morningReminderId = 100;
  static const int eveningReminderId = 101;


  // *** 修正: _ref を削除 ***
  NotificationService();

  /// 通知サービスの初期化
  Future<void> initialize() async {
    logger.d("NotificationService: Initializing...");

    // 1. Android の初期設定
    // (通知アイコンは AndroidManifest.xml の android:icon="@mipmap/ic_launcher" を参照)
    // *** 修正: const -> final ***
    final AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_launcher'); // 'app_icon' から 'ic_launcher' に変更

    // 2. iOS の初期設定
    // *** 修正: const -> final ***
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false, // 権限要求は別途手動で行う
      requestBadgePermission: false,
      requestSoundPermission: false,
      // (フォアグラウンドでの通知表示設定は AppDelegate.swift で実施)
    );

    // 3. 初期化設定の統合
    // *** 修正: const -> final ***
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // 4. プラグインの初期化
    try {
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        // (任意) 通知がタップされたときの処理
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          logger.i("Notification tapped: ${response.payload}");
          // TODO: 通知タップ時に特定の画面に遷移するロジックを実装可能
        },
      );
      logger.d("NotificationService: Initialization complete.");
    } catch (e, stackTrace) {
      logger.e("NotificationService: Initialization failed.", error: e, stackTrace: stackTrace);
    }
  }

  /// 通知の権限を要求する (iOS と Android 13+)
  Future<void> requestPermissions() async {
    logger.d("NotificationService: Requesting permissions...");
    try {
      // iOS
      final bool? iOSResult = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      logger.d("iOS permission result: $iOSResult");

      // Android 13+ (API 33+)
      final bool? androidResult = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission(); // API 33 未満では null が返る
      logger.d("Android permission result: $androidResult");
      
    } catch (e, stackTrace) {
      logger.e("NotificationService: Permission request failed.", error: e, stackTrace: stackTrace);
    }
  }

  /// Android 用の通知チャンネル詳細設定
  AndroidNotificationDetails _androidNotificationDetails() {
    return const AndroidNotificationDetails(
      'capaci_channel_id', // チャンネルID
      'Capaci Notifications', // チャンネル名
      channelDescription: 'Capaci アプリからの通知（排卵予測、リマインドなど）', // チャンネルの説明
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      // (任意) LED ライトの色
      // color: Color(0xFF4A6C53), 
      // ledColor: Color(0xFF4A6C53),
      // ledOnMs: 1000,
      // ledOffMs: 500,
    );
  }

  /// iOS 用の通知詳細設定
  DarwinNotificationDetails _darwinNotificationDetails() {
    return const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      // (任意) サウンドファイル
      // sound: 'notification_sound.aiff',
    );
  }


  /// 即時通知を表示する
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    logger.i("Showing immediate notification: ID=$id, Title=$title, Body=$body");
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(
      android: _androidNotificationDetails(),
      iOS: _darwinNotificationDetails(),
    );

    try {
      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
       logger.i("Notification shown successfully.");
    } catch (e, stackTrace) {
      logger.e("Failed to show notification.", error: e, stackTrace: stackTrace);
    }
  }

  // *** TODO 2: 検査リマインダー用のスケジュール通知メソッド ***

  /// 指定した時刻（時・分）で、デバイスのローカルタイムゾーンにおける次の通知日時を取得する
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local); // デバイスのローカルタイムゾーンの現在時刻
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    
    // もし計算した時刻が現在時刻より前（つまり今日既に過ぎている）なら、明日の同じ時刻に設定
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    logger.d("Calculated next instance of $hour:$minute: $scheduledDate (local time)");
    return scheduledDate;
  }

  /// 内部用のスケジュールメソッド
  Future<void> _scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    logger.i("Scheduling daily notification: ID=$id, Time=$hour:$minute");
    try {
      final tz.TZDateTime scheduledDateTime = _nextInstanceOfTime(hour, minute);

      final NotificationDetails platformChannelSpecifics =
          NotificationDetails(
        android: _androidNotificationDetails(),
        iOS: _darwinNotificationDetails(),
      );

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDateTime,
        platformChannelSpecifics,
        // *** 修正: Android 12 以降の正確なアラーム許可が必要 (AndroidManifest.xmlに追加) ***
        // (ひとまず allowWhileIdle: true を設定)
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // androidAllowWhileIdle: true, // (古い記述)
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        // 毎日同じ時刻に繰り返す
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'reminder_$id',
      );
      logger.i("Successfully scheduled notification ID=$id");
    } catch (e, stackTrace) {
       logger.e("Failed to schedule notification ID=$id", error: e, stackTrace: stackTrace);
    }
  }

  /// 検査リマインダー (午前・午後) をスケジュールする
  Future<void> scheduleTestReminders() async {
    logger.d("Scheduling test reminders (AM & PM)...");
    
    // TODO: この時刻は後で設定画面 (P3) から変更できるようにする
    const int morningHour = 10; // 10:00 AM
    const int eveningHour = 20; // 8:00 PM (20:00)

    // 午前リマインダー
    await _scheduleDailyNotification(
      id: morningReminderId,
      title: AppStrings.notificationReminderTitle,
      body: AppStrings.notificationReminderBody,
      hour: morningHour,
      minute: 0,
    );

    // 午後リマインダー
    await _scheduleDailyNotification(
      id: eveningReminderId,
      title: AppStrings.notificationReminderTitle,
      body: AppStrings.notificationReminderBody,
      hour: eveningHour,
      minute: 0,
    );
  }

  /// 特定のIDの通知をキャンセルする
  Future<void> cancelNotification(int id) async {
     logger.i("Cancelling notification with ID: $id");
     try {
       await _flutterLocalNotificationsPlugin.cancel(id);
        logger.i("Notification ID=$id cancelled.");
     } catch (e, stackTrace) {
       logger.e("Failed to cancel notification ID=$id", error: e, stackTrace: stackTrace);
     }
  }

  /// スケジュールされたすべての通知をキャンセルする
  Future<void> cancelAllNotifications() async {
    logger.i("Cancelling ALL notifications...");
     try {
       await _flutterLocalNotificationsPlugin.cancelAll();
       logger.i("All notifications cancelled.");
     } catch (e, stackTrace) {
        logger.e("Failed to cancel all notifications", error: e, stackTrace: stackTrace);
     }
  }
}

