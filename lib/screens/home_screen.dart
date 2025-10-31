// (エラー修正: import パス修正)
// ignore_for_file: unused_import

// *** 修正: dart:ui に修正 ***
import 'dart:ui' as ui; // For PointMode
// *** P1: ハイライトアニメーション用 (Timer) ***
import 'dart:async';

// *** P3: カレンダー連携 ***
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../components/timing_record_modal.dart';
// ChartData を import
import '../utils/prediction_logic.dart';
// *** 修正: package:flutter/material.dart に修正 ***
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// (エラー修正: import パス修正 & DateFormat のため)
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
// コーチマーク用に追加
import 'package:showcaseview/showcaseview.dart';

// V1.1 (3.1.3) / V1 (フロー 3)
import '../components/record_modal.dart';
// V1 (UX ライティング)
import '../constants/app_strings.dart';
// V1.1 (5.1) データモデル (エラー修正: prefix 'models' を追加)
import '../models/cycle_models.dart' as models;
// V1.1 (5.2) 状態管理 (Provider)
import '../providers/cycle_state_provider.dart';
// コーチマーク用に追加
import '../providers/settings_provider.dart';
// logger を import
import '../utils/logger.dart';
// *** TODO 2: 通知サービスをインポート ***
import '../services/notification_service.dart';
// *** 修正: カレンダー画面をインポート ***
import 'calendar_screen.dart';

