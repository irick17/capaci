import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:async';

import '../models/cycle_models.dart';
// logger を import
import '../utils/logger.dart';

// --- P1 (3.1.2) GOLDEN TIME 状態 ---
final goldenTimeProvider = StateProvider<bool>((ref) {
  return false;
});

// --- P3 (3.1.4) 過去周期の確認 ---
final currentCycleIndexProvider =
    StateNotifierProvider<CurrentCycleIndexNotifier, int>((ref) {
  return CurrentCycleIndexNotifier();
});

class CurrentCycleIndexNotifier extends StateNotifier<int> {
  CurrentCycleIndexNotifier() : super(0);

  void setPageIndex(int index) {
    state = index;
  }
}

// --- P0/P1/P2 データ管理 ---
final cycleDataProvider =
    StateNotifierProvider<CycleDataNotifier, List<CycleData>>((ref) {
  final notifier = CycleDataNotifier(ref);
  ref.listen(currentCycleIndexProvider, (_, nextIndex) {
     ref.read(goldenTimeProvider.notifier).state = false;
  });
  return notifier;
});

class CycleDataNotifier extends StateNotifier<List<CycleData>> {
  final Ref ref;
  late Box<CycleData> _cycleBox;
  StreamSubscription? _boxSubscription;

  CycleDataNotifier(this.ref) : super([]) {
    _init();
  }

