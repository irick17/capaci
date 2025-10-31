import 'package:flutter_riverpod/flutter_riverpod.dart'; // (★ 修正: 'package.flutter_riverpod' -> 'package:flutter_riverpod')
import 'package:hive_flutter/hive_flutter.dart';
// Remove unused rxdart import
// import 'package:rxdart/rxdart.dart';
import 'dart:async';

import '../models/cycle_models.dart';
// logger を import
import '../utils/logger.dart';

// --- P1 (3.1.2) GOLDEN TIME 状態 ---
final goldenTimeProvider = StateProvider<bool>((ref) {
  // Add log to check initial state
  logger.d("goldenTimeProvider initialized: false");
  return false;
});

// --- P3 (3.1.4) 過去周期の確認 ---
final currentCycleIndexProvider =
    StateNotifierProvider<CurrentCycleIndexNotifier, int>((ref) {
  // Add log to check initial state
  logger.d("currentCycleIndexProvider initialized: 0");
  return CurrentCycleIndexNotifier();
});

class CurrentCycleIndexNotifier extends StateNotifier<int> {
  CurrentCycleIndexNotifier() : super(0);

  void setPageIndex(int index) {
    // Prevent setting negative index
    if (index < 0) {
       logger.w("Attempted to set negative cycle index: $index. Keeping state $state.");
       return;
    }
    logger.d("Setting current cycle index to: $index"); // Log index change
    state = index;
  }
}

// *** P1: ハイライトアニメーション用 (フロー3 B) ***
final highlightedDateProvider = StateProvider<DateTime?>((ref) => null);

/// P1: ハイライトアニメーションを管理する Notifier
final highlightAnimationProvider = StateNotifierProvider<HighlightAnimationNotifier, bool>((ref) {
  return HighlightAnimationNotifier(ref);
});

class HighlightAnimationNotifier extends StateNotifier<bool> {
  final Ref _ref;
  Timer? _blinkTimer;

  HighlightAnimationNotifier(this._ref) : super(false);

