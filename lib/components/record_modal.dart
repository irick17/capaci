import 'dart:io';

import 'package:flutter/material.dart'; // (★ エラー箇所修正: 'package://' -> 'package:')
// Provider を import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:numberpicker/numberpicker.dart';


import '../constants/app_strings.dart';
import '../models/cycle_models.dart';
// Provider を import
import '../providers/cycle_state_provider.dart';
// logger を import
import '../utils/logger.dart';

/// 画面遷移図 (SUB-02): 記録モーダル
/// V1.1 (3.3) / V1.2 (3.2)
/// P2 必須入力 (基礎体温, 検査結果, 画像メモ) を実行するUI。
// (編集フローのため ConsumerStatefulWidget に変更)
class RecordModal extends ConsumerStatefulWidget {
  // フロー3: 保存時にHomeScreenへデータを渡すコールバック
  final Function(CycleRecord record) onSubmit;
  final DateTime? initialDate; // 過去データ編集用 (タップされた日付など)
  // (編集フローのため cycleId を受け取る)
  final String cycleId;

  const RecordModal({
    super.key,
    required this.onSubmit,
    this.initialDate,
    required this.cycleId, // cycleId を必須にする
  });

  @override
  ConsumerState<RecordModal> createState() => _RecordModalState();
}

// (編集フローのため ConsumerState に変更)
class _RecordModalState extends ConsumerState<RecordModal> {
  late DateTime _selectedDate;
  TestResult _selectedTestResult = TestResult.none;
  int _currentBBTInteger = 36;
  int _currentBBTFirstDecimal = 5;
  XFile? _imageFile; // 新しく選択された画像ファイル
  String? _existingImagePath; // 既存の画像パス
  bool _isLoading = false; // データロード中フラグ