/// 画面遷移図 (GA-01): ホーム (統合グラフ) 画面
/// V1.1 (3.1) / V1.2 (2.1)
/// アプリの唯一の主要画面。P1/P0（グラフ）と P2（入力）の起点。
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // (修正) viewportFraction を 1.0 に戻し、左右のpaddingで見切れ効果を出す
  final PageController _pageController = PageController(
    viewportFraction: 1.0, // ページ全体を表示
    initialPage: 0, // 初期ページを先頭に
  );
  late TooltipBehavior _tooltipBehavior;
  late PredictionLogic _predictionLogic;

  // コーチマーク用の GlobalKey を定義
  final GlobalKey _fabKey = GlobalKey();

  // 現在表示中のページインデックスを管理
  // StateNotifierProvider (`currentCycleIndexProvider`) に移行済み
  // int _currentPageIndex = 0; // StateNotifierProviderを使うため不要に

  @override
  void initState() {
    super.initState();
    _tooltipBehavior = TooltipBehavior(enable: true);
    _predictionLogic = PredictionLogic();
    logger.d("HomeScreen initState finished."); // Log initState completion

    // V1 (初回ホーム コーチマーク)
    // *** TODO 2 (通知スケジュール) ***
    // 画面ビルド後にコーチマークと通知スケジュールを開始する
    WidgetsBinding.instance.addPostFrameCallback((_) => _onHomeScreenReady());
  }

  @override
  void dispose() {
    _pageController.dispose(); // PageControllerをdispose
    logger.d("HomeScreen disposed."); // Log dispose
    super.dispose();
  }

  /// *** TODO 2 (通知スケジュール) ***
  /// 画面ビルド完了後にコーチマークと通知スケジュールを実行
  void _onHomeScreenReady() {
    _showCoachMark();
    _scheduleNotifications(); // *** TODO 2: 通知スケジュールの呼び出し ***
  }

  /// V1 (初回ホーム コーチマーク) 表示ロジック
  void _showCoachMark() {
    logger.d("Attempting to show coach mark..."); // Log attempt
    try { // コーチマーク表示も try-catch
      final isOnboardingComplete = ref.read(onboardingProvider);
      final isCoachMarkShown = ref.read(coachMarkShownProvider);
      logger.d(
          "Onboarding complete: $isOnboardingComplete, Coach mark shown: $isCoachMarkShown"); // Log values

      // mounted check
      if (!mounted) {
        logger.w("Coach mark check skipped: widget not mounted.");
        return;
      }

      if (isOnboardingComplete && !isCoachMarkShown) {
        // Use context directly if available, otherwise check mounted status
        // Ensure BuildContext is valid before calling ShowCaseWidget.of
        // Schedule for after build
        Future.microtask(() {
          if (mounted) { // Check mounted again inside microtask
            try {
              final showCaseContext = ShowCaseWidget.of(context);
              // Check if context is still valid and has ShowCaseWidget ancestor
              logger.d("Starting showcase...");
              showCaseContext.startShowCase([_fabKey]);
              // Mark as shown *after* starting successfully
              ref.read(coachMarkShownProvider.notifier).markAsShown();
              logger.d("Coach mark started and marked as shown.");
            } catch (e, stackTrace) {
              logger.e("Error starting showcase or marking as shown",
                  error: e, stackTrace: stackTrace);
            }
          } else {
            logger.w(
                "Showcase start skipped: widget unmounted before microtask execution.");
          }
        });
      } else {
        logger.d("Conditions not met to show coach mark."); // Log why not shown
      }
    } catch (e, stackTrace) {
      logger.e("Error showing coach mark", error: e, stackTrace: stackTrace);
    }
  }

  /// *** TODO 2: 通知スケジュールの呼び出し ***
  /// 検査リマインダー通知をスケジュールする
  Future<void> _scheduleNotifications() async {
    logger.d("Scheduling notifications...");
    try {
      final notificationService = ref.read(notificationServiceProvider);

      // 将来的に設定画面でON/OFFできるように、既存のスケジュールを一旦キャンセル
      // *** 修正: NotificationServiceで定義したIDを使用 ***
      await notificationService
          .cancelNotification(NotificationService.morningReminderId);
      await notificationService
          .cancelNotification(NotificationService.eveningReminderId);

      // 新しいスケジュールを設定
      await notificationService.scheduleTestReminders();
      logger.d("Test reminders scheduled successfully.");
    } catch (e, stackTrace) {
      logger.e("Failed to schedule notifications",
          error: e, stackTrace: stackTrace);
      // (任意) ユーザーにエラーを通知
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text('通知のスケジュール設定に失敗しました。')),
      //   );
      // }
    }
  }
  // *** TODO 2: ここまで ***

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // V1 (P1) GOLDEN TIME 状態を監視
    final isGoldenTime = ref.watch(goldenTimeProvider);
    logger.d("HomeScreen build: isGoldenTime = $isGoldenTime"); // Log state

    // V1 (P3) 周期データの総数を監視 (PageView の itemCount)
    final cycleList = ref.watch(cycleDataProvider); // Watch the list directly
    final cycleCount = cycleList.length;
    final currentCycleIndex =
        ref.watch(currentCycleIndexProvider); // Watch the index
    logger.d(
        "HomeScreen build: cycleCount = $cycleCount, currentCycleIndex = $currentCycleIndex");

    // PageController を現在のインデックスに同期 (初回ビルド後 or index変更時)
    // Avoid calling jumpToPage during build, use addPostFrameCallback or listen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _pageController.hasClients &&
          _pageController.page?.round() != currentCycleIndex) {
        logger.d("Syncing PageController to index: $currentCycleIndex");
        _pageController.jumpToPage(
            currentCycleIndex); // Use jumpToPage for immediate effect without animation
      }
    });

    return Scaffold(
      // V1.1 (3.1) / V1 (フロー 2)
      appBar: AppBar(
        // (任意) V1 (A) GOLDEN TIME時のヘッダー色変更
        backgroundColor: isGoldenTime ? colorScheme.primaryContainer : null,
        foregroundColor: isGoldenTime ? colorScheme.onPrimaryContainer : null,
        // V1 (3.1) タイトル
        title: Text(
          AppStrings.homeTitle,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          // *** P3: カレンダー連携ボタン ***
          IconButton(
            icon: Icon(Icons.share_outlined, // 共有アイコン
                color: isGoldenTime
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant),
            tooltip: AppStrings.shareCalendarTooltip,
            onPressed: () {
              logger.i("Share button pressed. Triggering _shareToCalendar...");
              _shareToCalendar(); // カレンダー連携ロジックを呼び出す
            },
          ),
          // V1 (P3) 将来的なカレンダー機能 (アイコン変更)
          IconButton(
            icon: Icon(Icons.calendar_month_outlined, // More standard calendar icon
                color: isGoldenTime
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant),
            tooltip: 'カレンダー表示', // (修正) ツールチップ
            onPressed: () {
              // *** 修正: CalendarScreen への遷移を実装 ***
              logger
                  .i("Calendar button pressed. Navigating to CalendarScreen...");
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const CalendarScreen()),
              );
              // *** 修正ここまで ***
            },
            // (任意) GOLDEN TIME時の色変更
            // color: isGoldenTime ? colorScheme.onPrimaryContainer : null, // Handled above
          ),
          // V1.1 (3.1.1) / V1.2 (2.5) ヘルプ機能 (P1/P3)
          IconButton(
            // (任意) GOLDEN TIME時の色変更
            icon: Icon(Icons.help_outline,
                color: isGoldenTime
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant),
            tooltip: AppStrings.helpModalTitle,
            onPressed: () => _buildHelpModal(context, colorScheme, textTheme),
          ),
        ],
      ),
      body: Column(
        children: [
          // V1 (P1) 3.1.2 GOLDEN TIME 状態表示 (Card)
          // (修正) AnimatedSize と Visibility を使用
          AnimatedSize(
            // (修正) const を追加
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Visibility(
              visible: isGoldenTime,
              // *** ここから Card の中身を実装 ***
              child: Card(
                // V1.2 (2.2) スタイル適用
                elevation: 1,
                color: colorScheme.primaryContainer,
                // (修正) BorderRadiusをM3標準に
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(16.0)), // M3 card radius
                // (修正) const を追加
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                clipBehavior: Clip.antiAlias, // Ensure content respects shape
                // (修正) const を追加
                child: Padding(
                  // Add padding inside the card
                  padding: const EdgeInsets.symmetric(
                      vertical: 12.0, horizontal: 16.0), // Adjust padding
                  child: Row(
                    // Use Row for icon, text, and optional graphic
                    children: [
                      Icon(Icons.celebration_outlined, // Use outlined icon
                          color: colorScheme.onPrimaryContainer,
                          size: 36, // Slightly larger icon // (修正) サイズ調整
                          ),
                      // (修正) const を追加
                      const SizedBox(width: 16),
                      Expanded(
                        // Allow text to take available space
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize:
                              MainAxisSize.min, // Fit content vertically
                          children: [
                            Text(AppStrings.goldenTimeTitle,
                                style: textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold)),
                            // (修正) const を追加
                            const SizedBox(height: 2), // Small space
                            Text(
                              AppStrings.goldenTimeBody,
                              style: textTheme.bodySmall
                                  ?.copyWith(color: colorScheme.onPrimaryContainer),
                              maxLines: 2, // Limit lines if needed
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Optional: Add graphic representation [精子] -> [時計] -> [卵子]
                      // This could be a simple Row of Icons or a custom widget
                      // Example with Icons:
                      // (修正) グラフィックを追加 (任意)
                      const SizedBox(width: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // TODO: Replace with more appropriate icons if available
                          Icon(Icons.adjust,
                              color: colorScheme.onPrimaryContainer.withAlpha(200),
                              size: 20), // Placeholder for Sperm
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Icon(Icons.arrow_forward_ios_rounded,
                                color: colorScheme.onPrimaryContainer
                                    .withAlpha(180),
                                size: 16),
                          ),
                          Icon(Icons.hourglass_bottom_rounded,
                              color: colorScheme.onPrimaryContainer.withAlpha(200),
                              size: 20), // Placeholder for Capacitation Time
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Icon(Icons.arrow_forward_ios_rounded,
                                color: colorScheme.onPrimaryContainer
                                    .withAlpha(180),
                                size: 16),
                          ),
                          Icon(Icons.trip_origin,
                              color: colorScheme.onPrimaryContainer.withAlpha(200),
                              size: 20), // Placeholder for Egg
                        ],
                      )
                    ],
                  ),
                ),
              ),
              // *** Card の中身ここまで ***
            ),
          ),

          // V1.1 (3.1.4) P3 過去周期の確認 (PageView)
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: cycleCount > 0 ? cycleCount : 1, // データがなくても1ページ表示
              onPageChanged: (index) {
                logger.d("PageView onPageChanged: index=$index"); // Log page change
                // P3 状態管理 (index)
                // Check if index is different before updating to avoid redundant updates
                if (ref.read(currentCycleIndexProvider) != index) {
                  ref
                      .read(currentCycleIndexProvider.notifier)
                      .setPageIndex(index);
                }
              },
              itemBuilder: (context, index) {
                logger.d(
                    "PageView itemBuilder: Building page for index $index"); // Log item build
                // V1 (フロー 5) ページ切り替え
                // (修正) index から cycleId を取得して渡す
                // (修正) cycleList を使用
                final String? expectedId = (index >= 0 &&
                        index < cycleList.length)
                    ? cycleList[index].id
                    : null;
                logger.d(
                    "Expecting cycle ID for index $index: $expectedId");
                return _buildCyclePage(context, index,
                    currentCycleIndex == index, expectedId, cycleList); // Pass expected ID and cycleList
              },
            ),
          ),
        ],
      ),

      // V1.1 (3.1.3) P2 入力起点 (BottomAppBar + FAB)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Showcase(
        // コーチマークの対象ウィジェットを Showcase でラップ
        key: _fabKey, // GlobalKey を設定
        description: AppStrings.emptyStateCoachMark, // V1 (3.1) コーチマーク文言
        child: FloatingActionButton(
          onPressed: () {
            logger.d("FAB (+) pressed."); // Log FAB press
            _showRecordModal(context, ref);
          },
          tooltip: AppStrings.fabTooltip,
          // (修正) const を追加
          child: const Icon(Icons.add),
        ),
      ),
      // (修正) タイミング記録ボタン (♡) を BottomAppBar 内に移動し Visibility で制御
      // (修正) const を追加
      bottomNavigationBar: BottomAppBar(
        // <<< ★ エラー修正: bottomAppBar -> bottomNavigationBar
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start, // Align to start
          children: <Widget>[
            // *** P2: ♡ボタンを Visibility でラップ ***
            // (修正) Visibility を追加
            Visibility(
              visible: isGoldenTime, // GOLDEN TIME 中のみ表示
              // 場所を確保しない (visible: false のときにスペースを詰める)
              maintainSize: false,
              maintainAnimation: true,
              maintainState: true,
              child: AnimatedOpacity(
                // フェードイン/アウトのアニメーション
                // (修正) const を追加
                duration: const Duration(milliseconds: 200),
                opacity: isGoldenTime ? 1.0 : 0.0,
                child: Padding(
                  // Add padding for spacing
                  // (修正) const を追加
                  padding:
                      const EdgeInsets.only(left: 16.0), // 左側に余白を追加
                  child: IconButton(
                    icon: Icon(Icons.favorite,
                        color: colorScheme.tertiary, size: 28), // アイコンサイズ調整
                    tooltip: AppStrings.timingButtonTooltip,
                    onPressed: () {
                      logger.d(
                          "Timing button (♡) pressed."); // Log button press
                      _showTimingRecordModal(context, ref);
                    },
                  ),
                ),
              ),
            ),
            // *** Visibility ラップここまで ***

            // Optionally add spacer or other icons if needed
            // const Spacer(),
            // IconButton(icon: Icon(Icons.settings), onPressed: () {}), // Example
          ],
        ),
      ),
    );
  }

  /// V1 (フロー 5) 周期ごとのグラフページ
  /// (修正) expectedId を受け取る
  /// (修正) cycleList を受け取る
  Widget _buildCyclePage(BuildContext context, int pageIndex, bool isActive,
      String? expectedId, List<models.CycleData> cycleList) {
    logger.d(
        "_buildCyclePage for index $pageIndex, isActive: $isActive. Watching currentCycleDataProvider.");
    // V1 (P1/P0)
    // (修正) currentCycleDataProvider を使用し、IDが一致するか確認
    final currentCycleDataAsync = ref.watch(currentCycleDataProvider);

    // Define padding based on active status for "peek" effect
    final horizontalPadding =
        isActive ? 8.0 : 16.0; // More padding when inactive

    // (修正) const を追加
    return Padding(
      // Add horizontal padding to create the "peek" effect
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
      // Use IgnorePointer to disable interaction with inactive pages
      child: IgnorePointer(
        ignoring: !isActive,
        // (修正) const を追加
        child: AnimatedOpacity(
          // Use AnimatedOpacity for smooth transition
          opacity: isActive ? 1.0 : 0.6, // Make inactive pages semi-transparent
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Card(
            elevation: isActive ? 2 : 0, // Slightly more elevation for active card
            // shape: RoundedRectangleBorder(
            //   borderRadius: BorderRadius.circular(20),
            //   side: isActive
            //       ? BorderSide.none
            //       : BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(100)),
            // ),
            // margin: EdgeInsets.zero, // Margin is handled by Padding above
            child: currentCycleDataAsync.when(
                data: (cycleData) {
                  // Add check for expected ID to prevent showing wrong data during transition
                  if (cycleData == null || cycleData.id != expectedId) {
                    logger.d(
                        "_buildCyclePage (data): pageIndex=$pageIndex, expectedId=$expectedId, receivedId=${cycleData?.id}. Data is null or ID mismatch, showing empty or loading.");
                    // Show a simple loading or empty state during mismatch
                    // (修正) cycleList を使用
                    if (cycleList
                        .isEmpty) { // Show initial empty state if no cycles exist at all
                      // (修正) const を追加
                      return const _EmptyState(
                        title: AppStrings
                            .emptyStateTitleB, // Or specific title for no data
                        body: AppStrings.emptyStateBodyB,
                      );
                    }
                    // Show loading during page transitions if IDs mismatch
                    // (修正) const を追加
                    return const Center(
                        child:
                            CircularProgressIndicator.adaptive(strokeWidth: 2));
                  }

                  logger.d(
                      "_buildCyclePage (data): pageIndex=$pageIndex, ID matched (${cycleData.id}). Records: ${cycleData.records?.length ?? 0}");

                  // Handle case where cycle exists but has no records yet (common after onboarding)
                  if (cycleData.records == null ||
                      cycleData.records!.isEmpty) {
                    logger.d(
                        "Showing empty state for cycle ${cycleData.id} (no records).");
                    // Show empty state specific to having a cycle but no records
                    // (修正) const を追加
                    return const _EmptyState(
                      title: AppStrings
                          .emptyStateTitleA, // "あなたの「安心グラフ」です"
                      body:
                          AppStrings.emptyStateBodyA, // "まずは..."
                    );
                  }
                  // If data and ID match, build the chart
                  return _buildChart(context, cycleData);
                },
                loading: () {
                  logger.d("_buildCyclePage (loading): pageIndex=$pageIndex");
                  // (修正) const を追加
                  return const Center(
                      child: CircularProgressIndicator.adaptive());
                },
                error: (e, stackTrace) {
                  logger.e("_buildCyclePage (error): pageIndex=$pageIndex",
                      error: e, stackTrace: stackTrace);
                  return Center(child: Text('Error: $e')); // UI上にもエラー表示
                }),
          ),
        ),
      ),
    );
  }

  /// V1.1 (3.1.1) 統合グラフ (P1/P0)
  Widget _buildChart(BuildContext context, models.CycleData cycleData) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Sort records by date here to ensure correct order for rendering
    final records = (cycleData.records?.toList() ?? [])
      ..sort((a, b) => a.date.compareTo(b.date));
    logger.d(
        "Building chart for cycle ${cycleData.id} with ${records.length} sorted records.");

    // グラフのX軸（日付）の範囲を計算
    final startDate = cycleData.startDate;
    // Ensure averageCycleLength is positive
    final cycleLengthForCalc =
        cycleData.averageCycleLength > 0 ? cycleData.averageCycleLength : 28; // Default to 28 if invalid
    final endDate = startDate
        // (修正) const を追加
        .add(Duration(days: cycleLengthForCalc + 7)); // 予測 + 猶予

    // P1: 予測グラフ用のデータを生成 (引数にソート済み records を渡す)
    final predictedLh =
        _predictionLogic.predictFutureLh(cycleData, records, endDate);
    final predictedBbt =
        _predictionLogic.predictFutureBbt(cycleData, records, endDate);
    logger.d(
        "Generated ${predictedLh.length} LH predictions, ${predictedBbt.length} BBT predictions.");

    // 結合されたデータソースを作成
    // Combine *sorted* records with predictions
    final combinedLhData = [...records, ...predictedLh];
    final combinedBbtData = [...records, ...predictedBbt];

    // 最後の記録日を取得 (予測スタイルの切り替え用)
    // (修正) const を追加
    final lastRecordDate = records.isNotEmpty
        ? records.last.date
        // (修正) const を追加
        : startDate.subtract(const Duration(days: 1));
    logger.d("Last record date: $lastRecordDate");

    // 精子の待機ゾーン (実績と予測) を取得
    final Map<String, List<ChartData>> spermZones =
        _predictionLogic.getSpermStandbyZones(cycleData, records); // Pass sorted records
    final List<ChartData> actualSpermZones = spermZones['actual']!;
    final List<ChartData> predictedSpermZones = spermZones['predicted']!;
    logger.d(
        "Actual sperm zones: ${actualSpermZones.length} points, Predicted: ${predictedSpermZones.length} points.");

    // 排卵ゾーン情報
    final Map<String, dynamic> ovulationZoneInfo =
        _predictionLogic.getOvulationZones(cycleData, records); // Pass sorted records
    final List<ChartData> ovulationZones =
        ovulationZoneInfo['zones'] as List<ChartData>;
    final bool isOvulationConfirmed =
        ovulationZoneInfo['isConfirmed'] as bool;
    logger.d(
        "Ovulation zones: ${ovulationZones.length} points, Confirmed: $isOvulationConfirmed");

    // *** P1: ハイライト対象の日付を Watch ***
    final highlightedDate = ref.watch(highlightedDateProvider);
    logger.d("Building chart, highlighted date: $highlightedDate");

    // (修正) const を追加
    return Padding(
      padding: const EdgeInsets.only(
          top: 24, right: 16, bottom: 12, left: 8), // Added left padding
      child: SfCartesianChart(
        // *** P1: アニメーション有効化 ***
        // (修正) animationDuration は SfCartesianChart には不要。Series 側で設定
        enableAxisAnimation: true, // 軸もアニメーション
        // *** アニメーションここまで ***
        // (修正) const を追加
        legend: const Legend(isVisible: false),
        tooltipBehavior: _tooltipBehavior,
        primaryXAxis: DateTimeAxis(
          minimum: startDate,
          maximum: endDate,
          intervalType: DateTimeIntervalType.days,
          interval: 7, // Adjust interval based on screen size?
          dateFormat: DateFormat.Md('ja'), // Short format
          // (修正) const を追加
          majorGridLines: const MajorGridLines(width: 0.5), // Subtle grid lines
          // (修正) const を追加
          axisLine: const AxisLine(width: 0),
          // (修正) const を追加
          majorTickLines: const MajorTickLines(size: 0), // Hide ticks
          labelStyle: theme.textTheme.labelSmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        // LH Y-Axis (Left)
        primaryYAxis: NumericAxis(
          title: AxisTitle(
              text: 'LH',
              textStyle: theme.textTheme.labelSmall
                  ?.copyWith(color: colorScheme.primary)),
          minimum: 0,
          maximum: 4, // Max value based on TestResult enum + 1
          interval: 1,
          // (修正) const を追加
          axisLine: const AxisLine(width: 0),
          // (修正) const を追加
          majorTickLines: const MajorTickLines(size: 0),
          // (修正) const を追加
          majorGridLines:
              const MajorGridLines(width: 0.5), // Subtle grid lines matching X-axis
          labelFormat: '{value}', // Show integer values
          axisLabelFormatter: (AxisLabelRenderDetails details) {
            // Custom labels for LH levels if desired
            // *** 修正: label が初期化されていないエラーを修正 ***
            String label = ''; // 初期値を設定
            int value = details.value.toInt();
            if (value >= 0 && value < models.TestResult.values.length) {
              switch (models.TestResult.values[value]) {
                case models.TestResult.none:
                  label = '';
                  break; // Or '-'
                case models.TestResult.negative:
                  label = '陰性';
                  break;
                case models.TestResult.positive:
                  label = '陽性';
                  break;
                case models.TestResult.strongPositive:
                  label = '強陽';
                  break;
                // (修正) default case を削除
              }
            } else {
              label = '';
            }
            return ChartAxisLabel(label, details.textStyle);
          },
          labelStyle: theme.textTheme.labelSmall
              ?.copyWith(color: colorScheme.primary),
        ),
        // BBT Y-Axis (Right)
        axes: <ChartAxis>[
          NumericAxis(
            name: 'bbtAxis',
            opposedPosition: true,
            title: AxisTitle(
                text: 'BBT (℃)',
                textStyle: theme.textTheme.labelSmall
                    ?.copyWith(color: colorScheme.secondary)),
            minimum: 35.5, // Adjust range if needed
            maximum: 37.5, // Adjust range if needed
            interval: 0.5,
            decimalPlaces: 1, // Show one decimal place
            // (修正) const を追加
            axisLine: const AxisLine(width: 0),
            // (修正) const を追加
            majorTickLines: const MajorTickLines(size: 0),
            // (修正) const を追加
            majorGridLines:
                const MajorGridLines(width: 0), // Hide grid lines for this axis
            labelStyle: theme.textTheme.labelSmall
                ?.copyWith(color: colorScheme.secondary),
          )
        ],
        series: <CartesianSeries>[
          // Draw zones first (background)
          _buildActualSpermStandbySeries(actualSpermZones, colorScheme),
          _buildPredictedSpermStandbySeries(predictedSpermZones, colorScheme),
          _buildOvulationZoneSeries(ovulationZones, isOvulationConfirmed,
              colorScheme), // Pass calculated zones and flag
          // Draw lines/bars next
          // *** P1: highlightedDate を渡す ***
          _buildLhSeries(
              combinedLhData, lastRecordDate, colorScheme, highlightedDate),
          _buildBbtSeries(
              combinedBbtData, lastRecordDate, colorScheme, highlightedDate),
          // Draw markers last (foreground)
          _buildTimingMarkers(records, colorScheme), // Pass sorted records
        ],
      ),
    );
  }

  /// P1/P2: LHレベル (棒グラフ) - 確定と予測を1つのシリーズで描画
  /// (修正) pointColorMapper を使用して予測を半透明にする
  ColumnSeries<models.CycleRecord, DateTime> _buildLhSeries(
      List<models.CycleRecord> dataSource,
      DateTime lastRecordDate,
      ColorScheme colorScheme,
      DateTime? highlightedDate) {
    // *** P1: highlightedDate を受け取る ***
    // Filter out 'none' results *before* passing to the series
    final lhData = dataSource
        .where((r) => r.testResult != models.TestResult.none)
        .toList();

    return ColumnSeries<models.CycleRecord, DateTime>(
      dataSource: lhData,
      animationDuration: 500, // *** P1: アニメーション追加 ***
      xValueMapper: (models.CycleRecord record, _) => record.date,
      // Map enum index to Y value (adjust if TestResult order changes)
      // none=0, negative=1, positive=2, strongPositive=3
      yValueMapper: (models.CycleRecord record, _) =>
          record.testResult.index.toDouble(),
      name: AppStrings.helpLegendLH,
      // Use primary color for base
      color: colorScheme.primary,
      width: 0.6, // Adjust bar width
      spacing: 0.2, // Adjust spacing between bars
      // Use pointColorMapper to differentiate predicted bars
      pointColorMapper: (models.CycleRecord record, _) {
        // *** P1: ハイライト判定 ***
        bool isHighlighted =
            highlightedDate != null && isSameDay(record.date, highlightedDate);
        if (isHighlighted) {
          logger.d("Highlighting LH bar for ${record.date}");
          return colorScheme.error; // ハイライト色 (例: エラー色)
        }
        // *** P1: ハイライト判定ここまで ***

        bool isPrediction = record.date.isAfter(lastRecordDate);
        // V1.2 (2.1) 予測は半透明 (Opacity 0.5), 確定は不透明 (Opacity 1.0)
        // (修正) withAlpha を使う
        return colorScheme.primary
            .withAlpha(isPrediction ? (255 * 0.3).round() : 255); // Less opaque for prediction
      },
      // (修正) const を追加
      borderRadius:
          const BorderRadius.all(Radius.circular(4)), // Rounded corners for bars
    );
  }

  /// P1/P2: 基礎体温 (折れ線グラフ) - 確定と予測を1つのシリーズで描画
  /// (修正) pointColorMapper を使用して予測マーカーを半透明にする
  SplineSeries<models.CycleRecord, DateTime> _buildBbtSeries(
      List<models.CycleRecord> dataSource,
      DateTime lastRecordDate,
      ColorScheme colorScheme,
      DateTime? highlightedDate) {
    // *** P1: highlightedDate を受け取る ***
    // Filter out null BBT values *before* passing to the series
    final bbtData = dataSource.where((r) => r.bbt != null).toList();

    return SplineSeries<models.CycleRecord, DateTime>(
      dataSource: bbtData,
      animationDuration: 500, // *** P1: アニメーション追加 ***
      xValueMapper: (models.CycleRecord record, _) => record.date,
      yValueMapper: (models.CycleRecord record, _) => record.bbt,
      name: AppStrings.helpLegendBBT,
      color: colorScheme.secondary, // Base color for the line
      width: 2.5, // Slightly thinner line
      // Use dashArray for the entire series if needed, but distinguishing points is often clearer
      // dashArray: <double>[5, 5], // Example dash array if needed globally
      // (修正) const を追加
      markerSettings: MarkerSettings(
        isVisible: true,
        // color: colorScheme.secondary, // Color will be set by pointColorMapper
        borderColor: colorScheme.surface, // Border color for visibility
        shape: DataMarkerType.circle,
        borderWidth: 1.5,
        height: 6, width: 6 // Slightly larger markers
        // *** P1: ハイライト判定 (マーカーサイズと枠線) ***
        // (注: SplineSeries の markerSettings は全ポイント共通のため、
        //   特定の点だけサイズを変えるのは pointColorMapper ほど単純ではない)
        // (※より高度な実装では SplineSeries を2つ (通常とハイライト) に分ける必要があるが、
        //   ここでは pointColorMapper で色を変えることで「ハイライト」とする)
      ),
      // Use pointColorMapper for marker color/opacity
      pointColorMapper: (models.CycleRecord record, _) {
        // *** P1: ハイライト判定 ***
        bool isHighlighted =
            highlightedDate != null && isSameDay(record.date, highlightedDate);
        if (isHighlighted) {
          logger.d("Highlighting BBT marker for ${record.date}");
          return colorScheme.error; // ハイライト色
        }
        // *** P1: ハイライト判定ここまで ***

        bool isPrediction = record.date.isAfter(lastRecordDate);
        // V1.2 (2.1) 予測マーカーは半透明 (Opacity 0.5), 確定マーカーは不透明 (Opacity 1.0)
        // (修正) withAlpha を使う
        return colorScheme.secondary
            .withAlpha(isPrediction ? (255 * 0.5).round() : 255);
      },
      yAxisName: 'bbtAxis',
      // Assign the custom renderer (No longer needed as we removed drawSegment)
      // onCreateRenderer: (ChartSeries<dynamic, dynamic> series) {
      //   return _CustomSplineSeriesRenderer(series as SplineSeries<models.CycleRecord, DateTime>, lastRecordDate);
      // },
    );
  }

  /// P2: タイミング (♡マーカー)
  /// (修正) Y値を調整して他のグラフと重ならないようにする
  ScatterSeries<models.CycleRecord, DateTime> _buildTimingMarkers(
      List<models.CycleRecord> records, ColorScheme colorScheme) {
    // Filter only records where timing occurred
    final timingRecords = records.where((r) => r.isTiming).toList();

    return ScatterSeries<models.CycleRecord, DateTime>(
      dataSource: timingRecords,
      animationDuration: 500, // *** P1: アニメーション追加 ***
      xValueMapper: (models.CycleRecord record, _) => record.date,
      // Adjust Y value to place markers clearly, e.g., slightly above x-axis
      // Consider placing it relative to the LH axis range (0-4)
      yValueMapper: (models.CycleRecord record, _) =>
          -0.5, // Position below the LH bars
      name: AppStrings.helpLegendTiming,
      color: colorScheme.tertiary, // Use tertiary color for distinction
      // (修正) const を追加
      markerSettings: const MarkerSettings(
        isVisible: true,
        height: 12, // Adjust size
        width: 12, // Adjust size
        // Use a standard icon shape if available, or keep pentagon
        // shape: DataMarkerType.icon, // Requires iconType
        // iconType: IconType.favorite,
        shape:
            DataMarkerType.circle, // Changed to Circle for potentially better rendering
        // Add border for better visibility?
        // borderColor: colorScheme.surface,
        // borderWidth: 1,
      ),
      // Associate with the primary Y axis (LH) for positioning
      yAxisName: null, // Default primary axis
    );
  }

  /// P1: 予測排卵ゾーン (赤帯) - BBT確定ロジック反映
  /// (修正) 引数と色決定ロジックを変更
  RangeAreaSeries<ChartData, DateTime> _buildOvulationZoneSeries(
      List<ChartData> zones, // Pass pre-calculated zones
      bool isConfirmed, // Pass confirmation flag
      ColorScheme colorScheme) {
    // V1.2 (2.1) 色決定ロジック
    final Color zoneColor = isConfirmed
        // Use error color (more prominent) when confirmed
        // (修正) withAlpha を使う
        ? colorScheme.error
            .withAlpha((255 * 0.3).round()) // Adjust opacity as needed
        // Use errorContainer color (less prominent) when predicted
        // (修正) withAlpha を使う
        : colorScheme.errorContainer
            .withAlpha((255 * 0.3).round()); // Adjust opacity

    // Add subtle border matching the fill color for better definition
    final Color borderColor = isConfirmed
        ? colorScheme.error.withAlpha(80)
        : colorScheme.errorContainer.withAlpha(80); // (修正) 境界線のアルファ値を調整

    return RangeAreaSeries<ChartData, DateTime>(
      dataSource: zones, // Use passed data
      animationDuration: 500, // *** P1: アニメーション追加 ***
      xValueMapper: (ChartData data, _) => data.x,
      lowValueMapper: (ChartData data, _) => -1, // Extend slightly below 0
      highValueMapper: (ChartData data, _) =>
          5, // Extend slightly above 4 (LH max)
      name: isConfirmed
          ? AppStrings.helpLegendOvulationConfirmed
          : AppStrings.helpLegendOvulation, // Dynamic name
      color: zoneColor,
      borderWidth: 1.0, // Add border
      borderColor: borderColor,
      // *** 修正: isConfirmed に基づいて dashArray を設定 ***
      dashArray: isConfirmed ? null : const <double>[4, 4], // 予測の場合は点線
    );
  }

  /// P1: 精子の待機バー (青バー) - 実績
  RangeAreaSeries<ChartData, DateTime> _buildActualSpermStandbySeries(
      List<ChartData> zones, ColorScheme colorScheme) {
    return RangeAreaSeries<ChartData, DateTime>(
      dataSource: zones,
      animationDuration: 500, // *** P1: アニメーション追加 ***
      xValueMapper: (ChartData data, _) => data.x,
      lowValueMapper: (ChartData data, _) => -1, // Match ovulation zone range
      highValueMapper: (ChartData data, _) => 5, // Match ovulation zone range
      name: AppStrings.helpLegendSperm,
      // V1.2 (2.1) 色指定
      // (修正) withAlpha を使う
      color: colorScheme.primary // Use primary color but with low opacity
          .withAlpha((255 * 0.15).round()), // Adjust opacity
      borderWidth: 1, // Add subtle border
      borderColor: colorScheme.primary.withAlpha(50),
    );
  }

  /// P1: 精子の待機バー (青バー) - 予測
  /// (修正) 色と dashArray をビジュアライゼーション要件に合わせる
  RangeAreaSeries<ChartData, DateTime> _buildPredictedSpermStandbySeries(
      List<ChartData> zones, ColorScheme colorScheme) {
    return RangeAreaSeries<ChartData, DateTime>(
      dataSource: zones,
      animationDuration: 500, // *** P1: アニメーション追加 ***
      xValueMapper: (ChartData data, _) => data.x,
      lowValueMapper: (ChartData data, _) => -1, // Match ovulation zone range
      highValueMapper: (ChartData data, _) => 5, // Match ovulation zone range
      name: AppStrings.helpLegendSpermPredicted,
      // V1.2 (2.1) 色指定 (tertiaryContainer)
      // (修正) withAlpha を使う
      color: colorScheme.tertiaryContainer
          .withAlpha((255 * 0.2).round()), // Adjust opacity
      borderWidth: 1,
      borderColor: colorScheme.tertiaryContainer.withAlpha(80),
      // V1.2 (2.1) dashArray for prediction
      dashArray: const <double>[4, 4], // Define dash pattern
    );
  }

  /// P2: 「＋」FAB (検査/体温) モーダル表示
  void _showRecordModal(BuildContext context, WidgetRef ref) {
    logger.d("Attempting to show record modal..."); // Log attempt
    // (修正) currentCycleDataProvider を使用
    final cycleDataAsync = ref.read(currentCycleDataProvider);
    // (修正) 未使用の変数を削除

    logger.d(
        "Current index: ${ref.read(currentCycleIndexProvider)}, Total cycles: ${ref.read(cycleDataProvider).length}"); // Log index and count

    // Check if cycleData itself is null or if the provider is still loading/error
    // Use pattern matching for clarity
    switch (cycleDataAsync) {
      case AsyncData(:final value):
        if (value != null) {
          logger.d(
              "Found cycle data for index ${ref.read(currentCycleIndexProvider)}: ID=${value.id}");
          final cycleId = value.id;
          logger.d("Showing RecordModal for cycle ID: $cycleId");

          // Proceed to show modal
          showModalBottomSheet(
            context: context,
            isScrollControlled: true, // Allows modal to resize with keyboard
            // Add barrier color for better visual separation
            barrierColor: Colors.black.withAlpha(100),
            // Use safe area to avoid system intrusions
            useSafeArea: true,
            builder: (modalContext) {
              // Use a different context name
              // Pass the specific CycleData for potential initial values?
              // Or rely on RecordModal loading via cycleId
              return RecordModal(
                cycleId: cycleId,
                // Pass initial date? Maybe today?
                initialDate: DateTime.now(), // Default to today for new records
                onSubmit: (record) {
                  logger.d(
                      "RecordModal onSubmit: date=${record.date}, bbt=${record.bbt}, test=${record.testResult}, timing=${record.isTiming}");
                  // Use async/await to handle potential errors from provider
                  Future(() async {
                    try {
                      await ref
                          .read(cycleDataProvider.notifier)
                          .addOrUpdateRecord(cycleId, record);
                      logger.d(
                          "addOrUpdateRecord successful for cycle $cycleId.");

                      // Check mounted status before showing SnackBar
                      if (!modalContext.mounted) return; // Use modalContext here

                      // Update Golden Time state *after* successful save
                      if (record.testResult == models.TestResult.positive ||
                          record.testResult ==
                              models.TestResult.strongPositive) {
                        logger.d("Setting goldenTimeProvider to true.");
                        ref.read(goldenTimeProvider.notifier).state = true;

                        // *** P1: ハイライトアニメーション (フロー3 B) - 明滅ロジック ***
                        final highlightedDate =
                            _normalizeDate(record.date); // Normalize once
                        logger.d(
                            "Starting highlight blink for date: $highlightedDate");

                        // マネージャーにハイライトの開始を通知
                        ref
                            .read(highlightAnimationProvider.notifier)
                            .startHighlight(highlightedDate);
                        // *** P1: ハイライトここまで ***

                        ScaffoldMessenger.of(modalContext).showSnackBar(
                          // (修正) const を追加
                          const SnackBar(
                            content: Text(AppStrings.feedbackGoldenTime),
                            // (修正) const を追加
                            duration: Duration(
                                seconds: 3), // Slightly longer duration
                          ),
                        );
                      } else {
                        // Optionally reset golden time if negative is recorded?
                        // ref.read(goldenTimeProvider.notifier).state = false;
                        ScaffoldMessenger.of(modalContext).showSnackBar(
                          // (修正) const を追加
                          const SnackBar(
                            content: Text(AppStrings.feedbackRecordSaved),
                          ),
                        );
                      }
                    } catch (e, stackTrace) {
                      logger.e("Error calling addOrUpdateRecord",
                          error: e, stackTrace: stackTrace);
                      // Show error SnackBar
                      if (modalContext.mounted) {
                        ScaffoldMessenger.of(modalContext).showSnackBar(
                          SnackBar(
                              content: Text('記録の保存に失敗しました: $e')),
                        );
                      }
                    }
                  });
                },
              );
            },
          );
        } else {
          // This case means AsyncData was received, but the value was null.
          // This *shouldn't* happen if the provider logic is correct (empty list handled).
          logger.e(
              "!!! Cycle data is null within AsyncData. Provider State: ${ref.read(cycleDataProvider)}");
          // (修正) const を追加
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('現在の周期データが見つかりません。(Error Code: AD)')),
          );
        }
        break; // Added break
      case AsyncLoading():
        logger.w("Attempted to show record modal while cycle data is loading.");
        // Optionally show a loading indicator or disable button
        // (修正) const を追加
        ScaffoldMessenger.of(context).showSnackBar(
          // (修正) const を追加
          const SnackBar(
              content: Text('データを読み込み中です...'),
              duration: Duration(seconds: 1)),
        );
        break; // Added break
      case AsyncError(:final error, :final stackTrace):
        logger.e(
            "Cannot show record modal due to error in cycle data provider.",
            error: error,
            stackTrace: stackTrace);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('周期データの読み込みエラー: $error')),
        );
        break; // Added break
      // (修正) default case を削除
    }
  }

  /// P2: 「♡」タイミング モーダル表示
  void _showTimingRecordModal(BuildContext context, WidgetRef ref) {
    logger.d("Attempting to show timing record modal..."); // Log attempt
    final cycleDataAsync = ref.read(currentCycleDataProvider); // Read async value
    // (修正) 未使用の変数を削除

    logger.d(
        "Current index: ${ref.read(currentCycleIndexProvider)}, Total cycles: ${ref.read(cycleDataProvider).length}"); // Log index and count

    // Use pattern matching for clarity
    switch (cycleDataAsync) {
      case AsyncData(:final value):
        if (value != null) {
          logger.d("Found cycle data for timing modal: ID=${value.id}");
          final cycleId = value.id;
          logger.d("Showing TimingRecordModal for cycle ID: $cycleId");

          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            barrierColor: Colors.black.withAlpha(100),
            useSafeArea: true,
            builder: (modalContext) {
              return TimingRecordModal(
                cycleId: cycleId,
                initialDate: DateTime.now(), // Default to today
                onSubmit: (date) {
                  logger.d("TimingRecordModal onSubmit: date=$date");
                  // Use async/await
                  Future(() async {
                    try {
                      await ref
                          .read(cycleDataProvider.notifier)
                          .addTimingRecord(cycleId, date);
                      logger.d(
                          "addTimingRecord successful for cycle $cycleId.");

                      if (!modalContext.mounted) return;
                      ScaffoldMessenger.of(modalContext).showSnackBar(
                        // (修正) const を追加
                        const SnackBar(
                          content: Text(AppStrings.feedbackRecordSaved),
                        ),
                      );
                    } catch (e, stackTrace) {
                      logger.e("Error calling addTimingRecord",
                          error: e, stackTrace: stackTrace);
                      if (modalContext.mounted) {
                        ScaffoldMessenger.of(modalContext).showSnackBar(
                          SnackBar(
                              content: Text('タイミング記録の保存に失敗しました: $e')),
                        );
                      }
                    }
                  });
                },
              );
            },
          );
        } else {
          logger.e(
              "!!! Cycle data is null within AsyncData for timing modal.");
          // (修正) const を追加
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('現在の周期データが見つかりません。(Error Code: T-AD)')),
          );
        }
        break; // Added break
      case AsyncLoading():
        logger
            .w("Attempted to show timing modal while cycle data is loading.");
        // (修正) const を追加
        ScaffoldMessenger.of(context).showSnackBar(
          // (修正) const を追加
          const SnackBar(
              content: Text('データを読み込み中です...'),
              duration: Duration(seconds: 1)),
        );
        break; // Added break
      case AsyncError(:final error, :final stackTrace):
        logger.e(
            "Cannot show timing modal due to error in cycle data provider.",
            error: error,
            stackTrace: stackTrace);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('周期データの読み込みエラー: $error')),
        );
        break; // Added break
      // (修正) default case を削除
    }
  }

  /// *** P3: カレンダー連携ロジック ***
  Future<void> _shareToCalendar() async {
    logger.d("Share to calendar requested...");
    final cycleDataAsync = ref.read(currentCycleDataProvider);

    models.CycleData? cycleData;
    if (cycleDataAsync is AsyncData<models.CycleData?>) {
      cycleData = cycleDataAsync.value;
    }

    if (cycleData == null) {
      logger.w("No cycle data available to share.");
      Fluttertoast.showToast(msg: AppStrings.feedbackCalendarError);
      return;
    }

    // グラフ構築に使用するのと同じソート済みレコードを取得
    final records = (cycleData.records?.toList() ?? [])
      ..sort((a, b) => a.date.compareTo(b.date));

    // 排卵ゾーン情報を取得
    final Map<String, dynamic> ovulationZoneInfo =
        _predictionLogic.getOvulationZones(cycleData, records);
    final List<ChartData> ovulationZones =
        ovulationZoneInfo['zones'] as List<ChartData>;

    if (ovulationZones.isEmpty) {
      logger.w("No ovulation zones found to share for cycle ${cycleData.id}.");
      Fluttertoast.showToast(msg: AppStrings.feedbackCalendarNoZone);
      return;
    }

    // ゾーンの開始時刻と終了時刻を抽出
    // getOvulationZones は [start(0), start(1), end(1), end(0)] の順で返す想定
    final DateTime startDate = ovulationZones[0].x;
    final DateTime endDate = ovulationZones[2].x;

    logger.d(
        "Creating calendar event: ${AppStrings.shareCalendarEventTitle} from $startDate to $endDate");

    // add_2_calendar の Event オブジェクトを作成
    final Event event = Event(
      title: AppStrings.shareCalendarEventTitle,
      description: AppStrings.shareCalendarEventDesc,
      location: 'Capaci App', // (任意)
      startDate: startDate,
      endDate: endDate,
      allDay: false, // 時間指定のイベントとして登録
      // (任意) iOS用のURLスキーム (カレンダーアプリに戻るため)
      // iosParams: const IOSParams(
      //   reminder: Duration(minutes: 30), // 30分前にリマインダー
      //   url: 'capaci://', // (アプリのURLスキームを設定した場合)
      // ),
      // (任意) Android用の設定
      // androidParams: const AndroidParams(
      //   emailInvites: [], // パートナーのメールアドレス (UIから入力させる必要がある)
      // ),
    );

    // カレンダー追加のダイアログを表示
    try {
      final success = await Add2Calendar.addEvent2Cal(event);
      if (success == true) { // addEvent2Cal は bool? を返す可能性がある
        logger.i("Successfully added event to calendar.");
        Fluttertoast.showToast(msg: AppStrings.feedbackCalendarSuccess);
      } else {
        logger.w("Failed to add event to calendar (user cancelled or error).");
        // (任意) ユーザーキャンセルの場合はトースト不要かもしれない
        // Fluttertoast.showToast(msg: AppStrings.feedbackCalendarError);
      }
    } catch (e, stackTrace) {
      logger.e("Error adding event to calendar",
          error: e, stackTrace: stackTrace);
      Fluttertoast.showToast(
          msg: "${AppStrings.feedbackCalendarError}: $e");
    }
  }

  /// V1.1 (3.1.1) / V1.2 (2.5) / V1 (3.3) ヘルプモーダル
  void _buildHelpModal(
      BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    showModalBottomSheet(
      context: context,
      // isScrollControlled: true, // Only needed if content might exceed height
      // (修正) const を追加
      shape: const RoundedRectangleBorder(
        // Consistent M3 shape
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        // Use SingleChildScrollView if content might overflow
        return SingleChildScrollView(
          // (修正) const を追加
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 24.0), // Adjust top padding
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // M3 Drag Handle
                Center(
                  // (修正) const を追加
                  child: Container(
                    width: 32,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withAlpha(100),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // const SizedBox(height: 16), // Replaced by drag handle margin
                Text(
                  AppStrings.helpModalTitle,
                  style: textTheme.titleLarge,
                ),
                // (修正) const を追加
                const SizedBox(height: 16), // Space before legends
                _buildLegendItem(
                  colorScheme.primary.withAlpha(120), // Semi-transparent bar color
                  AppStrings.helpLegendLH,
                  AppStrings.helpLegendLHDesc,
                  context,
                  isBar: true, // Indicate it's for the bar chart
                ),
                _buildLegendItem(
                  colorScheme.secondary, // Solid line color
                  AppStrings.helpLegendBBT,
                  AppStrings.helpLegendBBTDesc,
                  context,
                  isLine: true, // Indicate it's for the line chart
                ),
                // Legend for Predicted BBT (use semi-transparent color)
                _buildLegendItem(
                  colorScheme.secondary.withAlpha(128), // Semi-transparent line color
                  '${AppStrings.helpLegendBBT} (予測)',
                  '予測される基礎体温', // Simple description
                  context,
                  isLine: true,
                  isDashed: true, // Indicate dashed line style
                ),
                _buildLegendItem(
                  colorScheme.errorContainer
                      .withAlpha(77), // Prediction color Opacity(0.3)
                  AppStrings.helpLegendOvulation, // Predicted state
                  AppStrings.helpLegendOvulationDesc,
                  context,
                  isArea: true, // Indicate it's for the area
                ),
                // BBT確定時の凡例を追加
                _buildLegendItem(
                  colorScheme.error
                      .withAlpha(77), // Confirmed color Opacity(0.3)
                  AppStrings.helpLegendOvulationConfirmed,
                  AppStrings.helpLegendOvulationConfirmedDesc,
                  context,
                  isArea: true, // Indicate it's for the area
                ),
                _buildLegendItem(
                  colorScheme.primary
                      .withAlpha(38), // Actual Sperm Bar Opacity(0.15)
                  AppStrings.helpLegendSperm,
                  AppStrings.helpLegendSpermDesc,
                  context,
                  isArea: true, // Indicate it's for the area
                ),
                // (TODO 4: 予測バーの凡例を追加)
                _buildLegendItem(
                  colorScheme.tertiaryContainer
                      .withAlpha(51), // Predicted Sperm Bar Opacity(0.2)
                  AppStrings.helpLegendSpermPredicted,
                  AppStrings.helpLegendSpermPredictedDesc,
                  context,
                  isArea: true, // Indicate it's for the area
                  isDashed: true, // Indicate dashed border/fill pattern if applicable
                ),
                _buildLegendItem(
                  colorScheme.tertiary, // Timing marker color
                  AppStrings.helpLegendTiming,
                  AppStrings.helpLegendTimingDesc,
                  context,
                  isMarker: true, // Indicate it's a marker
                ),
                // (修正) const を追加
                const SizedBox(height: 16),
                Divider(color: colorScheme.outlineVariant),
                // (修正) const を追加
                const SizedBox(height: 16),
                Text(
                  AppStrings.helpModalConclusion,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                // (修正) const を追加
                const SizedBox(height: 8), // Add padding at the bottom
              ],
            ),
          ),
        );
      },
    );
  }

  /// V1.2 (2.5) ヘルプモーダル (凡例) の共通ウィジェット
  /// (修正) isBar, isLine, isArea, isMarker, isDashed フラグを追加してアイコンを動的に変更
  Widget _buildLegendItem(
      Color color, String title, String subtitle, BuildContext context,
      {bool isBar = false,
      bool isLine = false,
      bool isArea = false,
      bool isMarker = false,
      bool isDashed = false}) {
    Widget leadingWidget;
    const double iconSize = 24.0;

    if (isArea) {
      leadingWidget = Container(
        width: iconSize,
        height: iconSize,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: isDashed
              ? Border.all(
                  color: color.withAlpha(150),
                  width: 1,
                  style: BorderStyle.solid)
              : null, // Add border for dashed look if needed
        ),
        // Optional: Add pattern for dashed area representation
        // child: isDashed ? CustomPaint(painter: DashedRectPainter(color.withAlpha(150))) : null,
      );
    } else if (isLine) {
      leadingWidget = SizedBox(
        width: iconSize,
        height: iconSize,
        child: CustomPaint(
          // *** 修正: 'invalid_constant' エラーを修正するため const を削除 ***
          painter: LinePainter(color: color, isDashed: isDashed),
          child: isDashed
              ? null
              : Center(
                  // Show marker only for solid line if needed
                  child: Icon(Icons.circle, color: color, size: 8),
                ),
        ),
      );
    } else if (isBar) {
      leadingWidget = Container(
        width: iconSize * 0.6, // Narrower for bar
        height: iconSize,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    } else if (isMarker) {
      leadingWidget =
          Icon(Icons.favorite, color: color, size: iconSize); // Use favorite icon for timing
    } else {
      // Default square
      leadingWidget = Container(
        width: iconSize,
        height: iconSize,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: leadingWidget,
      title: Text(title,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
          // ?.copyWith(fontWeight: FontWeight.bold) // Removed bold for cleaner look
          ),
      subtitle: Text(subtitle,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      minLeadingWidth: iconSize + 8, // Ensure enough space for the leading widget
    );
  }
}

/// V1 (3.1) Empty State
class _EmptyState extends StatelessWidget {
  final String title;
  final String body;
  // (修正) const constructor
  const _EmptyState({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // (修正) const を追加
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insights_rounded,
                size: 48,
                color: theme.colorScheme.primary.withAlpha(150)), // Softer color
            // (修正) const を追加
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            // (修正) const を追加
            const SizedBox(height: 8),
            Text(
              body,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// *** P1: ハイライトアニメーション用にヘルパー関数を追加 ***

/// 時刻情報を除去した DateTime を返すヘルパー
DateTime _normalizeDate(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

/// 2つの DateTime が同じ日付か (時刻を無視して) 判定するヘルパー
bool isSameDay(DateTime date1, DateTime date2) {
  return date1.year == date2.year &&
      date1.month == date2.month &&
      date1.day == date2.day;
}
// *** P1: ヘルパー関数ここまで ***

// --- Custom Painters for Legend ---

class LinePainter extends CustomPainter {
  final Color color;
  final bool isDashed;

  // (修正) const constructor
  const LinePainter({required this.color, this.isDashed = false});

  @override
  void paint(Canvas canvas, Size size) {
    // *** 修正: 描画サイズが 0 以下の場合は何もしない ***
    if (size.width <= 0 || size.height <= 0) {
      logger.w(
          "LinePainter: Skipping paint because size is zero or negative ($size)");
      return;
    }
    // *** 修正ここまで ***

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0 // Match line width
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height / 2);
    path.lineTo(size.width, size.height / 2);

    if (isDashed) {
      // Create dashed path
      final dashPath = Path();
      const double dashWidth = 4.0;
      const double dashSpace = 4.0;
      double distance = 0.0;
      // (修正) computeMetrics() が空でないことを確認
      final metrics = path.computeMetrics();
      // *** 修正: metrics が空でないことを確認 ***
      if (metrics.isNotEmpty) {
        final metric = metrics.first;
        while (distance < metric.length) {
          // Use metric.length
          dashPath.addPath(
              metric.extractPath(distance, distance + dashWidth), Offset.zero);
          distance += dashWidth + dashSpace;
        }
        canvas.drawPath(dashPath, paint);
      } else {
        logger.w("LinePainter: Could not compute metrics for dashing.");
        // Fallback to solid line?
        // canvas.drawPath(path, paint);
      }
    } else {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Optional: Painter for dashed area representation if needed
class DashedRectPainter extends CustomPainter {
  final Color color;
  // (修正) const constructor
  const DashedRectPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw diagonal dashed lines (example)
    const double step = 4.0;
    for (double i = -size.height; i < size.width; i += step * 2) {
      canvas.drawLine(
          Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ChartData は prediction_logic.dart から export される

