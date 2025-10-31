import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:capaci/utils/logger.dart'; // (パスを修正)

/// 通知サービスを提供する Riverpod プロバイダー
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref);
});

/// P3: ローカル通知を管理するサービスクラス
class NotificationService {
  final Ref _ref; // Riverpod の Ref
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  NotificationService(this._ref);

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

  // TODO: 検査リマインド用のスケジュール通知メソッドを後で追加
  // Future<void> scheduleTestReminder(...) async { ... }
}

