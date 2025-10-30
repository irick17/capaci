import 'dart:math';

import '../constants/app_logic.dart';
import '../models/cycle_models.dart';
// logger を import
import '../utils/logger.dart';

// ChartData を export する
export 'prediction_logic.dart' show ChartData;

/// V1.1 (3.1.1) / V1 (数値データ) に基づく予測ロジック
class PredictionLogic {
  // --- P1: ゾーン計算 ---

  /// 予測排卵ゾーン (赤帯) のデータと確定フラグを計算
  /// 戻り値: {'zones': List<ChartData>, 'isConfirmed': bool}
  Map<String, dynamic> getOvulationZones(
      CycleData cycleData, List<CycleRecord> records) {
     logger.d("Calculating ovulation zones for cycle ${cycleData.id}...");
    final List<ChartData> zones = [];
    bool isConfirmed = false; // BBT上昇による確定フラグ

    // Ensure records are sorted by date for accurate BBT rise detection
    records.sort((a, b) => a.date.compareTo(b.date));

    // 予測ロジック① (LH/周期) と 予測ロジック② (BBT) の両方を呼び出す
    final predictedOvulation = _predictOvulationDate(cycleData, records, bbtPriority: false);
    final ovulationDateByBbt = _findOvulationDateByBbtRise(records);
     logger.d("Predicted ovulation (LH/Cycle): $predictedOvulation, Ovulation by BBT: $ovulationDateByBbt");

    // 表示する排卵日 (BBT確定 > LH/周期予測)
    final displayOvulationDate = ovulationDateByBbt ?? predictedOvulation;
     logger.d("Displaying ovulation date based on: $displayOvulationDate");

    if (displayOvulationDate != null) {
       // (修正) 未使用の変数を削除
      // const windowDuration = AppLogic.ovulationWindow; // Typically 12-24 hours
       // Center the window around the estimated ovulation time
       // Example: If ovulation is estimated at noon, window is 6am-6pm if 12h, or previous day 6pm to this day 6pm if 24h.
       // Let's use a simpler approach: Start slightly before, end slightly after.
      // (修正) const を追加
      final windowStart = displayOvulationDate.subtract(const Duration(hours: 12)); // Start 12h before estimate
      // (修正) const を追加
      final windowEnd = displayOvulationDate.add(const Duration(hours: 12)); // End 12h after estimate

       logger.d("Ovulation window calculated: $windowStart to $windowEnd");


      // Create zone data points using floor/ceil to align with chart rendering if needed
      // Or just use the exact times
      zones.add(ChartData(windowStart, 0)); // Bottom left
      zones.add(ChartData(windowStart, 1)); // Top left (Using 1 for value, height is controlled by range series)
      zones.add(ChartData(windowEnd, 1));   // Top right
      zones.add(ChartData(windowEnd, 0));   // Bottom right

      // (ロジック改善: BBT確定ロジックを厳密化)
      // Confirm if BBT rise date is close to the LH/Cycle prediction
      if (ovulationDateByBbt != null && predictedOvulation != null) {
        final differenceInDays = ovulationDateByBbt.difference(predictedOvulation).inDays.abs();
         logger.d("Difference between BBT and LH/Cycle prediction: $differenceInDays days");
        // Consider confirmed if BBT rise found and it's within 2 days of LH/Cycle prediction
        if (differenceInDays <= 2) {
          isConfirmed = true;
           logger.d("Ovulation CONFIRMED by BBT proximity.");
        } else {
           logger.d("BBT rise found, but differs >2 days from LH/Cycle prediction. Not confirming.");
           // Optional: Decide whether to *still* show the BBT-based zone or stick to LH/Cycle
           // Current logic uses BBT date if available (displayOvulationDate = ovulationDateByBbt)
        }
      } else if (ovulationDateByBbt != null && predictedOvulation == null) {
         // If only BBT rise is found (e.g., irregular cycle, no LH data yet)
         isConfirmed = true; // Consider it confirmed based on BBT alone
         logger.d("Ovulation CONFIRMED by BBT rise (no LH/Cycle prediction available).");
      } else {
         logger.d("Ovulation NOT confirmed by BBT.");
      }
    } else {
       logger.d("Could not determine displayOvulationDate.");
    }
    return {'zones': zones, 'isConfirmed': isConfirmed};
  }

