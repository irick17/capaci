import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// *** [TODO 2] timezone と AppStrings をインポート ***
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../constants/app_strings.dart';
import '../providers/settings_provider.dart'; // [TODO 3] AppSettings のため
import 'package:capaci/utils/logger.dart'; // (パスを修正)
// *** エラー修正: 'TimeOfDay' のために material.dart をインポート ***
import 'package:flutter/material.dart'; 


/// 通知サービスを提供する Riverpod プロバイダー
final notificationServiceProvider = Provider<NotificationService>((ref) {
  // *** 警告修正: ref を渡す ***
  return NotificationService(ref);
});

/// P3: ローカル通知を管理するサービスクラス
class NotificationService {
  // *** 警告修正: _ref を使用する (または削除する) ***
  final Ref _ref; // 
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // *** [TODO 2] リマインダー用の通知IDを定義 ***
  // (外部 (home_screen) から参照するため static const にする)
  static const int morningReminderId = 100;
  static const int eveningReminderId = 101;


  // *** 警告修正: ref を受け取る ***
  NotificationService(this._ref);

  /// 通知サービスの初期化
  Future<void> initialize() async {
    logger.d("NotificationService: Initializing...");

    // 1. Android の初期設定
    // (通知アイコンは AndroidManifest.xml の android:icon="@mipmap/ic_launcher" を参照)
    // *** 修正: const -> final ***
    // *** 警告修正: prefer_const_constructors ***
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_launcher'); // 'app_icon' から 'ic_launcher' に変更

    // 2. iOS の初期設定
    // *** 修正: const -> final ***
    // *** 警告修正: prefer_const_constructors ***
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false, // 権限要求は別途手動で行う
      requestBadgePermission: false,
      requestSoundPermission: false,
      // (フォアグラウンドでの通知表示設定は AppDelegate.swift で実施)
    );

    // 3. 初期化設定の統合
    // *** 修正: const -> final ***
    // *** 警告修正: prefer_const_constructors ***
    const InitializationSettings initializationSettings =
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

  // *** [TODO 2] 検査リマインダー用のスケジュール通知メソッド ***
  /// 毎日決まった時刻に通知をスケジュールする
  /// (*** [TODO 3] AppSettings を引数で受け取るように変更 ***)
  Future<void> scheduleTestReminders(AppSettings settings) async {
    // 1. 通知が OFF なら、既存の通知をキャンセルして終了
    if (!settings.notificationsEnabled) {
      logger.d("Notifications are disabled. Cancelling all scheduled reminders.");
      await cancelNotification(morningReminderId);
      await cancelNotification(eveningReminderId);
      return;
    }

    // 2. 通知が ON なら、設定時刻でスケジュール
    try {
      // --- 午前 ---
      // *** [TODO 3] ハードコードされた TimeOfDay(10, 0) の代わりに settings を使用 ***
      // *** エラー修正: reminderTimeMorning -> morningTime ***
      final tz.TZDateTime nextMorningTime = _nextInstanceOfTime(settings.morningTime);
      await _scheduleDailyNotification(
        id: morningReminderId,
        title: AppStrings.notificationReminderTitle,
        body: AppStrings.notificationReminderBody,
        scheduledTime: nextMorningTime,
      );
      logger.i("Scheduled morning reminder (ID $morningReminderId) for $nextMorningTime");

      // --- 午後 ---
      // *** [TODO 3] ハードコードされた TimeOfDay(20, 0) の代わりに settings を使用 ***
      // *** エラー修正: reminderTimeEvening -> eveningTime ***
      final tz.TZDateTime nextEveningTime = _nextInstanceOfTime(settings.eveningTime);
       await _scheduleDailyNotification(
        id: eveningReminderId,
        title: AppStrings.notificationReminderTitle,
        body: AppStrings.notificationReminderBody,
        scheduledTime: nextEveningTime,
      );
      logger.i("Scheduled evening reminder (ID $eveningReminderId) for $nextEveningTime");

    } catch (e, stackTrace) {
       logger.e("Failed to schedule test reminders.", error: e, stackTrace: stackTrace);
    }
  }

  /// 内部ヘルパー: 毎日同じ時刻にスケジュール
  Future<void> _scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
  }) async {
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(
      android: _androidNotificationDetails(),
      iOS: _darwinNotificationDetails(),
    );

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      platformChannelSpecifics,
      // *** 修正: Android 12 (API 31) 以上での権限 ***
      // (注: scheduleTestReminders がアプリ起動時に呼ばれる前提)
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // (iOS/Android共通) 毎日同じ "時刻" に繰り返す
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }


  /// 内部ヘルパー: TimeOfDay から次の tz.TZDateTime を計算
  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    // デバイスの現在時刻とローカルタイムゾーンを取得
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    
    // 今日の指定時刻を tz.TZDateTime で作成
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // もし指定時刻が既に過ぎていたら、明日の同じ時刻に設定
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// [TODO 3] 特定のIDの通知をキャンセル
  Future<void> cancelNotification(int id) async {
    logger.d("Cancelling notification ID: $id");
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  /// [TODO 3] すべての通知をキャンセル
  Future<void> cancelAllNotifications() async {
    logger.d("Cancelling ALL notifications.");
    await _flutterLocalNotificationsPlugin.cancelAll();
  }
}

