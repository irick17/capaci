import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
// コーチマーク用に追加
import 'package:showcaseview/showcaseview.dart';

import 'models/cycle_models.dart';
import 'startup_wrapper.dart'; // V1 (フロー 1)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ja_JP', null);
  await Hive.initFlutter();

  // Hive アダプタの登録 (重複登録を避ける)
  if (!Hive.isAdapterRegistered(CycleRecordAdapter().typeId)) {
    Hive.registerAdapter(CycleRecordAdapter());
  }
  if (!Hive.isAdapterRegistered(TestResultAdapter().typeId)) {
    Hive.registerAdapter(TestResultAdapter());
  }
   if (!Hive.isAdapterRegistered(CycleDataAdapter().typeId)) {
    Hive.registerAdapter(CycleDataAdapter());
  }

  // Box を開く
  await Hive.openBox<CycleData>('cycleBox');
  await Hive.openBox('settingsBox');

  runApp(
    const ProviderScope(
      // (エラー修正: child -> builder を使用)
      child: ShowCaseWidget(
         // builder でアプリのルートウィジェットを返す
         builder: Builder(builder: (_) => const CapaciApp()),
         // child: CapaciApp(), // child は使わない
      ),
    ),
  );
}

class CapaciApp extends StatelessWidget {
  const CapaciApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme lightColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4A6C53),
      brightness: Brightness.light,
    );
    final ColorScheme darkColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4A6C53),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Capaci',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: lightColorScheme,
        useMaterial3: true,
        fontFamily: 'Inter',
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: lightColorScheme.surfaceContainerHighest.withAlpha((255 * 0.5).round()),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            textStyle: WidgetStateProperty.resolveWith<TextStyle?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(fontWeight: FontWeight.bold);
                }
                return null;
              },
            ),
            backgroundColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return lightColorScheme.primaryContainer;
                }
                return lightColorScheme.surfaceContainer;
              },
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: lightColorScheme.inverseSurface,
          contentTextStyle: TextStyle(color: lightColorScheme.onInverseSurface),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: darkColorScheme,
        useMaterial3: true,
        fontFamily: 'Inter',
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: darkColorScheme.surfaceContainerHighest.withAlpha((255 * 0.5).round()),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            textStyle: WidgetStateProperty.resolveWith<TextStyle?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(fontWeight: FontWeight.bold);
                }
                return null;
              },
            ),
            backgroundColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return darkColorScheme.primaryContainer;
                }
                return darkColorScheme.surfaceContainer;
              },
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: darkColorScheme.inverseSurface,
          contentTextStyle: TextStyle(color: darkColorScheme.onInverseSurface),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const StartupWrapper(),
    );
  }
}

