import 'package:flutter/material.dart'; // TimeOfDay のために必要
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/logger.dart'; // logger

// --- V1 (フロー 1) オンボーディング完了状態 ---

/// 設定 Box (main.dart で開いた 'settingsBox') を提供する Provider
/// (他の settings 関連 Provider がこれを参照する)
final settingsBoxProvider = Provider<Box>((ref) {
  // main.dart で既に開かれていることを前提とする
  return Hive.box('settingsBox');
});


final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, bool>((ref) {
  // settingsBoxProvider を watch して Box インスタンスを取得
  final box = ref.watch(settingsBoxProvider);
  return OnboardingNotifier(box);
});

class OnboardingNotifier extends StateNotifier<bool> {
  final Box _settingsBox;
  static const String _key = 'onboardingComplete';

  OnboardingNotifier(this._settingsBox)
      : super(_settingsBox.get(_key, defaultValue: false));

  void completeOnboarding() {
    _settingsBox.put(_key, true);
    state = true;
  }

  // (テスト用) 状態をリセットするメソッド
  void reset() {
     _settingsBox.put(_key, false);
     state = false;
  }
}

// --- V1 (初回ホーム コーチマーク) 表示済みフラグ ---
final coachMarkShownProvider =
    StateNotifierProvider<CoachMarkShownNotifier, bool>((ref) {
  // settingsBoxProvider を watch して Box インスタンスを取得
  final box = ref.watch(settingsBoxProvider);
  return CoachMarkShownNotifier(box);
});

class CoachMarkShownNotifier extends StateNotifier<bool> {
  final Box _settingsBox;
  static const String _key = 'coachMarkShown';

  CoachMarkShownNotifier(this._settingsBox)
      : super(_settingsBox.get(_key, defaultValue: false));

  void markAsShown() {
    _settingsBox.put(_key, true);
    state = true;
  }

   // (テスト用) 状態をリセットするメソッド
  void reset() {
     _settingsBox.put(_key, false);
     state = false;
  }
}


// --- [TODO 3] 通知設定 ---

// 1. 設定データモデル
// (Hive には TimeOfDay を直接保存できないため、int (分) に変換する)
class AppSettings {
  final bool notificationsEnabled;
  final TimeOfDay morningTime;
  final TimeOfDay eveningTime;

  // Hive に保存するためのデフォルト値
  static const bool defaultNotificationsEnabled = true;
  // *** 警告修正: final -> const ***
  static const TimeOfDay defaultMorningTime = TimeOfDay(hour: 10, minute: 0); // 10:00
  static const TimeOfDay defaultEveningTime = TimeOfDay(hour: 20, minute: 0); // 20:00

  AppSettings({
    required this.notificationsEnabled,
    required this.morningTime,
    required this.eveningTime,
  });

  // TimeOfDay を int (分) に変換
  int get morningTimeInMinutes => morningTime.hour * 60 + morningTime.minute;
  int get eveningTimeInMinutes => eveningTime.hour * 60 + eveningTime.minute;

  // int (分) から TimeOfDay に変換
  static TimeOfDay timeFromMinutes(int minutes) {
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  // Hive から読み込むためのファクトリコンストラクタ
  factory AppSettings.fromBox(Box box) {
    final bool enabled = box.get(
      _kNotificationsEnabled,
      defaultValue: defaultNotificationsEnabled,
    ) as bool;
    
    final int morningMinutes = box.get(
      _kMorningTime,
      defaultValue: defaultMorningTime.hour * 60 + defaultMorningTime.minute,
    ) as int;
    
    final int eveningMinutes = box.get(
      _kEveningTime,
      defaultValue: defaultEveningTime.hour * 60 + defaultEveningTime.minute,
    ) as int;

    return AppSettings(
      notificationsEnabled: enabled,
      morningTime: timeFromMinutes(morningMinutes),
      eveningTime: timeFromMinutes(eveningMinutes),
    );
  }
}

// 2. Hive に保存するためのキー (private)
const String _kNotificationsEnabled = 'notificationsEnabled';
const String _kMorningTime = 'morningTimeInMinutes';
const String _kEveningTime = 'eveningTimeInMinutes';


// 3. 設定ロジック (Notifier)
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  final Box _settingsBox;

  AppSettingsNotifier(this._settingsBox)
      : super(AppSettings.fromBox(_settingsBox)); // 初期値を Hive からロード

  // 通知のON/OFFを更新
  Future<void> updateNotificationsEnabled(bool isEnabled) async {
    logger.d("Updating notificationsEnabled: $isEnabled");
    await _settingsBox.put(_kNotificationsEnabled, isEnabled);
    state = AppSettings.fromBox(_settingsBox); // 状態を更新
  }

  // 朝の時刻を更新
  // *** エラー修正: updateReminderTimeMorning -> updateMorningTime ***
  Future<void> updateMorningTime(TimeOfDay newTime) async {
    final newMinutes = newTime.hour * 60 + newTime.minute;
    logger.d("Updating morningTime: $newTime ($newMinutes minutes)");
    await _settingsBox.put(_kMorningTime, newMinutes);
    state = AppSettings.fromBox(_settingsBox); // 状態を更新
  }

  // 夜の時刻を更新
  // *** エラー修正: updateReminderTimeEvening -> updateEveningTime ***
  Future<void> updateEveningTime(TimeOfDay newTime) async {
    final newMinutes = newTime.hour * 60 + newTime.minute;
    logger.d("Updating eveningTime: $newTime ($newMinutes minutes)");
    await _settingsBox.put(_kEveningTime, newMinutes);
    state = AppSettings.fromBox(_settingsBox); // 状態を更新
  }

  // (テスト用) 設定をリセット
  Future<void> reset() async {
     logger.d("Resetting app settings to default.");
     await _settingsBox.delete(_kNotificationsEnabled);
     await _settingsBox.delete(_kMorningTime);
     await _settingsBox.delete(_kEveningTime);
     state = AppSettings.fromBox(_settingsBox); // デフォルト値で状態を更新
  }
}

// 4. UIに公開する Provider
final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  final box = ref.watch(settingsBoxProvider);
  return AppSettingsNotifier(box);
});

