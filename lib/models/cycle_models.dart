import 'package:hive_flutter/hive_flutter.dart';

part 'cycle_models.g.dart'; // Hive アダプタ生成用

/// 検査結果 (V1.1 (3.3))
@HiveType(typeId: 1)
enum TestResult {
  @HiveField(0)
  none, // 未記録または初期値
  @HiveField(1)
  negative, // 陰性
  @HiveField(2)
  positive, // 陽性
  @HiveField(3)
  strongPositive, // 強陽性
}

/// 1日ごとの記録データ (V1.1 (5.1))
@HiveType(typeId: 2)
class CycleRecord extends HiveObject { // HiveObject を継承
  @HiveField(0)
  DateTime date;

  @HiveField(1)
  double? bbt; // 基礎体温 (任意)

  @HiveField(2)
  TestResult testResult;

  @HiveField(3)
  String? imagePath; // 画像メモのパス (任意)

  @HiveField(4)
  bool isTiming; // タイミングを取ったか

  // *** [TODO 4] 生理記録フラグを追加 ***
  @HiveField(5)
  bool isPeriod; // 生理中か

  CycleRecord({
    required this.date,
    this.bbt,
    this.testResult = TestResult.none,
    this.imagePath,
    this.isTiming = false, // デフォルトは false
    this.isPeriod = false, // *** [TODO 4] デフォルトは false ***
  });
}


/// 1周期全体のデータ (V1.1 (5.1))
@HiveType(typeId: 0)
class CycleData extends HiveObject { // HiveObject を継承
  @HiveField(0)
  final String id; // UUID or Timestamp

  @HiveField(1)
  final DateTime startDate;

  // (エラー箇所: プロパティ名を averageCycleLength に統一)
  @HiveField(2)
  final int averageCycleLength; // 平均周期日数

  @HiveField(3)
  final bool isRegular; // 周期の規則性

  @HiveField(4)
  // final List<CycleRecord> records; // HiveList を使用
  HiveList<CycleRecord>? records; // Nullable に変更

  CycleData({
    required this.id,
    required this.startDate,
    // (エラー箇所: プロパティ名を averageCycleLength に統一)
    required this.averageCycleLength,
    required this.isRegular,
    this.records, // Nullable に
  });
}
