import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
// コーチマーク用に追加
import 'package:showcaseview/showcaseview.dart';
// *** 追加 ***
import 'package:flutter_localizations/flutter_localizations.dart';

// *** P3: 通知サービスをインポート ***
import 'services/notification_service.dart';

import 'models/cycle_models.dart';
import 'startup_wrapper.dart'; // V1 (フロー 1)
// logger を import (main でも使う可能性)
import 'utils/logger.dart';


// *** P3: main を Future<void> に変更し、ProviderScope をグローバルに定義 ***
// (ProviderScope を runApp の外に移動し、初期化時に ref を使えるようにする)
final container = ProviderContainer();

void main() async {
  // Ensure bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize logger early
  logger.d("App starting...");

  // Initialize localization data
  try {
    logger.d("Initializing date formatting...");
    await initializeDateFormatting('ja_JP', null);
    logger.d("Date formatting initialized.");
  } catch (e, stackTrace) {
     logger.e("Error initializing date formatting", error: e, stackTrace: stackTrace);
  }

  // Initialize Hive
  try {
    logger.d("Initializing Hive...");
    await Hive.initFlutter();
    logger.d("Hive initialized.");

    // Register Hive adapters (check if already registered)
    logger.d("Registering Hive adapters...");
    if (!Hive.isAdapterRegistered(CycleRecordAdapter().typeId)) {
      Hive.registerAdapter(CycleRecordAdapter());
      logger.d("Registered CycleRecordAdapter (typeId: ${CycleRecordAdapter().typeId})");
    } else {
       logger.d("CycleRecordAdapter already registered.");
    }
    if (!Hive.isAdapterRegistered(TestResultAdapter().typeId)) {
      Hive.registerAdapter(TestResultAdapter());
       logger.d("Registered TestResultAdapter (typeId: ${TestResultAdapter().typeId})");
    } else {
       logger.d("TestResultAdapter already registered.");
    }
     if (!Hive.isAdapterRegistered(CycleDataAdapter().typeId)) {
      Hive.registerAdapter(CycleDataAdapter());
      logger.d("Registered CycleDataAdapter (typeId: ${CycleDataAdapter().typeId})");
    } else {
        logger.d("CycleDataAdapter already registered.");
    }

    // Open Hive boxes
    logger.d("Opening Hive boxes...");
    await Hive.openBox<CycleData>('cycleBox');
    logger.d("Opened 'cycleBox'. Contains ${Hive.box<CycleData>('cycleBox').length} items.");
    await Hive.openBox('settingsBox');
    logger.d("Opened 'settingsBox'. Contains ${Hive.box('settingsBox').length} items.");
    logger.d("Hive setup complete.");

  } catch(e, stackTrace) {
     logger.e("!!! CRITICAL: Error initializing Hive !!!", error: e, stackTrace: stackTrace);
     // Consider showing an error message to the user or exiting
  }

  // *** P3: 通知サービスの初期化と権限要求 ***
  try {
    final notificationService = container.read(notificationServiceProvider);
    await notificationService.initialize();
    await notificationService.requestPermissions();
    logger.d("Notification service initialized and permissions requested.");
  } catch (e, stackTrace) {
     logger.e("Error initializing notification service", error: e, stackTrace: stackTrace);
  }
  // *** P3: 通知設定ここまで ***


  logger.d("Running app...");
  runApp(
     UncontrolledProviderScope( // (変更) ProviderScope -> UncontrolledProviderScope
       container: container,   // (追加) 既存のコンテナを渡す
      // (エラー修正: child -> builder を使用)
      child: ShowCaseWidget(
         // builder でアプリのルートウィジェットを返す
         // (修正) builderに関数を渡す
         builder: (context) => const CapaciApp(),
      ),
    ),
  );
}