  /// 精子の待機バー (青バー) のデータを計算
  /// 戻り値: {'actual': List<ChartData>, 'predicted': List<ChartData>}
  Map<String, List<ChartData>> getSpermStandbyZones(
      CycleData cycleData, List<CycleRecord> records) {
    logger.d("Calculating sperm standby zones for cycle ${cycleData.id}...");
    final List<ChartData> actualZones = [];
    final List<ChartData> predictedZones = [];

    const capacitationTime = AppLogic.spermCapacitationTime; // ~7 hours
    const lifespan = AppLogic.spermLifespan; // ~4 days

    // Ensure records are sorted for consistency
    records.sort((a, b) => a.date.compareTo(b.date));

    // 1. ユーザーが記録した実績タイミング（actual）
    final timingRecords = records.where((r) => r.isTiming).toList();
    logger.d("Found ${timingRecords.length} actual timing records.");
    for (final record in timingRecords) {
      // Calculate standby start (timing + capacitation)
      final standbyStart = record.date.add(capacitationTime);
      // Calculate standby end (timing + lifespan)
      final standbyEnd = record.date.add(lifespan);
       logger.d("  Actual timing on ${record.date}: Standby zone $standbyStart to $standbyEnd");

      // Add points for the RangeAreaSeries
      actualZones.add(ChartData(standbyStart, 0)); // Bottom left
      actualZones.add(ChartData(standbyStart, 1)); // Top left (Value 1, height controlled by series)
      actualZones.add(ChartData(standbyEnd, 1));   // Top right
      actualZones.add(ChartData(standbyEnd, 0));   // Bottom right
    }

    // 2. 予測に基づく推奨タイミング（predicted）
    // (TODO 解消済み: 予測タイミング（推奨日）に基づく予測バー)
    // Get the *predicted* ovulation date (using LH/Cycle first, then BBT as fallback if needed)
    final predictedOvulation = _predictOvulationDate(cycleData, records, bbtPriority: false); // Use LH/Cycle priority for prediction
    logger.d("Predicted ovulation for recommendation: $predictedOvulation");

    if (predictedOvulation != null) {
      // Recommend timing based on prediction (e.g., 1-2 days before predicted ovulation)
      // Let's recommend timing 1 day before predicted ovulation
      // (修正) const を追加
      final recommendedTimingDate = predictedOvulation.subtract(const Duration(days: 1));
      logger.d("Recommended timing date based on prediction: $recommendedTimingDate");

      // Calculate the predicted standby zone based on this recommended timing
      final standbyStart = recommendedTimingDate.add(capacitationTime);
      final standbyEnd = recommendedTimingDate.add(lifespan);
       logger.d("  Predicted standby zone based on recommendation: $standbyStart to $standbyEnd");


      // Add points for the predicted RangeAreaSeries
      predictedZones.add(ChartData(standbyStart, 0));
      predictedZones.add(ChartData(standbyStart, 1));
      predictedZones.add(ChartData(standbyEnd, 1));
      predictedZones.add(ChartData(standbyEnd, 0));

    } else {
       logger.d("Cannot calculate recommended timing - no predicted ovulation date.");
    }

    return {'actual': actualZones, 'predicted': predictedZones};
  }

