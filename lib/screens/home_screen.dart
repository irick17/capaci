// (エラー修正: import パス修正)
import '../components/timing_record_modal.dart';
// (エラー修正: ChartData を import)
import '../utils/prediction_logic.dart';
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
// (エラー修正: hide 不要)
import '../providers/cycle_state_provider.dart';
// コーチマーク用に追加
import '../providers/settings_provider.dart';
// logger を import
import '../utils/logger.dart';
// カレンダー画面 import (★ エラー: calendar_screen.dart はまだ存在しないためコメントアウト)
// import 'calendar_screen.dart';


/// 画面遷移図 (GA-01): ホーム (統合グラフ) 画面
/// V1.1 (3.1) / V1.2 (2.1)
/// アプリの唯一の主要画面。P1/P0（グラフ）と P2（入力）の起点。
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final PageController _pageController = PageController(
    viewportFraction: 0.9, // V1.1 (3.1.4) P3 見切れ
  );
  late TooltipBehavior _tooltipBehavior;
  late PredictionLogic _predictionLogic;

  // コーチマーク用の GlobalKey を定義
  final GlobalKey _fabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tooltipBehavior = TooltipBehavior(enable: true);
    _predictionLogic = PredictionLogic();

    // V1 (初回ホーム コーチマーク)
    // 画面ビルド後にコーチマークを開始する
    WidgetsBinding.instance.addPostFrameCallback((_) => _showCoachMark());
  }

   @override
  void dispose() {
    _pageController.dispose(); // PageControllerをdispose
    super.dispose();
  }

  /// V1 (初回ホーム コーチマーク) 表示ロジック
  void _showCoachMark() {
    try { // コーチマーク表示も try-catch
      final isOnboardingComplete = ref.read(onboardingProvider);
      final isCoachMarkShown = ref.read(coachMarkShownProvider);

      if (isOnboardingComplete && !isCoachMarkShown && mounted) {
        final showCaseContext = ShowCaseWidget.of(context);
        showCaseContext.startShowCase([_fabKey]);
        ref.read(coachMarkShownProvider.notifier).markAsShown();
      }
    } catch (e, stackTrace) {
        logger.e("Error showing coach mark", error: e, stackTrace: stackTrace);
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // V1 (P1) GOLDEN TIME 状態を監視
    final isGoldenTime = ref.watch(goldenTimeProvider);

    // V1 (P3) 周期データの総数を監視 (PageView の itemCount)
    final cycleCount = ref.watch(cycleDataProvider).length;
    final currentCycleIndex = ref.watch(currentCycleIndexProvider);

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
          // V1 (P3) 将来的なカレンダー機能
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () {
              // (★ エラー: CalendarScreen はまだ存在しないためコメントアウト)
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(builder: (context) => const CalendarScreen()),
              // );
               logger.i("Calendar button pressed (Not implemented yet)"); // 代わりにログ出力
            },
            // (任意) GOLDEN TIME時の色変更
            color: isGoldenTime ? colorScheme.onPrimaryContainer : null,
          ),
          // V1.1 (3.1.1) / V1.2 (2.5) ヘルプ機能 (P1/P3)
          IconButton(
            // (任意) GOLDEN TIME時の色変更
            icon: Icon(Icons.help_outline, color: isGoldenTime ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant),
            tooltip: AppStrings.helpModalTitle,
            onPressed: () => _buildHelpModal(context, colorScheme, textTheme),
          ),
        ],
      ),
      body: Column(
        children: [
          // V1 (P1) 3.1.2 GOLDEN TIME 状態表示
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: isGoldenTime ? 80 : 0,
            child: Visibility(
              visible: isGoldenTime,
              child: Card(
                // V1.2 (2.2)
                elevation: 1,
                color: colorScheme.primaryContainer,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Center(
                  // V1.2 (2.2) / V1 (3.2)
                  child: ListTile(
                    leading: Icon(Icons.celebration,
                        color: colorScheme.onPrimaryContainer),
                    title: Text(AppStrings.goldenTimeTitle,
                        style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold)),
                    subtitle: Text(AppStrings.goldenTimeBody,
                        style: textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onPrimaryContainer)),
                  ),
                ),
              ),
            ),
          ),

          // V1.1 (3.1.4) P3 過去周期の確認 (PageView)
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: cycleCount > 0 ? cycleCount : 1, // データがなくても1ページ表示
              onPageChanged: (index) {
                // P3 状態管理 (index)
                ref
                    .read(currentCycleIndexProvider.notifier)
                    .setPageIndex(index);
              },
              itemBuilder: (context, index) {
                // V1 (フロー 5) ページ切り替え
                return _buildCyclePage(
                    context, index, currentCycleIndex == index);
              },
            ),
          ),
        ],
      ),

      // V1.1 (3.1.3) P2 入力起点 (BottomAppBar + FAB)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Showcase( // コーチマークの対象ウィジェットを Showcase でラップ
        key: _fabKey, // GlobalKey を設定
        description: AppStrings.emptyStateCoachMark, // V1 (3.1) コーチマーク文言
        child: FloatingActionButton(
          onPressed: () => _showRecordModal(context, ref),
          tooltip: AppStrings.fabTooltip,
          child: const Icon(Icons.add),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            IconButton(
              icon: Icon(Icons.favorite, color: colorScheme.tertiary),
              tooltip: AppStrings.timingButtonTooltip,
              onPressed: () => _showTimingRecordModal(context, ref),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  /// V1 (フロー 5) 周期ごとのグラフページ
  Widget _buildCyclePage(BuildContext context, int pageIndex, bool isActive) {
    // V1 (P1/P0)
    final cycleDataAsync = ref.watch(currentCycleDataProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      transform: Matrix4.translationValues(0, isActive ? 0 : 20, 0),
      child: Opacity(
        opacity: isActive ? 1.0 : 0.5,
        child: Card(
          elevation: isActive ? 1 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: isActive
                ? BorderSide.none
                : BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: cycleDataAsync.when(
            data: (cycleData) {
              if (cycleData == null || (cycleData.records?.isEmpty ?? true)) {
                 return _EmptyState(
                   title: AppStrings.emptyStateTitleB,
                   body: AppStrings.emptyStateBodyB,
                 );
              }
              return _buildChart(context, cycleData);
            },
            loading: () =>
                const Center(child: CircularProgressIndicator.adaptive()),
            error: (e, stackTrace) {
              logger.e("Error loading cycle data in page view", error: e, stackTrace: stackTrace);
              return Center(child: Text('Error: $e')); // UI上にもエラー表示
            }
          ),
        ),
      ),
    );
  }

  /// V1.1 (3.1.1) 統合グラフ (P1/P0)
  Widget _buildChart(BuildContext context, models.CycleData cycleData) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final records = cycleData.records?.toList() ?? [];

    // グラフのX軸（日付）の範囲を計算
    final startDate = cycleData.startDate;
    // (★ エラー箇所修正: averageCycleLength -> averageLength)
    final endDate = startDate
        .add(Duration(days: (cycleData.averageCycleLength) + 7)); // 予測 + 猶予

    // P1: 予測グラフ用のデータを生成
    final predictedLh =
        _predictionLogic.predictFutureLh(cycleData, records, endDate);
    final predictedBbt =
        _predictionLogic.predictFutureBbt(cycleData, records, endDate);

    // 結合されたデータソースを作成
    final combinedLhData = [...records, ...predictedLh];
    final combinedBbtData = [...records, ...predictedBbt];
    // 最後の記録日を取得 (予測スタイルの切り替え用)
    final lastRecordDate = records.isNotEmpty ? records.last.date : startDate.subtract(const Duration(days: 1));
    
    final Map<String, List<ChartData>> spermZones =
        _predictionLogic.getSpermStandbyZones(cycleData, records);
    final List<ChartData> actualSpermZones = spermZones['actual']!;
    final List<ChartData> predictedSpermZones = spermZones['predicted']!;


    return Padding(
      padding: const EdgeInsets.only(top: 24, right: 16, bottom: 12),
      child: SfCartesianChart(
        legend: const Legend(isVisible: false),
        tooltipBehavior: _tooltipBehavior,
        primaryXAxis: DateTimeAxis(
          minimum: startDate,
          maximum: endDate,
          intervalType: DateTimeIntervalType.days,
          interval: 7,
          dateFormat: DateFormat.Md('ja_JP'),
          majorGridLines: const MajorGridLines(width: 0),
        ),
        primaryYAxis: NumericAxis(
          title: AxisTitle(
              text: 'LH',
              textStyle: TextStyle(color: colorScheme.primary)),
          minimum: 0,
          maximum: 4,
          interval: 1,
          axisLine: const AxisLine(width: 0),
          majorTickLines: const MajorTickLines(size: 0),
        ),
        axes: <ChartAxis>[
          NumericAxis(
            name: 'bbtAxis',
            opposedPosition: true,
            title: AxisTitle(
                text: 'BBT (℃)',
                textStyle: TextStyle(color: colorScheme.secondary)),
            minimum: 35.5,
            maximum: 37.5,
            interval: 0.5,
            axisLine: const AxisLine(width: 0),
            majorTickLines: const MajorTickLines(size: 0),
          )
        ],
        series: <CartesianSeries>[
          _buildActualSpermStandbySeries(actualSpermZones, colorScheme),
          _buildPredictedSpermStandbySeries(predictedSpermZones, colorScheme),
          _buildOvulationZoneSeries(cycleData, records, colorScheme),
          _buildLhSeries(combinedLhData, lastRecordDate, colorScheme),
          _buildBbtSeries(combinedBbtData, lastRecordDate, colorScheme),
          _buildTimingMarkers(records, colorScheme),
        ],
      ),
    );
  }

  /// P1/P2: LHレベル (棒グラフ) - 確定と予測を1つのシリーズで描画
  ColumnSeries<models.CycleRecord, DateTime> _buildLhSeries(
      List<models.CycleRecord> dataSource, DateTime lastRecordDate, ColorScheme colorScheme) {
    final lhData =
        dataSource.where((r) => r.testResult != models.TestResult.none).toList();

    return ColumnSeries<models.CycleRecord, DateTime>(
      dataSource: lhData,
      xValueMapper: (models.CycleRecord record, _) => record.date,
      yValueMapper: (models.CycleRecord record, _) => record.testResult.index,
      name: AppStrings.helpLegendLH,
      color: colorScheme.primary.withAlpha((255 * 0.5).round()),
      width: 0.5,
      pointColorMapper: (models.CycleRecord record, _) {
          bool isPrediction = record.date.isAfter(lastRecordDate);
          return colorScheme.primary.withAlpha((255 * (isPrediction ? 0.3 : 0.5)).round());
      },
    );
  }

  /// P1/P2: 基礎体温 (折れ線グラフ) - 確定と予測を1つのシリーズで描画
  SplineSeries<models.CycleRecord, DateTime> _buildBbtSeries( // (★ エラー箇所修正: Grid -> models.CycleRecord)
      List<models.CycleRecord> dataSource, DateTime lastRecordDate, ColorScheme colorScheme) {
    final bbtData = dataSource.where((r) => r.bbt != null).toList();

    return SplineSeries<models.CycleRecord, DateTime>(
      dataSource: bbtData,
      xValueMapper: (models.CycleRecord record, _) => record.date,
      yValueMapper: (models.CycleRecord record, _) => record.bbt,
      name: AppStrings.helpLegendBBT,
      color: colorScheme.secondary,
      width: 3,
      pointColorMapper: (models.CycleRecord record, _) {
          bool isPrediction = record.date.isAfter(lastRecordDate);
          // (★ エラー箇所修正: withOpacity -> color.withOpacity)
          return colorScheme.secondary.withOpacity(isPrediction ? 0.5 : 1.0);
      },
      markerSettings: MarkerSettings(
        isVisible: true,
        color: colorScheme.secondary,
        borderColor: colorScheme.surface,
        shape: DataMarkerType.circle,
        borderWidth: 2,
        height: 5, width: 5
      ),
      yAxisName: 'bbtAxis',
    );
  }


  /// P2: タイミング (♡マーカー)
  ScatterSeries<models.CycleRecord, DateTime> _buildTimingMarkers(
      List<models.CycleRecord> records, ColorScheme colorScheme) {
    final timingRecords = records.where((r) => r.isTiming).toList();

    return ScatterSeries<models.CycleRecord, DateTime>(
      dataSource: timingRecords,
      xValueMapper: (models.CycleRecord record, _) => record.date,
      yValueMapper: (models.CycleRecord record, _) => 0.5,
      name: AppStrings.helpLegendTiming,
      color: colorScheme.tertiary,
      markerSettings: const MarkerSettings(
        isVisible: true,
        height: 15,
        width: 15,
        shape: DataMarkerType.pentagon,
      ),
    );
  }

  /// P1: 予測排卵ゾーン (赤帯) - BBT確定ロジック反映
  RangeAreaSeries<ChartData, DateTime> _buildOvulationZoneSeries(
      models.CycleData cycleData,
      List<models.CycleRecord> records,
      ColorScheme colorScheme) {
    final Map<String, dynamic> zoneInfo =
        _predictionLogic.getOvulationZones(cycleData, records);
    final List<ChartData> zones = zoneInfo['zones'] as List<ChartData>;
    final bool isConfirmed = zoneInfo['isConfirmed'] as bool;

    final Color zoneColor = isConfirmed
      ? colorScheme.error.withAlpha((255 * 0.4).round())
      : colorScheme.errorContainer.withAlpha((255 * 0.3).round());

    return RangeAreaSeries<ChartData, DateTime>(
      dataSource: zones,
      xValueMapper: (ChartData data, _) => data.x,
      lowValueMapper: (ChartData data, _) => 0,
      highValueMapper: (ChartData data, _) => 4,
      name: AppStrings.helpLegendOvulation,
      color: zoneColor,
      borderWidth: 0,
    );
  }

  /// P1: 精子の待機バー (青バー) - 実績
  RangeAreaSeries<ChartData, DateTime> _buildActualSpermStandbySeries(
      List<ChartData> zones, ColorScheme colorScheme) {
    return RangeAreaSeries<ChartData, DateTime>(
      dataSource: zones,
      xValueMapper: (ChartData data, _) => data.x,
      lowValueMapper: (ChartData data, _) => 0,
      highValueMapper: (ChartData data, _) => 4,
      name: AppStrings.helpLegendSperm,
      color: colorScheme.primary
          .withAlpha((255 * 0.2).round()),
      borderWidth: 0,
    );
  }

  /// P1: 精子の待機バー (青バー) - 予測 (TODO 4)
  RangeAreaSeries<ChartData, DateTime> _buildPredictedSpermStandbySeries(
      List<ChartData> zones, ColorScheme colorScheme) {
    return RangeAreaSeries<ChartData, DateTime>(
      dataSource: zones,
      xValueMapper: (ChartData data, _) => data.x,
      lowValueMapper: (ChartData data, _) => 0,
      highValueMapper: (ChartData data, _) => 4,
      name: AppStrings.helpLegendSpermPredicted,
      color: colorScheme.tertiaryContainer
          .withAlpha((255 * 0.3).round()),
      borderWidth: 1,
      borderColor: colorScheme.tertiaryContainer,
      dashArray: <double>[5, 5],
    );
  }


  /// P2: 「＋」FAB (検査/体温) モーダル表示
  void _showRecordModal(BuildContext context, WidgetRef ref) {
     final cycleData = ref.read(currentCycleDataProvider).valueOrNull;
     if (cycleData == null) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('周期データが見つかりません。')),
       );
       return;
     }
     final cycleId = cycleData.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return RecordModal(
          cycleId: cycleId,
          onSubmit: (record) {
              ref
                  .read(cycleDataProvider.notifier)
                  .addOrUpdateRecord(cycleId, record);

              if (record.testResult == models.TestResult.positive ||
                  record.testResult == models.TestResult.strongPositive) {
                ref.read(goldenTimeProvider.notifier).state = true;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(AppStrings.feedbackGoldenTime),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(AppStrings.feedbackRecordSaved),
                  ),
                );
              }
          },
        );
      },
    );
  }

  /// P2: 「♡」タイミング モーダル表示
  void _showTimingRecordModal(BuildContext context, WidgetRef ref) {
     final cycleData = ref.read(currentCycleDataProvider).valueOrNull;
     if (cycleData == null) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('周期データが見つかりません。')),
       );
       return;
     }
     final cycleId = cycleData.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return TimingRecordModal(
          cycleId: cycleId,
          onSubmit: (date) {
              ref
                  .read(cycleDataProvider.notifier)
                  .addTimingRecord(cycleId, date);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(AppStrings.feedbackRecordSaved),
                ),
              );
          },
        );
      },
    );
  }

  /// V1.1 (3.1.1) / V1.2 (2.5) / V1 (3.3) ヘルプモーダル
  void _buildHelpModal(
      BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.helpModalTitle,
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              _buildLegendItem(
                colorScheme.primary.withAlpha(120),
                AppStrings.helpLegendLH,
                AppStrings.helpLegendLHDesc,
                context,
              ),
              _buildLegendItem(
                colorScheme.secondary,
                AppStrings.helpLegendBBT,
                AppStrings.helpLegendBBTDesc,
                context,
              ),
              _buildLegendItem(
                colorScheme.errorContainer.withAlpha(150), // 通常の色
                AppStrings.helpLegendOvulation,
                AppStrings.helpLegendOvulationDesc,
                context,
              ),
               // BBT確定時の凡例を追加
              _buildLegendItem(
                colorScheme.error.withAlpha(100), // 濃い色
                AppStrings.helpLegendOvulationConfirmed,
                AppStrings.helpLegendOvulationConfirmedDesc,
                context,
              ),
              _buildLegendItem(
                colorScheme.primary.withAlpha(80),
                AppStrings.helpLegendSperm,
                AppStrings.helpLegendSpermDesc,
                context,
              ),
               // (TODO 4: 予測バーの凡例を追加)
              _buildLegendItem(
                colorScheme.tertiaryContainer.withAlpha(150), // 予測バーの色
                AppStrings.helpLegendSpermPredicted,
                AppStrings.helpLegendSpermPredictedDesc,
                context,
              ),
              _buildLegendItem(
                colorScheme.tertiary,
                AppStrings.helpLegendTiming,
                AppStrings.helpLegendTimingDesc,
                context,
              ),
              const SizedBox(height: 16),
              Divider(color: colorScheme.outlineVariant),
              const SizedBox(height: 16),
              Text(
                AppStrings.helpModalConclusion,
                style: textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        );
      },
    );
  }

  /// V1.2 (2.5) ヘルプモーダル (凡例) の共通ウィジェット
  Widget _buildLegendItem(
      Color color, String title, String subtitle, BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      title: Text(title,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

/// V1 (3.1) Empty State
class _EmptyState extends StatelessWidget {
  final String title;
  final String body;
  const _EmptyState({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insights_rounded,
                size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
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

// ChartData は prediction_logic.dart から export される

