import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

// --- V1 (フロー 1) オンボーディング完了状態 ---
final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, bool>((ref) {
  final box = Hive.box('settingsBox');
  return OnboardingNotifier(box);
});

class OnboardingNotifier extends StateNotifier<bool> {
  final Box _settingsBox;
  // (エラー修正: キーを static const にするか、直接文字列を使用)
  static const String _key = 'onboardingComplete'; // static const に変更

  OnboardingNotifier(this._settingsBox)
      // (エラー修正: static const _key を参照)
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
  final box = Hive.box('settingsBox');
  return CoachMarkShownNotifier(box);
});

class CoachMarkShownNotifier extends StateNotifier<bool> {
  final Box _settingsBox;
   // (エラー修正: キーを static const にするか、直接文字列を使用)
  static const String _key = 'coachMarkShown'; // static const に変更

  CoachMarkShownNotifier(this._settingsBox)
      // (エラー修正: static const _key を参照)
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

