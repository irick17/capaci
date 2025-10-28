import 'dart:math';

import '../constants/app_logic.dart';
import '../models/cycle_models.dart';
// ChartData を export する
export 'prediction_logic.dart' show ChartData;

/// V1.1 (3.1.1) / V1 (数値データ) に基づく予測ロジック
class PredictionLogic {
  // --- P1: ゾーン計算 ---

  /// 予測排卵ゾーン (赤帯) のデータと確定フラグを計算
  /// 戻り値: {'zones': List<ChartData>, 'isConfirmed': bool}
  Map<String, dynamic> getOvulationZones(
      CycleData cycleData, List<CycleRecord> records) {
    final List<ChartData> zones = [];
    bool isConfirmed = false; // BBT上昇による確定フラグ

    // 予測ロジック① (LH/周期) と 予測ロジック② (BBT) の両方を呼び出す
    final predictedOvulation = _predictOvulationDate(cycleData, records, bbtPriority: false);
    final ovulationDateByBbt = _findOvulationDateByBbtRise(records);

    // 表示する排卵日 (BBT確定 > LH/周期予測)
    final displayOvulationDate = ovulationDateByBbt ?? predictedOvulation;

    if (displayOvulationDate != null) {
      const windowDuration = AppLogic.ovulationWindow;
      final windowStart =
          displayOvulationDate.subtract(Duration(hours: windowDuration.inHours ~/ 2));
      final windowEnd =
          displayOvulationDate.add(Duration(hours: windowDuration.inHours ~/ 2));

      zones.add(ChartData(windowStart, 0));
      zones.add(ChartData(windowStart, 4));
      zones.add(ChartData(windowEnd, 4));
      zones.add(ChartData(windowEnd, 0));

      // (ロジック改善: BBT確定ロジックを厳密化)
      if (ovulationDateByBbt != null && predictedOvulation != null) {
        final differenceInDays = ovulationDateByBbt.difference(predictedOvulation).inDays.abs();
        if (differenceInDays <= 2) {
          isConfirmed = true;
        }
      } else if (ovulationDateByBbt != null && predictedOvulation == null) {
         isConfirmed = true;
      }
    }
    return {'zones': zones, 'isConfirmed': isConfirmed};
  }

  /// 精子の待機バー (青バー) のデータを計算
  /// 戻り値: {'actual': List<ChartData>, 'predicted': List<ChartData>}
  Map<String, List<ChartData>> getSpermStandbyZones(
      CycleData cycleData, List<CycleRecord> records) {
    
    final List<ChartData> actualZones = [];
    final List<ChartData> predictedZones = [];
    
    const capacitationTime = AppLogic.spermCapacitationTime;
    const lifespan = AppLogic.spermLifespan;

    // 1. ユーザーが記録した実績タイミング（actual）
    final timingRecords = records.where((r) => r.isTiming).toList();
    for (final record in timingRecords) {
      final standbyStart = record.date.add(capacitationTime);
      final standbyEnd = record.date.add(lifespan);

      actualZones.add(ChartData(standbyStart, 0));
      actualZones.add(ChartData(standbyStart, 4));
      actualZones.add(ChartData(standbyEnd, 4));
      actualZones.add(ChartData(standbyEnd, 0));
    }

    // 2. 予測に基づく推奨タイミング（predicted）
    // (TODO 解消: 予測タイミング（推奨日）に基づく予測バー)
    final predictedOvulation = _predictOvulationDate(cycleData, records);
    if (predictedOvulation != null) {
      // 例: 予測排卵日の2日前にタイミングを取ることを推奨
      final recommendedTimingDate = predictedOvulation.subtract(const Duration(days: 2));
      
      // その推奨タイミングに基づく待機バーを計算
      final standbyStart = recommendedTimingDate.add(capacitationTime);
      final standbyEnd = recommendedTimingDate.add(lifespan);

      // ただし、既に実績（actual）ゾーンがその期間をカバーしている場合は表示しない（任意）
      // (今回は簡易的に常に予測バーも表示する)
      predictedZones.add(ChartData(standbyStart, 0));
      predictedZones.add(ChartData(standbyStart, 4));
      predictedZones.add(ChartData(standbyEnd, 4));
      predictedZones.add(ChartData(standbyEnd, 0));
    }

    return {'actual': actualZones, 'predicted': predictedZones};
  }

