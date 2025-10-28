import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'providers/settings_provider.dart'; // onboardingProvider のため

/// V1 (フロー 1) 起動時の画面振り分けウィジェット
/// オンボーディングが完了しているかどうかで表示する画面を切り替える
class StartupWrapper extends ConsumerWidget {
  const StartupWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // オンボーディング完了状態を監視
    final isOnboardingComplete = ref.watch(onboardingProvider);

    // (エラー修正: settingsBoxProvider は不要なので削除)
    // final settingsBoxAsync = ref.watch(settingsBoxProvider);

    // return settingsBoxAsync.when(
    //   data: (settingsBox) {
        if (isOnboardingComplete) {
          // オンボーディング完了済み -> ホーム画面へ
          return const HomeScreen();
        } else {
          // オンボーディング未完了 -> オンボーディング画面へ
          return const OnboardingScreen();
        }
    //   },
    //   loading: () => const Scaffold( // Box がロード中の表示 (任意)
    //     body: Center(child: CircularProgressIndicator.adaptive()),
    //   ),
    //   error: (err, stack) => Scaffold( // Box のロードエラー表示 (任意)
    //     body: Center(child: Text('設定の読み込みに失敗しました: $err')),
    //   ),
    // );
  }
}