class CapaciApp extends StatelessWidget {
  const CapaciApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Define ColorSchemes (Consider moving to a separate theme file later)
    final ColorScheme lightColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4A6C53), // Example Seed Color (Adjust as needed)
      brightness: Brightness.light,
      // Customize specific colors if needed
      // primary: const Color(0xFF...),
      // secondary: const Color(0xFF...),
      // surface: const Color(0xFF...),
      // background: const Color(0xFF...),
    );
    final ColorScheme darkColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4A6C53), // Use the same seed for consistency
      brightness: Brightness.dark,
      // Customize dark theme colors if needed
      // primary: const Color(0xFF...),
      // secondary: const Color(0xFF...),
      // surface: const Color(0xFF...),
      // background: const Color(0xFF...),
    );


    return MaterialApp(
      title: 'Capaci', // Consider using AppStrings.appName later
      debugShowCheckedModeBanner: false,

      // *** 追加: ローカライゼーション設定 ***
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate, // For Cupertino widgets if used
      ],
      supportedLocales: const [
        Locale('ja', 'JP'), // Japanese
        Locale('en', 'US'), // English as fallback (optional)
      ],
      locale: const Locale('ja', 'JP'), // Default locale to Japanese
      // *** ローカライゼーション設定ここまで ***


      theme: ThemeData(
        colorScheme: lightColorScheme,
        useMaterial3: true,
        fontFamily: 'Inter', // Ensure font is included in pubspec.yaml and assets
        // Define common theme properties once
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          // (修正) withAlpha を使う
          fillColor: lightColorScheme.surfaceContainerHighest.withAlpha((255 * 0.5).round()), // Use withAlpha
          hintStyle: TextStyle(color: lightColorScheme.onSurfaceVariant.withAlpha(150)), // Softer hint text
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
             // Define text style directly for consistency
            textStyle: WidgetStateProperty.resolveWith<TextStyle?>(
              (Set<WidgetState> states) {
                // Example: slightly bolder/different color when selected
                return TextStyle(
                  fontWeight: states.contains(WidgetState.selected) ? FontWeight.bold : FontWeight.normal,
                   color: states.contains(WidgetState.selected) ? lightColorScheme.onPrimaryContainer : lightColorScheme.onSurface,
                );
              },
            ),
            backgroundColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  // Use a color that contrasts well with the selected text
                  return lightColorScheme.primaryContainer;
                }
                // Use a less prominent background for unselected
                return lightColorScheme.surfaceContainer;
              },
            ),
             foregroundColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return lightColorScheme.onPrimaryContainer;
                }
                return lightColorScheme.onSurface;
              },
            ),
             // Define shape for rounded corners consistent with M3
             shape: WidgetStateProperty.all<OutlinedBorder>(
                 RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), // Adjust radius as needed
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: lightColorScheme.inverseSurface,
          contentTextStyle: TextStyle(color: lightColorScheme.onInverseSurface),
           // (修正) M3 recommends slightly larger radius
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Increased radius
          // Add elevation for floating effect
          elevation: 4,
        ),
        // (修正) CardThemeData を使用
        cardTheme: CardThemeData( // Use CardThemeData
           elevation: 1, // M3 default low elevation
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // M3 default radius
           // Define margin globally if needed, or handle per-card
           // margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
           clipBehavior: Clip.antiAlias, // Smoother edges
         ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
           backgroundColor: lightColorScheme.primary,
           foregroundColor: lightColorScheme.onPrimary,
        ),
        // (修正) BottomAppBarThemeData を使用
        bottomAppBarTheme: BottomAppBarThemeData( // Use BottomAppBarThemeData
           color: lightColorScheme.surfaceContainer, // M3 bottom app bar color
           elevation: 2, // Slight elevation
           // Define shape if needed, e.g., for notch
           shape: const CircularNotchedRectangle(), // Keep notch shape
           // padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), // Adjust padding
        ),
         listTileTheme: ListTileThemeData(
           iconColor: lightColorScheme.onSurfaceVariant, // Consistent icon color
         ),
         // Add TextButton theme if needed
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: lightColorScheme.primary, // Standard text button color
            ),
          ),
         // Add FilledButton theme if needed
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
               backgroundColor: lightColorScheme.primary,
               foregroundColor: lightColorScheme.onPrimary,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Consistent radius
             ),
          ),
          // Add OutlinedButton theme if needed
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: lightColorScheme.primary,
              side: BorderSide(color: lightColorScheme.outline),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Consistent radius
            ),
          ),
      ),

      // --- Dark Theme ---
      darkTheme: ThemeData(
        colorScheme: darkColorScheme,
        useMaterial3: true,
        fontFamily: 'Inter',
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          // (修正) withAlpha を使う
          fillColor: darkColorScheme.surfaceContainerHighest.withAlpha((255 * 0.5).round()), // Use withAlpha
          hintStyle: TextStyle(color: darkColorScheme.onSurfaceVariant.withAlpha(150)),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
             textStyle: WidgetStateProperty.resolveWith<TextStyle?>(
              (Set<WidgetState> states) {
                 return TextStyle(
                  fontWeight: states.contains(WidgetState.selected) ? FontWeight.bold : FontWeight.normal,
                   color: states.contains(WidgetState.selected) ? darkColorScheme.onPrimaryContainer : darkColorScheme.onSurface,
                 );
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
             foregroundColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return darkColorScheme.onPrimaryContainer;
                }
                return darkColorScheme.onSurface;
              },
            ),
             shape: WidgetStateProperty.all<OutlinedBorder>(
                 RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: darkColorScheme.inverseSurface,
          contentTextStyle: TextStyle(color: darkColorScheme.onInverseSurface),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
         // (修正) CardThemeData を使用
        cardTheme: CardThemeData( // Use CardThemeData
           elevation: 1,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           clipBehavior: Clip.antiAlias,
         ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
           backgroundColor: darkColorScheme.primaryContainer, // Use container color in dark typically
           foregroundColor: darkColorScheme.onPrimaryContainer,
        ),
         // (修正) BottomAppBarThemeData を使用
        bottomAppBarTheme: BottomAppBarThemeData( // Use BottomAppBarThemeData
           color: darkColorScheme.surfaceContainer,
           elevation: 2,
           shape: const CircularNotchedRectangle(),
        ),
         listTileTheme: ListTileThemeData(
           iconColor: darkColorScheme.onSurfaceVariant,
         ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: darkColorScheme.primary,
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
               backgroundColor: darkColorScheme.primary,
               foregroundColor: darkColorScheme.onPrimary,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
             ),
          ),
           outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: darkColorScheme.primary,
              side: BorderSide(color: darkColorScheme.outline),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
      ),
      themeMode: ThemeMode.system, // Or ThemeMode.light / ThemeMode.dark
      home: const StartupWrapper(), // Use StartupWrapper to decide initial screen
    );
  }
}