  /// 記録と周期情報から排卵日を予測する
  /// bbtPriority: trueならBBT上昇を最優先, falseならLH陽性/周期予測を優先
  DateTime? _predictOvulationDate(
      CycleData cycleData, List<CycleRecord> records, {bool bbtPriority = true}) {
     logger.d("Predicting ovulation date (bbtPriority: $bbtPriority)...");

    // Ensure records are sorted
    records.sort((a, b) => a.date.compareTo(b.date));

    // BBTの上昇から推定 (3 over 6 rule)
    final ovulationDateByBbt = _findOvulationDateByBbtRise(records);
     logger.d("Ovulation date by BBT rise: $ovulationDateByBbt");

    // LH陽性/強陽性記録から予測
     // Find the *last* positive or strong positive record
    final positiveRecord = records.lastWhere(
        (r) =>
            r.testResult == TestResult.positive ||
            r.testResult == TestResult.strongPositive,
        // Provide a default CycleRecord with a very old date if none found
        orElse: () => CycleRecord(date: DateTime(0))); // Use DateTime(0) as indicator

    DateTime? ovulationDateByLh;
    if (positiveRecord.date.year > 1) { // Check if a valid record was found (year > 0)
      final durationToAdd = positiveRecord.testResult == TestResult.strongPositive
          ? AppLogic.lhPeakToOvulation // Shorter duration for peak
          : AppLogic.lhSurgeToOvulation; // Longer duration for initial positive
      ovulationDateByLh = positiveRecord.date.add(durationToAdd);
       logger.d("Ovulation date by LH surge/peak (${positiveRecord.testResult} on ${positiveRecord.date}): $ovulationDateByLh");
    } else {
        logger.d("No positive/strong positive LH records found.");
    }


    // 周期開始日と平均周期から予測 (簡易) - 排卵日は平均周期の14日前と仮定
    DateTime? ovulationDateByCycle;
    // Ensure averageCycleLength is valid
    if (cycleData.averageCycleLength >= 21 && cycleData.averageCycleLength <= 45) { // Reasonable cycle range
      // Calculate ovulation day relative to start date
      final predictedDay = cycleData.averageCycleLength - 14; // Luteal phase assumption
      if (predictedDay > 0) {
        ovulationDateByCycle = cycleData.startDate.add(Duration(days: predictedDay));
         logger.d("Ovulation date by cycle length (${cycleData.averageCycleLength} days): $ovulationDateByCycle");
      } else {
         logger.w("Calculated predictedDay ($predictedDay) is not positive.");
      }
    } else {
       logger.w("Average cycle length (${cycleData.averageCycleLength}) is outside typical range for cycle-based prediction.");
    }


    // Determine final prediction based on priority
    if (bbtPriority) {
       logger.d("Using BBT priority:");
       if (ovulationDateByBbt != null) {
          logger.d("Returning BBT date: $ovulationDateByBbt");
          return ovulationDateByBbt;
       }
       if (ovulationDateByLh != null) {
          logger.d("Returning LH date: $ovulationDateByLh");
          return ovulationDateByLh;
       }
        logger.d("Returning Cycle date: $ovulationDateByCycle");
       return ovulationDateByCycle; // Fallback to cycle prediction
    } else { // LH/Cycle priority
        logger.d("Using LH/Cycle priority:");
       if (ovulationDateByLh != null) {
           logger.d("Returning LH date: $ovulationDateByLh");
           return ovulationDateByLh;
       }
       if (ovulationDateByCycle != null) {
          logger.d("Returning Cycle date: $ovulationDateByCycle");
          return ovulationDateByCycle;
       }
        logger.d("Returning BBT date: $ovulationDateByBbt");
       return ovulationDateByBbt; // Fallback to BBT prediction
    }
  }