  Future<void> _init() async {
    try { // _init 全体を try-catch
      _cycleBox = await Hive.openBox<CycleData>('cycleBox');
      _boxSubscription = _cycleBox
          .watch()
          .map((_) => _cycleBox.values.toList()
            ..sort((a, b) => b.startDate.compareTo(a.startDate)))
          .startWith(_cycleBox.values.toList()
            ..sort((a, b) => b.startDate.compareTo(a.startDate)))
          .listen((cycles) {
        if (mounted) {
            state = cycles;
            Future.microtask(() => ref.read(currentCycleIndexProvider.notifier).setPageIndex(0));
        }
      }, onError: (e, stackTrace) { // onError で stackTrace も受け取る
        logger.e("Error listening to Hive box", error: e, stackTrace: stackTrace);
      });
       if (mounted && state.isEmpty) {
          state = _cycleBox.values.toList()..sort((a, b) => b.startDate.compareTo(a.startDate));
           Future.microtask(() => ref.read(currentCycleIndexProvider.notifier).setPageIndex(0));
       }
    } catch (e, stackTrace) { // Boxを開く際のエラーもキャッチ
       logger.e("Error initializing CycleDataNotifier", error: e, stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    _boxSubscription?.cancel();
    super.dispose();
  }

  /// 指定された ID の CycleData を取得する
  CycleData? getCycleById(String cycleId) {
    try { // Box アクセスを try-catch
        if (Hive.isBoxOpen('cycleBox')) {
           _cycleBox = Hive.box<CycleData>('cycleBox');
           return _cycleBox.get(cycleId);
        }
        return state.firstWhere((cycle) => cycle.id == cycleId);
    } catch(e, stackTrace) {
        logger.e("Error getting CycleData by ID: $cycleId", error: e, stackTrace: stackTrace);
        return null; // 見つからない場合 or エラー時は null
    }
  }


  /// V1 (フロー 1) オンボーディングからの初期周期作成
  Future<void> createInitialCycle(
      DateTime startDate, int averageLength, bool isRegular) async {
    try { // DB操作を try-catch
      if (!Hive.isBoxOpen('cycleBox')) {
          _cycleBox = await Hive.openBox<CycleData>('cycleBox');
      }
      final newCycle = CycleData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startDate: startDate,
        // (★ エラー箇所修正: 'averageLength' -> 'averageCycleLength' に修正)
        averageCycleLength: averageLength,
        isRegular: isRegular,
        records: HiveList(_cycleBox),
      );
      await _cycleBox.put(newCycle.id, newCycle);
    } catch (e, stackTrace) {
       logger.e("Error creating initial cycle", error: e, stackTrace: stackTrace);
    }
  }

  /// V1 (フロー 3) 検査記録または基礎体温記録の追加/更新
  Future<void> addOrUpdateRecord(String cycleId, CycleRecord newRecord) async {
    try { // DB操作を try-catch
      if (!Hive.isBoxOpen('cycleBox')) {
          _cycleBox = await Hive.openBox<CycleData>('cycleBox');
      }
      final cycle = _cycleBox.get(cycleId);
      if (cycle != null) {
        final HiveList<CycleRecord> records = cycle.records ?? HiveList(_cycleBox);
        final index = records
            .indexWhere((r) => isSameDay(r.date, newRecord.date));

        if (index != -1) {
          final existingRecord = records[index];
          existingRecord.bbt = newRecord.bbt ?? existingRecord.bbt;
          existingRecord.testResult = newRecord.testResult != TestResult.none
              ? newRecord.testResult
              : existingRecord.testResult;
          existingRecord.imagePath =
              newRecord.imagePath ?? existingRecord.imagePath;
          // (TODO 8 修正: isTiming も上書き)
          existingRecord.isTiming = newRecord.isTiming; 
        } else {
          records.add(newRecord);
          records.sort((a, b) => a.date.compareTo(b.date));
        }
        cycle.records ??= records;
        await cycle.save();
      } else {
         logger.w("Cycle not found for ID: $cycleId when adding/updating record.");
      }
    } catch (e, stackTrace) {
       logger.e("Error adding or updating record for cycle $cycleId", error: e, stackTrace: stackTrace);
    }
  }

  /// V1 (フロー 4) タイミング記録の追加/更新
  Future<void> addTimingRecord(String cycleId, DateTime date) async {
     try { // DB操作を try-catch
      if (!Hive.isBoxOpen('cycleBox')) {
          _cycleBox = await Hive.openBox<CycleData>('cycleBox');
      }
      final cycle = _cycleBox.get(cycleId);
      if (cycle != null) {
        final HiveList<CycleRecord> records = cycle.records ?? HiveList(_cycleBox);
        final index =
            records.indexWhere((r) => isSameDay(r.date, date));

        if (index != -1) {
          final existingRecord = records[index];
          existingRecord.isTiming = true;
        } else {
          final newRecord = CycleRecord(
            date: date,
            isTiming: true,
          );
          records.add(newRecord);
          records.sort((a, b) => a.date.compareTo(b.date));
        }
        cycle.records ??= records;
        await cycle.save();
      } else {
         logger.w("Cycle not found for ID: $cycleId when adding timing record.");
      }
     } catch (e, stackTrace) {
        logger.e("Error adding timing record for cycle $cycleId", error: e, stackTrace: stackTrace);
     }
  }
}

// --- Helper ---
bool isSameDay(DateTime date1, DateTime date2) {
  return date1.year == date2.year &&
      date1.month == date2.month &&
      date1.day == date2.day;
}

// --- 現在表示中の周期データを監視する Provider ---
final currentCycleDataProvider = Provider<AsyncValue<CycleData?>>((ref) {
  final allCycles = ref.watch(cycleDataProvider);
  final currentIndex = ref.watch(currentCycleIndexProvider);

  if (allCycles.isEmpty) {
    return const AsyncValue.data(null);
  }

  if (currentIndex >= 0 && currentIndex < allCycles.length) {
     final cycle = allCycles[currentIndex];
    return AsyncValue.data(cycle);
  } else {
    logger.w("Warning: currentIndex ($currentIndex) is out of bounds (${allCycles.length}). Falling back to index 0.");
    if (allCycles.isNotEmpty) {
      return AsyncValue.data(allCycles[0]);
    } else {
       return const AsyncValue.data(null);
    }
  }
});