  /// 記録と周期情報から排卵日を予測する
  DateTime? _predictOvulationDate(
      CycleData cycleData, List<CycleRecord> records, {bool bbtPriority = true}) {

    // 優先度1: BBTの上昇から推定 (3 over 6 rule)
    final ovulationDateByBbt = _findOvulationDateByBbtRise(records);
    if (bbtPriority && ovulationDateByBbt != null) {
      return ovulationDateByBbt;
    }

    // 優先度2: LH陽性/強陽性記録から予測
    final positiveRecord = records.lastWhere(
        (r) =>
            r.testResult == TestResult.positive ||
            r.testResult == TestResult.strongPositive,
        orElse: () => CycleRecord(date: DateTime(0)));

    if (positiveRecord.date.year > 1970) {
      final durationToAdd = positiveRecord.testResult == TestResult.strongPositive
          ? AppLogic.lhPeakToOvulation
          : AppLogic.lhSurgeToOvulation;
      return positiveRecord.date.add(durationToAdd);
    }

    // 優先度3: 周期開始日と平均周期から予測 (簡易)
    if (cycleData.averageCycleLength > 0) {
      final predictedDay = cycleData.averageCycleLength - 14;
      if (predictedDay > 0) {
        return cycleData.startDate.add(Duration(days: predictedDay));
      }
    }

    if (!bbtPriority && ovulationDateByBbt != null) {
       return ovulationDateByBbt;
    }
    return null;
  }

  /// BBTの持続的な上昇 (3 over 6 rule) から排卵日を推定するヘルパーメソッド
  DateTime? _findOvulationDateByBbtRise(List<CycleRecord> records) {
    final bbtRecords = records
        .where((r) => r.bbt != null)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (bbtRecords.length < 9) {
      return null;
    }

    for (int i = bbtRecords.length - 1; i >= 8; i--) {
      final highTemp1 = bbtRecords[i].bbt!;
      final highTemp2 = bbtRecords[i - 1].bbt!;
      final highTemp3 = bbtRecords[i - 2].bbt!;
      final lowTemps = bbtRecords
          .sublist(i - 8, i - 2)
          .map((r) => r.bbt!)
          .toList();
      final coverLine = lowTemps.reduce(max);

      if (highTemp1 > coverLine &&
          highTemp2 > coverLine &&
          highTemp3 > coverLine) {
        if (highTemp1 >= coverLine + 0.2 || highTemp2 >= coverLine + 0.2 || highTemp3 >= coverLine + 0.2) {
             return bbtRecords[i - 3].date;
        }
      }
    }
    return null;
  }


  // --- P1: 予測グラフ計算 ---
  List<CycleRecord> predictFutureLh(
      CycleData cycleData, List<CycleRecord> existingRecords, DateTime untilDate) {
    List<CycleRecord> predictions = [];
    DateTime lastRecordDate = existingRecords.isNotEmpty
        ? existingRecords.last.date
        : cycleData.startDate;
    DateTime predictionDate = lastRecordDate.add(const Duration(days: 1));
    final predictedOvulation = _predictOvulationDate(cycleData, existingRecords);

    while (predictionDate.isBefore(untilDate) || predictionDate.isAtSameMomentAs(untilDate)) {
      TestResult predictedResult = TestResult.negative;
      if (predictedOvulation != null) {
        final daysUntilOvulation = predictedOvulation.difference(predictionDate).inDays;
        if (daysUntilOvulation == 1) {
             predictedResult = TestResult.strongPositive;
        } else if (daysUntilOvulation == 2) {
             predictedResult = TestResult.positive;
        }
      }
      predictions.add(CycleRecord(
        date: predictionDate,
        testResult: predictedResult,
        bbt: null,
        isTiming: false,
      ));
      predictionDate = predictionDate.add(const Duration(days: 1));
    }
    return predictions;
  }

 List<CycleRecord> predictFutureBbt(
      CycleData cycleData, List<CycleRecord> existingRecords, DateTime untilDate) {
    List<CycleRecord> predictions = [];
    DateTime lastRecordDate = existingRecords.isNotEmpty
        ? existingRecords.last.date
        : cycleData.startDate;
    DateTime predictionDate = lastRecordDate.add(const Duration(days: 1));

    double lowTempAvg = 36.3;
    final recentBbt = existingRecords
        .where((r) => r.bbt != null && r.date.isAfter(lastRecordDate.subtract(const Duration(days: 7))))
        .map((r) => r.bbt!)
        .toList();
    if (recentBbt.isNotEmpty) {
      lowTempAvg = recentBbt.reduce((a, b) => a + b) / recentBbt.length;
    }
    final predictedOvulation = _predictOvulationDate(cycleData, existingRecords);
    const double tempRise = 0.3;

    while (predictionDate.isBefore(untilDate) || predictionDate.isAtSameMomentAs(untilDate)) {
      double predictedBbt = lowTempAvg;
      if (predictedOvulation != null && predictionDate.isAfter(predictedOvulation)) {
        predictedBbt = lowTempAvg + tempRise + (Random().nextDouble() * 0.1 - 0.05);
      } else {
        predictedBbt = lowTempAvg + (Random().nextDouble() * 0.1 - 0.05);
      }
      predictedBbt = (predictedBbt * 100).round() / 100.0;

      predictions.add(CycleRecord(
        date: predictionDate,
        bbt: predictedBbt,
        testResult: TestResult.none,
        isTiming: false,
      ));
      predictionDate = predictionDate.add(const Duration(days: 1));
    }
    return predictions;
  }
}

// ChartData クラス定義
class ChartData {
  ChartData(this.x, this.y);
  final DateTime x;
  final double y;
}