  /// BBTの持続的な上昇 (3 over 6 rule) から排卵日を推定するヘルパーメソッド
  /// 排卵日は、最初に上昇した日の「前日」と推定する
  DateTime? _findOvulationDateByBbtRise(List<CycleRecord> records) {
     logger.d("Finding ovulation date by BBT rise (3 over 6 rule)...");
    // Get records with BBT, ensure sorted
    final bbtRecords = records
        .where((r) => r.bbt != null && r.bbt! > 30 && r.bbt! < 45) // Basic sanity check for BBT value
        .toList();
    // No need to sort again if 'records' was already sorted

    // Need at least 9 records (3 high + 6 low) to apply the rule
    if (bbtRecords.length < 9) {
      logger.d("Not enough BBT records (${bbtRecords.length}) to apply 3 over 6 rule.");
      return null;
    }

    // Iterate backwards from the most recent data
    // Start index `i` points to the *last* of the 3 potentially high temps
    for (int i = bbtRecords.length - 1; i >= 8; i--) {
      // The three potentially high temperatures
      final highTemp1 = bbtRecords[i].bbt!;     // Most recent
      final highTemp2 = bbtRecords[i - 1].bbt!;
      final highTemp3 = bbtRecords[i - 2].bbt!; // Earliest of the three

      // The preceding six temperatures for the coverline
      final lowTemps = bbtRecords
          .sublist(i - 8, i - 2) // Indices from i-8 up to (but not including) i-2
          .map((r) => r.bbt!)
          .toList();

      // Calculate the coverline: the highest of the 6 low temps
      final coverLine = lowTemps.reduce(max);
       // logger.d("Checking index $i: Highs=[$highTemp3, $highTemp2, $highTemp1], Coverline=$coverLine (from $lowTemps)");


      // Check if all 3 temps are above the coverline
      if (highTemp1 > coverLine &&
          highTemp2 > coverLine &&
          highTemp3 > coverLine) {
         logger.d("  Index $i: Found 3 temps above coverline ($coverLine). Highs=[$highTemp3, $highTemp2, $highTemp1]");
        // Check if at least one of the high temps is >= coverline + 0.2°C (or equivalent Fahrenheit)
        // (Using 0.2 for Celsius as per common rule)
        if (highTemp1 >= coverLine + 0.2 ||
            highTemp2 >= coverLine + 0.2 ||
            highTemp3 >= coverLine + 0.2) {
           logger.d("    Index $i: At least one temp is >= coverline + 0.2. BBT rise confirmed.");
          // If the rule is met, ovulation is estimated to be the day *before*
          // the first temperature rise (which is bbtRecords[i - 2]).
          // The day *before* bbtRecords[i-2] is the date of bbtRecords[i-3].
          final estimatedOvulationDate = bbtRecords[i - 3].date;
          logger.d("    Estimated ovulation date by BBT: $estimatedOvulationDate (day before first rise)");
          return estimatedOvulationDate;
        } else {
           logger.d("    Index $i: Temps are above coverline, but none are >= coverline + 0.2.");
        }
      }
    }

    logger.d("BBT rise pattern not found.");
    return null; // Pattern not found
  }


  // --- P1: 予測グラフ計算 ---

   /// Predicts future LH levels based on predicted ovulation.
  List<CycleRecord> predictFutureLh(
      CycleData cycleData, List<CycleRecord> existingRecords, DateTime untilDate) {
    logger.d("Predicting future LH until $untilDate...");
    List<CycleRecord> predictions = [];
    // Ensure records are sorted
    existingRecords.sort((a, b) => a.date.compareTo(b.date));

    // Determine the start date for prediction (day after the last record or cycle start)
    // (修正) const を追加
    DateTime lastRecordDate = existingRecords.isNotEmpty
        ? existingRecords.last.date
        : cycleData.startDate.subtract(const Duration(days: 1)); // Ensure prediction starts from day 1 if no records
    // (修正) const を追加
    DateTime predictionDate = lastRecordDate.add(const Duration(days: 1));
     logger.d("Prediction starts from: $predictionDate");

    // Get the predicted ovulation date (use LH/Cycle priority for consistency)
    final predictedOvulation = _predictOvulationDate(cycleData, existingRecords, bbtPriority: false);
     logger.d("Predicted ovulation date used for LH prediction: $predictedOvulation");

    while (!predictionDate.isAfter(untilDate)) {
      TestResult predictedResult = TestResult.negative; // Default to negative

      if (predictedOvulation != null) {
        // Calculate days *until* predicted ovulation (positive if future, zero on day, negative if past)
        final daysUntilOvulation = predictedOvulation.difference(predictionDate).inDays;

        // Predict based on proximity to ovulation
        if (daysUntilOvulation == 0) {
            // Assume peak (strong positive) is ~1 day before ovulation day itself
            // So on ovulation day, it might be positive or negative depending on timing
             predictedResult = TestResult.positive; // Or negative? Let's assume positive
             logger.d("  Predicting LH Positive for $predictionDate (Ovulation day)");
        } else if (daysUntilOvulation == 1) {
             // Day before ovulation: Likely peak or strong positive
             predictedResult = TestResult.strongPositive;
              logger.d("  Predicting LH Strong Positive for $predictionDate (1 day before ov)");
        } else if (daysUntilOvulation == 2) {
             // Two days before: Likely positive (start of surge)
             predictedResult = TestResult.positive;
             logger.d("  Predicting LH Positive for $predictionDate (2 days before ov)");
        } else {
            // More than 2 days before or after ovulation: Assume negative
             predictedResult = TestResult.negative;
            // logger.d("  Predicting LH Negative for $predictionDate"); // Too verbose maybe
        }
      } else {
         // If ovulation cannot be predicted, assume negative
         predictedResult = TestResult.negative;
         // logger.d("  Predicting LH Negative for $predictionDate (no predicted ov date)");
      }

      predictions.add(CycleRecord(
        date: predictionDate,
        testResult: predictedResult,
        bbt: null, // BBT prediction is separate
        isTiming: false, // Predictions don't include timing
      ));

      // Move to the next day
      // (修正) const を追加
      predictionDate = predictionDate.add(const Duration(days: 1));
    }
     logger.d("Generated ${predictions.length} LH predictions.");
    return predictions;
  }