  // (二次導線 TODO 8 のための State)
  bool _alsoRecordTiming = false;


  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    logger.d("RecordModal initState: initialDate=${widget.initialDate}, cycleId=${widget.cycleId}");
    // initState で初期データをロード
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (mounted) {
          logger.d("RecordModal: Loading record for date: $_selectedDate");
         _loadRecordForDate(_selectedDate);
       }
    });
  }

  /// 指定された日付の既存レコードをロードしてUIに反映する
  Future<void> _loadRecordForDate(DateTime date) async {
     logger.d("RecordModal: _loadRecordForDate called for $date");
     if (!mounted) {
        logger.w("_loadRecordForDate skipped: widget not mounted.");
        return;
     }
     setState(() => _isLoading = true);
     logger.d("RecordModal: Set loading state to true.");

     // Use try-catch for provider access
     CycleRecord? existingRecord;
     try {
        // Access provider data safely
        final cycleDataNotifier = ref.read(cycleDataProvider.notifier);
        final cycleData = cycleDataNotifier.getCycleById(widget.cycleId); // Use getCycleById

        if (cycleData != null && cycleData.records != null) {
          logger.d("Cycle data found. Searching for record matching $date in ${cycleData.records!.length} records.");
          try {
            existingRecord = cycleData.records!.firstWhere(
              (r) => isSameDay(r.date, date),
            );
             logger.d("Existing record found: BBT=${existingRecord.bbt}, Test=${existingRecord.testResult}, Timing=${existingRecord.isTiming}");
          } catch (e) {
             logger.d("No existing record found for $date.");
            existingRecord = null;
          }
        } else {
           logger.w("Cycle data or records list is null for cycle ID ${widget.cycleId}.");
        }
     } catch (e, stackTrace) {
        logger.e("Error accessing cycle data in _loadRecordForDate", error: e, stackTrace: stackTrace);
        existingRecord = null; // Ensure null on error
     }


    // デフォルト値にリセット before applying loaded data
    _selectedTestResult = TestResult.none;
    _currentBBTInteger = 36;
    _currentBBTFirstDecimal = 5;
    _imageFile = null;
    _existingImagePath = null;
    _alsoRecordTiming = false;
     logger.d("RecordModal: Reset local state variables.");

    if (existingRecord != null) {
      logger.d("Applying existing record data to state.");
      _selectedTestResult = existingRecord.testResult;
      if (existingRecord.bbt != null) {
        _currentBBTInteger = existingRecord.bbt!.floor();
        // Ensure decimal calculation is robust
        _currentBBTFirstDecimal = ((existingRecord.bbt! - _currentBBTInteger) * 10).round().clamp(0, 9);
        _currentBBTInteger = _currentBBTInteger.clamp(35, 42); // Clamp integer part
         logger.d("  Applied BBT: $_currentBBTInteger.$_currentBBTFirstDecimal");
      } else {
         logger.d("  Existing BBT is null.");
      }
      _existingImagePath = existingRecord.imagePath;
      _alsoRecordTiming = existingRecord.isTiming;
       logger.d("  Applied TestResult: $_selectedTestResult, ImagePath: $_existingImagePath, Timing: $_alsoRecordTiming");
    } else {
       logger.d("No existing record to apply.");
    }

     if (!mounted) {
        logger.w("_loadRecordForDate finishing but widget not mounted.");
        return;
     }
     setState(() => _isLoading = false);
     logger.d("RecordModal: Set loading state to false.");
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Padding(
      // Ensure padding accounts for keyboard
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 16, // Keep top padding
      ),
       // Use AnimatedSwitcher for loading state transition
       child: AnimatedSwitcher(
         duration: const Duration(milliseconds: 200),
         child: _isLoading
           ? Container( // Use container to constrain size during loading
               key: const ValueKey('loading'), // Key for AnimatedSwitcher
               height: 300, // Estimate height or adjust dynamically
               child: const Center(child: CircularProgressIndicator.adaptive()),
             )
           : SingleChildScrollView( // Only scrollable when content is loaded
               key: const ValueKey('content'), // Key for AnimatedSwitcher
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    // M3 Drag Handle
                    Center(
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
                     AppStrings.recordModalTitle,
                     style: textTheme.titleLarge,
                   ),
                   const SizedBox(height: 24),
                   _buildDatePicker(context, textTheme),
                   const SizedBox(height: 16),
                    Text(
                     AppStrings.recordModalBBTLabel,
                     style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                   ),
                    const SizedBox(height: 8),
                   _buildBBTPicker(textTheme, colorScheme),
                   const SizedBox(height: 16),
                   Text(
                     AppStrings.recordModalTestLabel,
                     style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                   ),
                   const SizedBox(height: 8),
                   _buildTestResultSelector(),
                   const SizedBox(height: 16),
                   Text(
                     AppStrings.recordModalImageLabel,
                     style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                   ),
                   const SizedBox(height: 8),
                   _buildImagePicker(context, textTheme, colorScheme),
                   const SizedBox(height: 16),

                   _buildTimingToggle(textTheme, colorScheme),
                   const SizedBox(height: 24),


                   Row(
                     mainAxisAlignment: MainAxisAlignment.end,
                     children: [
                       TextButton(
                         onPressed: () {
                            logger.d("RecordModal Cancel pressed.");
                            Navigator.pop(context);
                         },
                         child: const Text(
                           AppStrings.cancelButton,
                         ),
                       ),
                       const SizedBox(width: 8),
                       FilledButton(
                         onPressed: _submitRecord,
                         child: const Text(
                           AppStrings.saveButton,
                         ),
                       ),
                     ],
                   ),
                   const SizedBox(height: 16), // Bottom padding inside modal
                 ],
               ),
             ),
       ),
    );
  }

  /// V1 (5.1) 日付選択ウィジェット
  Widget _buildDatePicker(BuildContext context, TextTheme textTheme) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_today_outlined),
      // title: const Text(AppStrings.recordModalDateLabel), // Removed for cleaner look
      title: Text(DateFormat.yMMMMEEEEd('ja').format(_selectedDate)), // Show full date as title
      trailing: const Icon(Icons.edit_calendar_outlined), // Indicate tappable
      // trailing: Text(DateFormat.yMMMd('ja_JP').format(_selectedDate)),
      onTap: () async {
         logger.d("Date picker tapped. Current date: $_selectedDate");
        final DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now().subtract(const Duration(days: 90)), // Limit past date range
          lastDate: DateTime.now(), // Cannot record future dates
           locale: const Locale('ja', 'JP'), // Ensure Japanese locale
        );
         logger.d("Date picker closed. Picked date: $pickedDate");
        if (pickedDate != null && !isSameDay(pickedDate, _selectedDate)) { // Check if date actually changed
           logger.d("Date changed to $pickedDate. Reloading record...");
           // Reload data for the newly selected date BEFORE updating the state
           await _loadRecordForDate(pickedDate);
           if (mounted) {
             setState(() {
               _selectedDate = pickedDate;
                logger.d("State updated with new selected date: $_selectedDate");
             });
           }
        } else {
           logger.d("Date not changed or picker cancelled.");
        }
      },
    );
  }

  /// V1 (12:50 PM) 基礎体温入力ウィジェット (標準的な縦回転 Number Picker)
  Widget _buildBBTPicker(TextTheme textTheme, ColorScheme colorScheme) {
    const int intMinValue = 35;
    const int intMaxValue = 42;
    const int decimalMinValue = 0;
    const int decimalMaxValue = 9;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
           color: colorScheme.surfaceContainerHighest.withAlpha(100), // Subtle background
           borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            NumberPicker(
              minValue: intMinValue,
              maxValue: intMaxValue,
              value: _currentBBTInteger,
              step: 1,
              itemHeight: 40,
              itemWidth: 50,
              axis: Axis.vertical,
              onChanged: (value) => setState(() => _currentBBTInteger = value),
              selectedTextStyle: textTheme.headlineMedium?.copyWith(color: colorScheme.primary),
              textStyle: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
               // Add dividers for better visual separation
              // decoration: BoxDecoration(
              //   border: Border.symmetric(
              //     vertical: BorderSide(color: colorScheme.outlineVariant, width: 1),
              //   ),
              // ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: Text(
                '.',
                style: textTheme.headlineMedium?.copyWith(color: colorScheme.primary),
              ),
            ),
            NumberPicker(
              minValue: decimalMinValue,
              maxValue: decimalMaxValue,
              value: _currentBBTFirstDecimal,
              step: 1,
              itemHeight: 40,
              itemWidth: 50,
              axis: Axis.vertical,
              onChanged: (value) => setState(() => _currentBBTFirstDecimal = value),
              selectedTextStyle: textTheme.headlineMedium?.copyWith(color: colorScheme.primary),
              textStyle: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
               // decoration: BoxDecoration(
               //  border: Border.symmetric(
               //    vertical: BorderSide(color: colorScheme.outlineVariant, width: 1),
               //  ),
               //),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                '℃',
                style: textTheme.bodyLarge?.copyWith(color: colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// V1.1 (3.3) / V1.2 (3.3) 検査結果選択ウィジェット
  Widget _buildTestResultSelector() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<TestResult>(
        // Use enum values directly
        segments: const <ButtonSegment<TestResult>>[
          ButtonSegment<TestResult>(
              value: TestResult.negative,
              label: Text(AppStrings.testResultNegative),
              icon: Icon(Icons.remove, size: 18)), // Optional icon
          ButtonSegment<TestResult>(
              value: TestResult.positive,
              label: Text(AppStrings.testResultPositive),
               icon: Icon(Icons.add, size: 18)), // Optional icon
          ButtonSegment<TestResult>(
              value: TestResult.strongPositive,
              label: Text(AppStrings.testResultStrongPositive),
               icon: Icon(Icons.priority_high_rounded, size: 18)), // Optional icon
        ],
        selected: <TestResult>{_selectedTestResult},
        onSelectionChanged: (Set<TestResult> newSelection) {
           logger.d("Test result selection changed: $newSelection");
          setState(() {
            // Allow unselecting back to 'none' if the currently selected button is tapped again
            if (newSelection.isEmpty) {
               _selectedTestResult = TestResult.none;
            } else if (newSelection.length == 1 && newSelection.first == _selectedTestResult){
               // Tapped the same button again, treat as unselect
               _selectedTestResult = TestResult.none;
            }
            else {
               _selectedTestResult = newSelection.first;
            }
             logger.d("  New selectedTestResult state: $_selectedTestResult");
          });
        },
        multiSelectionEnabled: false,
        emptySelectionAllowed: true, // Allow no selection (TestResult.none)
         showSelectedIcon: false, // Don't show checkmark by default
         style: SegmentedButton.styleFrom( // Customize style further if needed
          // visualDensity: VisualDensity.compact,
         ),
      ),
    );
  }

  /// V1.1 (3.3) 画像メモウィジェット (編集対応)
  Widget _buildImagePicker(
      BuildContext context, TextTheme textTheme, ColorScheme colorScheme) {
    // Determine which path to show (newly picked or existing)
    final imagePathToShow = _imageFile?.path ?? _existingImagePath;
    logger.d("Building image picker. Image to show: $imagePathToShow (New: ${_imageFile?.path}, Existing: $_existingImagePath)");

    return Column(
      children: [
        if (imagePathToShow != null) ...[
          // Show Image Preview
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(imagePathToShow), // Create File object from path
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
               // Add error builder for robustness
               errorBuilder: (context, error, stackTrace) {
                   logger.e("Error loading image file: $imagePathToShow", error: error, stackTrace: stackTrace);
                   // Show a placeholder on error
                   return Container(
                     height: 150,
                     width: double.infinity,
                     decoration: BoxDecoration(
                       color: colorScheme.surfaceContainerHighest,
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Center(
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Icon(Icons.broken_image_outlined, color: colorScheme.outline, size: 40),
                           const SizedBox(height: 8),
                           Text("画像表示エラー", style: textTheme.bodySmall?.copyWith(color: colorScheme.outline)),
                         ],
                       ),
                     ),
                   );
                 },
            ),
          ),
          const SizedBox(height: 8),
          // Show "Change/Delete" button
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text(
              AppStrings.recordModalImageChangeButton,
            ),
            onPressed: _showImageSourceActionSheet,
             style: OutlinedButton.styleFrom(
                side: BorderSide(color: colorScheme.outline), // Use outline color
             ),
          ),
        ] else ...[
          // Show "Attach Photo" button
          OutlinedButton.icon(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text(AppStrings.recordModalImageAttachButton),
            onPressed: _showImageSourceActionSheet,
             style: OutlinedButton.styleFrom(
               side: BorderSide(color: colorScheme.outline),
             ),
          ),
        ],
      ],
    );
  }

  /// V1 (11:41 AM) カメラ/ギャラリー選択 ActionSheet (編集対応: 削除追加)
  void _showImageSourceActionSheet() {
     logger.d("Showing image source action sheet.");
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea( // Ensure content is within safe area
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library_outlined), // Use outlined icons
              title: const Text(AppStrings.imageSourceGallery),
              onTap: () {
                logger.d("Gallery option selected.");
                _pickImage(ImageSource.gallery);
                Navigator.of(context).pop(); // Close bottom sheet
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined), // Use outlined icons
              title: const Text(AppStrings.imageSourceCamera),
              onTap: () {
                 logger.d("Camera option selected.");
                _pickImage(ImageSource.camera);
                Navigator.of(context).pop(); // Close bottom sheet
              },
            ),
            // Show delete option only if an image is currently selected/exists
            if (_imageFile != null || _existingImagePath != null) ...[
               const Divider(), // Add a divider
               ListTile(
                 leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                 title: Text(
                   AppStrings.imageDeleteOption,
                   style: TextStyle(color: Theme.of(context).colorScheme.error), // Use error color for text
                  ),
                 onTap: () {
                    logger.d("Delete image option selected.");
                   setState(() {
                     _imageFile = null;
                     _existingImagePath = null; // Clear both potential sources
                      logger.d("Image cleared from state.");
                   });
                   Navigator.of(context).pop(); // Close bottom sheet
                 },
               ),
            ],
          ],
        ),
      ),
    );
  }


  /// V1.1 (3.3) 画像選択ロジック (image_picker)
  Future<void> _pickImage(ImageSource source) async {
     logger.d("Attempting to pick image from $source...");
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        // Optional: Add image quality constraints if needed
        // imageQuality: 80,
        // maxWidth: 1000,
      );
      if (pickedFile != null) {
         logger.d("Image picked successfully: ${pickedFile.path}");
        if (!mounted) {
           logger.w("Image picked but widget not mounted, discarding.");
           return;
        }
        setState(() {
          _imageFile = pickedFile;
          _existingImagePath = null; // Clear existing path if new image is picked
           logger.d("State updated with new image file.");
        });
      } else {
         logger.d("Image picker cancelled by user.");
      }
    } catch (e, stackTrace) {
       logger.e("Error picking image", error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('画像の取得中にエラーが発生しました: ${e.toString()}')),
        );
      }
    }
  }

  /// (二次導線 TODO 8) タイミング記録トグルウィジェット
  Widget _buildTimingToggle(TextTheme textTheme, ColorScheme colorScheme) {
    // Use SwitchListTile for better layout and tap handling
    return SwitchListTile(
        title: Text(
          AppStrings.recordModalTimingToggleLabel,
          style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        value: _alsoRecordTiming,
        onChanged: (bool value) {
          logger.d("Timing toggle changed: $value");
          setState(() {
            _alsoRecordTiming = value;
          });
        },
        secondary: Icon(
          _alsoRecordTiming ? Icons.favorite : Icons.favorite_border, // Change icon based on state
          color: colorScheme.tertiary
          ),
        contentPadding: EdgeInsets.zero, // Remove default padding if needed
        // *** 修正: 'activeColor' (非推奨) を 'activeTrackColor' に変更 ***
        activeTrackColor: colorScheme.tertiary, // Color of the switch track when on
      );
  }

  /// V1 (フロー 3) 記録保存ロジック (編集対応)
  void _submitRecord() {
     logger.d("Submit record called.");
    // Combine integer and decimal parts for BBT
    // (*** 修正: _currentBBTInteger/_currentBBTFirstDecimal は null にならないため、null チェックを削除 ***)
    final double? bbtValue = _currentBBTInteger + (_currentBBTFirstDecimal / 10.0);

    logger.d("Preparing record: Date=$_selectedDate, BBT=$bbtValue, Test=$_selectedTestResult, Image(New)=${_imageFile?.path}, Image(Existing)=$_existingImagePath, Timing=$_alsoRecordTiming");

    final newRecord = CycleRecord(
      date: _selectedDate,
      bbt: bbtValue,
      testResult: _selectedTestResult,
      // Prioritize newly picked image, otherwise use existing path
      imagePath: _imageFile?.path ?? _existingImagePath,
      isTiming: _alsoRecordTiming, // Use the state of the toggle
    );

     logger.d("Calling onSubmit callback with prepared record.");
    widget.onSubmit(newRecord); // Pass the combined/updated record
    Navigator.pop(context); // Close the modal
     logger.d("Record modal closed.");
  }
}

// Helper (already in cycle_state_provider.dart, but keep here for locality if preferred)
// bool isSameDay(DateTime date1, DateTime date2) {
//   return date1.year == date2.year &&
//       date1.month == date2.month &&
//       date1.day == date2.day;
// }