  /// 指定した日付のハイライト明滅を開始する
  void startHighlight(DateTime date, {Duration duration = const Duration(milliseconds: 1500), Duration interval = const Duration(milliseconds: 300)}) {
    logger.d("Starting highlight animation for $date");
    _blinkTimer?.cancel(); // 既存のタイマーをキャンセル

    final int blinkCount = (duration.inMilliseconds / interval.inMilliseconds).floor();
    int currentBlink = 0;

    _blinkTimer = Timer.periodic(interval, (timer) {
      if (currentBlink >= blinkCount) {
        timer.cancel();
        _ref.read(highlightedDateProvider.notifier).state = null; // 確実にハイライトを消す
        state = false;
        logger.d("Highlight animation finished for $date");
      } else {
        final bool isCurrentlyHighlighted = _ref.read(highlightedDateProvider.notifier).state != null;
        _ref.read(highlightedDateProvider.notifier).state = isCurrentlyHighlighted ? null : date;
        state = !isCurrentlyHighlighted; // state も連動させる (bool)
      }
      currentBlink++;
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
  }
}


// --- P0/P1/P2 データ管理 ---
final cycleDataProvider =
    StateNotifierProvider<CycleDataNotifier, List<CycleData>>((ref) {
  logger.d("cycleDataProvider initializing..."); // Log provider initialization
  final notifier = CycleDataNotifier(ref);
  ref.listen(currentCycleIndexProvider, (_, nextIndex) {
     // (★ 修正: logger.v -> logger.t)
     logger.t("Cycle index changed to $nextIndex, resetting goldenTimeProvider.");
     // Check if notifier state is empty before resetting, maybe not needed if cycle changes
     // final cycles = ref.read(cycleDataProvider);
     // if (cycles.isNotEmpty && nextIndex < cycles.length) {
       ref.read(goldenTimeProvider.notifier).state = false;
     // }
  });
  return notifier;
});

class CycleDataNotifier extends StateNotifier<List<CycleData>> {
  final Ref ref;
  // Make _cycleBox potentially nullable until _init completes
  Box<CycleData>? _cycleBox;
  StreamSubscription? _boxSubscription;

  CycleDataNotifier(this.ref) : super([]) {
    _init();
  }

  // Ensure _init completes before other methods rely on _cycleBox
  Future<void> _init() async {
    try { // _init 全体を try-catch
      logger.d("CycleDataNotifier _init started.");
      // Ensure box is opened before accessing
      // Use try-catch specifically for opening the box
      try {
        if (!Hive.isBoxOpen('cycleBox')) {
           logger.d("cycleBox is not open, opening...");
           _cycleBox = await Hive.openBox<CycleData>('cycleBox');
           logger.d("cycleBox opened successfully.");
        } else {
           logger.d("cycleBox is already open.");
           _cycleBox = Hive.box<CycleData>('cycleBox'); // Get reference
        }
      } catch (e, stackTrace) {
         logger.e("!!! CRITICAL: Failed to open cycleBox !!!", error: e, stackTrace: stackTrace);
         // Handle critical failure - maybe set an error state?
         if (mounted) state = []; // Set state to empty on failure
         return; // Stop initialization if box fails to open
      }


      logger.d("cycleBox opened. Contains ${_cycleBox!.length} items."); // Use ! after successful open
      // *** 追加ログ: Boxの中身を具体的に表示 ***
      _cycleBox!.toMap().forEach((key, value) {
        // (★ 修正: logger.v -> logger.t)
        logger.t("  Hive Key: $key, StartDate: ${value.startDate}, Records: ${value.records?.length ?? 'null'}");
      });
      // *** 追加ログここまで ***

      // Initial load before listening to stream
      final initialCycles = _cycleBox!.values.toList() // Use !
        ..sort((a, b) => b.startDate.compareTo(a.startDate)); // Sort descending by start date
      logger.d("Initial load from cycleBox: ${initialCycles.length} cycles found and sorted.");
      if (mounted) {
         state = initialCycles;
         // Ensure index is reset only if data exists and state changes significantly
         if (initialCycles.isNotEmpty) {
           logger.d("Setting initial cycle index to 0 after load.");
           // Use Future.microtask to avoid calling during build phase
           Future.microtask(() {
              // Check mounted again inside microtask
              if (mounted) {
                 // Check current index before setting to avoid unnecessary triggers
                 if (ref.read(currentCycleIndexProvider) != 0) {
                    ref.read(currentCycleIndexProvider.notifier).setPageIndex(0);
                 }
              }
           });
         } else {
            logger.d("Initial load resulted in 0 cycles.");
            // Make sure index is 0 if list is empty
             Future.microtask(() {
               if (mounted && ref.read(currentCycleIndexProvider) != 0) {
                  ref.read(currentCycleIndexProvider.notifier).setPageIndex(0);
               }
             });
         }
      }

      // Listen directly to the box watch stream
      // Add error handling to the listen stream
      _boxSubscription = _cycleBox!.watch().listen((event) { // Use !
        logger.d("cycleBox watch event received: key=${event.key}, deleted=${event.deleted}, value=${event.value}"); // Log event value too
        // Add try-catch within the listener as well
        try {
          final updatedCycles = _cycleBox!.values.toList() // Use !
            ..sort((a, b) => b.startDate.compareTo(a.startDate)); // Sort descending
          logger.d("cycleBox listener updated state with ${updatedCycles.length} cycles.");

          if (mounted) {
            state = updatedCycles;
            // Reset index only if necessary (e.g., current index becomes invalid)
            final currentIndex = ref.read(currentCycleIndexProvider);
             logger.d("Current index before potential reset: $currentIndex");
            if (updatedCycles.isNotEmpty && (currentIndex >= updatedCycles.length || currentIndex < 0)) {
              logger.d("Resetting cycle index to 0 due to state update (index out of bounds).");
              // Use Future.microtask to avoid issues during build/notification phase
              Future.microtask(() {
                 if (mounted) {
                    ref.read(currentCycleIndexProvider.notifier).setPageIndex(0);
                 }
              });
            } else if (updatedCycles.isEmpty && currentIndex != 0) {
              logger.d("Resetting cycle index to 0 as cycles list is empty.");
              Future.microtask(() {
                 if (mounted) {
                   ref.read(currentCycleIndexProvider.notifier).setPageIndex(0);
                 }
              });
            } else {
               logger.d("Cycle index remains $currentIndex after update.");
            }
          }
        } catch (e, stackTrace) {
           logger.e("Error processing cycleBox watch event", error: e, stackTrace: stackTrace);
        }
      }, onError: (e, stackTrace) { // onError で stackTrace も受け取る
        logger.e("Error listening to Hive box stream", error: e, stackTrace: stackTrace);
         // Consider how to handle stream errors - maybe retry listening?
      });


       logger.d("CycleDataNotifier _init finished successfully.");
    } catch (e, stackTrace) { // Catch other potential errors in _init
       logger.e("Error during CycleDataNotifier _init", error: e, stackTrace: stackTrace);
       if (mounted) state = []; // Ensure state is empty on error
    }
  }

  @override
  void dispose() {
    logger.d("CycleDataNotifier disposing."); // Log disposal
    _boxSubscription?.cancel();
    // Do not close the box here, let Hive manage it or close on app exit
    // _cycleBox?.close(); // Avoid closing if box is shared or needed elsewhere
    super.dispose();
  }

  // Helper to ensure box is open before use in methods
  Future<Box<CycleData>?> _getOpenBox() async {
     if (_cycleBox != null && _cycleBox!.isOpen) {
        return _cycleBox!;
     }
     try {
        if (!Hive.isBoxOpen('cycleBox')) {
           logger.w("cycleBox was closed or null. Attempting to reopen...");
           _cycleBox = await Hive.openBox<CycleData>('cycleBox');
           logger.d("cycleBox reopened successfully.");
           return _cycleBox!;
        } else {
           _cycleBox = Hive.box<CycleData>('cycleBox'); // Get reference if open but null locally
           logger.d("cycleBox was open but local ref was null. Got reference.");
           return _cycleBox!;
        }
     } catch (e, stackTrace) {
       logger.e("!!! CRITICAL: Failed to get or reopen cycleBox !!!", error: e, stackTrace: stackTrace);
       return null; // Return null if opening fails
     }
  }


  /// 指定された ID の CycleData を取得する
  /// (★ 修正: logger.v -> logger.t)
  CycleData? getCycleById(String cycleId) {
    logger.t("Attempting to get CycleData by ID: $cycleId"); // Log ID lookup
    // Use the state as the primary source of truth after initialization
    try {
      // Find in current state first
      final cycleFromState = state.firstWhere((cycle) => cycle.id == cycleId);
      logger.d("CycleData found in provider state for ID: $cycleId");
      return cycleFromState;
    } catch (e) {
      // If not in state (shouldn't happen if state reflects box), log and potentially check box as fallback
      logger.w("CycleData not found in provider state for ID: $cycleId. Checking box as fallback.", error: e);
      try {
        if (_cycleBox != null && _cycleBox!.isOpen) {
          final cycleFromBox = _cycleBox!.get(cycleId);
          if (cycleFromBox != null) {
             logger.w("CycleData found in box but not state for ID: $cycleId. State might be inconsistent.");
          } else {
             logger.w("CycleData not found in box either for ID: $cycleId");
          }
          return cycleFromBox;
        } else {
          logger.e("Cannot check box in getCycleById: Box is closed or null.");
          return null;
        }
      } catch (boxError, stackTrace) {
         logger.e("Error accessing Hive box fallback in getCycleById", error: boxError, stackTrace: stackTrace);
         return null;
      }
    }
  }


  /// V1 (フロー 1) オンボーディングからの初期周期作成
  Future<void> createInitialCycle(
      DateTime startDate, int averageLength, bool isRegular) async {
    logger.d("Attempting to create initial cycle: StartDate=$startDate, AvgLength=$averageLength, IsRegular=$isRegular"); // Log creation attempt
    final box = await _getOpenBox(); // Ensure box is open
    if (box == null) {
       logger.e("Cannot create initial cycle: Failed to get open box.");
       // Optionally throw an error or notify UI
       throw Exception("Database error: Could not access cycle data.");
    }

    try {
      final newCycle = CycleData(
        // Use a more robust ID, e.g., combine timestamp with a random element or use UUID package
        id: 'cycle_${DateTime.now().millisecondsSinceEpoch}_${(1000 + DateTime.now().microsecond % 9000)}', // Added microsecond part
        startDate: startDate,
        averageCycleLength: averageLength,
        isRegular: isRegular,
        // (修正) HiveListを初期化する際はBoxインスタンスを渡す
        records: HiveList(box), // Pass the obtained box instance
      );
      logger.d("Attempting to put new cycle with ID: ${newCycle.id}");
      await box.put(newCycle.id, newCycle); // Use the obtained box instance
      logger.d("Initial cycle created successfully with ID: ${newCycle.id}. Box now contains ${box.length} items.");
       // *** 追加ログ: 保存後のBoxの中身を確認 ***
      box.toMap().forEach((key, value) {
        // (★ 修正: logger.v -> logger.t)
        logger.t("  After Create - Hive Key: $key, StartDate: ${value.startDate}");
      });
      // *** 追加ログここまで ***
      // Note: The watch listener should update the state automatically.
      // If immediate update is critical, you might manually update state here,
      // but it's generally better to rely on the listener.
      // state = [newCycle, ...state]..sort((a, b) => b.startDate.compareTo(a.startDate)); // Example manual update


    } catch (e, stackTrace) {
       logger.e("Error creating initial cycle in Hive", error: e, stackTrace: stackTrace);
       // Rethrow or handle UI feedback if needed
        throw Exception("Failed to save initial cycle data: $e");
    }
  }

  /// V1 (フロー 3) 検査記録または基礎体温記録の追加/更新
  Future<void> addOrUpdateRecord(String cycleId, CycleRecord newRecord) async {
    // (修正) 不要な波括弧を削除
    logger.d("Attempting Add/Update record for cycle $cycleId: Date=${newRecord.date}, BBT=${newRecord.bbt}, Test=${newRecord.testResult}, Timing=${newRecord.isTiming}"); // Log update attempt
    final box = await _getOpenBox(); // Ensure box is open
    if (box == null) {
       logger.e("Cannot add/update record: Failed to get open box.");
       throw Exception("Database error: Could not access cycle data.");
    }

    try {
      final cycle = box.get(cycleId);
      if (cycle != null) {
        // Ensure records list exists
        final HiveList<CycleRecord> records = cycle.records ?? HiveList(box);
        if (cycle.records == null) {
            cycle.records = records;
            logger.d("Initialized cycle.records HiveList for cycle $cycleId during add/update.");
        }

        final index = records
            .indexWhere((r) => isSameDay(r.date, newRecord.date));

        CycleRecord recordToSave; // Record that will be added or is being updated
        if (index != -1) {
          logger.d("Existing record found at index $index for date ${newRecord.date}, updating.");
          recordToSave = records[index]; // Get reference to existing record
          // Update fields
          // (修正) BBT が null の場合も上書きする
          recordToSave.bbt = newRecord.bbt;
          if (newRecord.testResult != TestResult.none) {
              recordToSave.testResult = newRecord.testResult;
          } else {
             // If newRecord is 'none', keep existing value unless explicitly clearing?
             // (修正) 'none' の場合は 'none' で上書きする（選択解除を反映）
             recordToSave.testResult = TestResult.none;
             logger.d("New test result is 'none', setting to none.");
          }
          recordToSave.imagePath = newRecord.imagePath; // Allows clearing with null
          recordToSave.isTiming = newRecord.isTiming; // Update timing status

          // ** Crucial for HiveObject updates within HiveList **
          // While saving the parent (`cycle.save()`) often works, explicitly saving
          // the modified HiveObject (`recordToSave.save()`) is safer, especially
          // if the HiveList relationship isn't perfectly managed.
          // However, let's stick to saving the parent first, as it's simpler.
          // await recordToSave.save(); // Alternative if cycle.save() doesn't work reliably
          // (修正) 不要な波括弧を削除
          logger.d("Updated existing record: Date=${recordToSave.date}, BBT=${recordToSave.bbt}, Test=${recordToSave.testResult}, Timing=${recordToSave.isTiming}");

        } else {
          logger.d("No existing record found for date ${newRecord.date}, adding new record.");
          // Create a new record instance. IMPORTANT: It must be added to the Box/List *before* associating with the parent CycleData if using HiveList relations implicitly
          // Let's create it directly without adding to a separate box first.
          recordToSave = CycleRecord(
            date: newRecord.date,
            bbt: newRecord.bbt,
            testResult: newRecord.testResult,
            imagePath: newRecord.imagePath,
            isTiming: newRecord.isTiming,
          );
          // Add the new record to the list
          records.add(recordToSave);
          // Ensure the cycle object knows about the list if it was just created
          cycle.records = records;
          // (修正) 不要な波括弧を削除
          logger.d("Added new record: Date=${recordToSave.date}, BBT=${recordToSave.bbt}, Test=${recordToSave.testResult}, Timing=${recordToSave.isTiming}");
          // Sorting: Rely on read-time sorting in the provider for consistency
        }

        logger.d("Saving cycle ${cycle.id} after record update/add. Records count now: ${records.length}");
        await cycle.save(); // Save the CycleData object
        logger.d("Cycle ${cycle.id} saved successfully after record update/add.");

      } else {
         logger.w("Cycle not found for ID: $cycleId when adding/updating record.");
         throw Exception("Target cycle not found."); // Throw error if cycle doesn't exist
      }
    } catch (e, stackTrace) {
       logger.e("Error adding or updating record for cycle $cycleId", error: e, stackTrace: stackTrace);
       // Rethrow or provide feedback
        throw Exception("Failed to save record: $e");
    }
  }

  /// V1 (フロー 4) タイミング記録の追加/更新
  Future<void> addTimingRecord(String cycleId, DateTime date) async {
     logger.d("Attempting Add/Update timing record for cycle $cycleId on date $date"); // Log timing add attempt
     final box = await _getOpenBox(); // Ensure box is open
     if (box == null) {
       logger.e("Cannot add/update timing record: Failed to get open box.");
       throw Exception("Database error: Could not access cycle data.");
     }

     try {
      final cycle = box.get(cycleId);
      if (cycle != null) {
         // Ensure records list exists
        final HiveList<CycleRecord> records = cycle.records ?? HiveList(box);
        if (cycle.records == null) {
            cycle.records = records;
            logger.d("Initialized cycle.records HiveList for cycle $cycleId during timing add.");
        }

        final index =
            records.indexWhere((r) => isSameDay(r.date, date));

        CycleRecord recordToSave;
        if (index != -1) {
          logger.d("Existing record found for timing date $date, setting isTiming=true.");
          recordToSave = records[index];
          // Only update isTiming, leave other fields as they were
          recordToSave.isTiming = true;
          // (修正) 不要な波括弧を削除
          logger.d("Updated existing record for timing: Date=${recordToSave.date}, isTiming=${recordToSave.isTiming}");
          // See note in addOrUpdateRecord about saving HiveObject vs parent
          // await recordToSave.save(); // Alternative
        } else {
          logger.d("No existing record found for timing date $date, adding new record with isTiming=true.");
          recordToSave = CycleRecord(
            date: date,
            isTiming: true, // Only timing is recorded
            testResult: TestResult.none, // Ensure default is set
            bbt: null, // Ensure default is set
          );
          records.add(recordToSave);
           cycle.records = records; // Ensure parent knows list if just created
           // (修正) 不要な波括弧を削除
           logger.d("Added new record for timing: Date=${recordToSave.date}, isTiming=${recordToSave.isTiming}");
           // Rely on read-time sorting
        }

        logger.d("Saving cycle ${cycle.id} after timing record update/add. Records count now: ${records.length}");
        await cycle.save(); // Save the parent CycleData
        logger.d("Cycle ${cycle.id} saved successfully after timing.");

      } else {
         logger.w("Cycle not found for ID: $cycleId when adding timing record.");
          throw Exception("Target cycle not found.");
      }
     } catch (e, stackTrace) {
        logger.e("Error adding timing record for cycle $cycleId", error: e, stackTrace: stackTrace);
        // Rethrow or provide feedback
         throw Exception("Failed to save timing record: $e");
     }
  }
}

// --- Helper ---
bool isSameDay(DateTime date1, DateTime date2) {
  // (修正) 不要なnullチェックを削除
  // if (date1 == null || date2 == null) return false;
  return date1.year == date2.year &&
      date1.month == date2.month &&
      date1.day == date2.day;
}

// --- 現在表示中の周期データを監視する Provider ---
final currentCycleDataProvider = Provider<AsyncValue<CycleData?>>((ref) {
  // (★ 修正: logger.v -> logger.t)
  logger.t("currentCycleDataProvider executing..."); // Log provider execution
  // (修正) List<CycleData> を直接watchする
  final allCycles = ref.watch(cycleDataProvider);
  // (★ 修正: logger.v -> logger.t)
  logger.t("cycleDataProvider state updated. Total cycles: ${allCycles.length}");
  final currentIndex = ref.watch(currentCycleIndexProvider);
  // (★ 修正: logger.v -> logger.t)
  logger.t("Current cycle index: $currentIndex");

  // .when を使わずに List を直接処理する
  if (allCycles.isEmpty) {
    logger.d("No cycles available in cycleDataProvider state.");
    return const AsyncValue.data(null);
  }

  // Ensure index is valid before accessing
  if (currentIndex >= 0 && currentIndex < allCycles.length) {
      final cycle = allCycles[currentIndex];
      logger.d("Returning cycle data for index $currentIndex, ID: ${cycle.id}, StartDate: ${cycle.startDate}");
      // Log records count for debugging
      // (★ 修正: logger.v -> logger.t)
      logger.t("Cycle ID: ${cycle.id} has ${cycle.records?.length ?? 0} records.");
      // *** 追加ログ: records の中身も一部表示 ***
      // cycle.records?.take(5).forEach((rec) => logger.t("  Record: ${rec.date}, BBT=${rec.bbt}, Test=${rec.testResult}, Timing=${rec.isTiming}"));
      // *** 追加ログここまで ***
     return AsyncValue.data(cycle);
   } else {
     // This case should ideally not happen if index is managed correctly, but handle defensively
     logger.w("Warning: currentIndex ($currentIndex) is out of bounds (${allCycles.length}). Attempting to return index 0.");
     if (allCycles.isNotEmpty) {
       final cycle = allCycles[0];
       logger.d("Falling back to cycle data for index 0, ID: ${cycle.id}, StartDate: ${cycle.startDate}");
       // (★ 修正: logger.v -> logger.t)
       logger.t("Fallback Cycle ID: ${cycle.id} has ${cycle.records?.length ?? 0} records.");
       // Correct the index state if it was out of bounds
       Future.microtask(() {
          // Check mounted is not possible here, rely on read/notifier check
          if (ref.read(currentCycleIndexProvider) != 0) {
             ref.read(currentCycleIndexProvider.notifier).setPageIndex(0);
          }
       });
       return AsyncValue.data(cycle);
     } else {
        logger.e("Fallback failed: No cycles available even for index 0.");
        return const AsyncValue.data(null); // Return null data if truly empty
     }
   }
});