  /// Predicts future BBT levels with a simple rise after predicted ovulation.
 List<CycleRecord> predictFutureBbt(
      CycleData cycleData, List<CycleRecord> existingRecords, DateTime untilDate) {
    logger.d("Predicting future BBT until $untilDate...");
    List<CycleRecord> predictions = [];
    // Ensure records are sorted
    existingRecords.sort((a, b) => a.date.compareTo(b.date));

    // Determine start date for prediction
    // (修正) const を追加
    DateTime lastRecordDate = existingRecords.isNotEmpty
        ? existingRecords.last.date
        : cycleData.startDate.subtract(const Duration(days: 1));
    // (修正) const を追加
    DateTime predictionDate = lastRecordDate.add(const Duration(days: 1));
     logger.d("BBT Prediction starts from: $predictionDate");


    // Estimate baseline low temperature (follicular phase)
    // Use average of last ~7 days of non-null BBT before prediction starts, or a default
    double lowTempAvg = 36.3; // Default baseline
    final recentBbtRecords = existingRecords
        .where((r) => r.bbt != null && r.bbt! > 30 && r.bbt! < 45 && !r.date.isAfter(lastRecordDate)) // Records up to last recorded date
        .toList();
    // Take up to the last 7 available readings
    final relevantBbt = recentBbtRecords.reversed.take(7).map((r) => r.bbt!).toList();

    if (relevantBbt.isNotEmpty) {
      lowTempAvg = relevantBbt.reduce((a, b) => a + b) / relevantBbt.length;
       logger.d("Calculated baseline BBT: ${lowTempAvg.toStringAsFixed(2)} from ${relevantBbt.length} recent records.");
    } else {
       logger.d("Using default baseline BBT: $lowTempAvg");
    }


    // Get predicted ovulation date (use LH/Cycle priority)
    final predictedOvulation = _predictOvulationDate(cycleData, existingRecords, bbtPriority: false);
     logger.d("Predicted ovulation date used for BBT prediction: $predictedOvulation");

    // Typical temperature rise amount
    const double tempRise = 0.3;
    final random = Random();

    while (!predictionDate.isAfter(untilDate)) {
      double predictedBbt;

      if (predictedOvulation != null &&
          (predictionDate.isAfter(predictedOvulation) || isSameDay(predictionDate, predictedOvulation)) ) { // Rise starts on or after predicted ovulation
        // Luteal phase: Higher temperature + slight random variation
        predictedBbt = lowTempAvg + tempRise + (random.nextDouble() * 0.1 - 0.05); // Add rise + small noise
        // logger.d("  Predicting HIGH BBT for $predictionDate");
      } else {
        // Follicular phase: Baseline temperature + slight random variation
        predictedBbt = lowTempAvg + (random.nextDouble() * 0.1 - 0.05); // Baseline + small noise
         // logger.d("  Predicting LOW BBT for $predictionDate");
      }

      // Round to 2 decimal places for realism
      predictedBbt = (predictedBbt * 100).round() / 100.0;

      predictions.add(CycleRecord(
        date: predictionDate,
        bbt: predictedBbt,
        testResult: TestResult.none, // LH prediction is separate
        isTiming: false,
      ));

      // Move to the next day
      // (修正) const を追加
      predictionDate = predictionDate.add(const Duration(days: 1));
    }
     logger.d("Generated ${predictions.length} BBT predictions.");
    return predictions;
  }
}

// ChartData クラス定義 (グラフ表示用)
class ChartData {
  ChartData(this.x, this.y);
  final DateTime x;
  final double y; // Use double for flexibility with numeric axes
}

// Helper to check if two DateTime objects represent the same date (ignoring time)
bool isSameDay(DateTime date1, DateTime date2) {
  return date1.year == date2.year &&
      date1.month == date2.month &&
      date1.day == date2.day;
}

