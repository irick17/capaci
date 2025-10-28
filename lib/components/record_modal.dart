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
    // initState で初期データをロード
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (mounted) {
         _loadRecordForDate(_selectedDate);
       }
    });
  }

  /// 指定された日付の既存レコードをロードしてUIに反映する
  Future<void> _loadRecordForDate(DateTime date) async {
     if (!mounted) return;
     setState(() => _isLoading = true);

     final cycleData = ref.read(cycleDataProvider.notifier).getCycleById(widget.cycleId);
     CycleRecord? existingRecord;

     if (cycleData != null && cycleData.records != null) {
       try {
         existingRecord = cycleData.records!.firstWhere(
           (r) => isSameDay(r.date, date),
         );
       } catch (e) {
         existingRecord = null;
       }
     }

    // デフォルト値にリセット
    _selectedTestResult = TestResult.none;
    _currentBBTInteger = 36;
    _currentBBTFirstDecimal = 5;
    _imageFile = null;
    _existingImagePath = null;
    _alsoRecordTiming = false;

    if (existingRecord != null) {
      _selectedTestResult = existingRecord.testResult;
      if (existingRecord.bbt != null) {
        _currentBBTInteger = existingRecord.bbt!.floor();
        _currentBBTFirstDecimal = ((existingRecord.bbt! - _currentBBTInteger) * 10).round();
        _currentBBTInteger = _currentBBTInteger.clamp(35, 42);
        _currentBBTFirstDecimal = _currentBBTFirstDecimal.clamp(0, 9);
      }
      _existingImagePath = existingRecord.imagePath;
      _alsoRecordTiming = existingRecord.isTiming;
    }

     if (!mounted) return;
     setState(() => _isLoading = false);
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: _isLoading
          ? const Center(child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator.adaptive(),
            ))
          : Column(
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
                      onPressed: () => Navigator.pop(context),
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
                const SizedBox(height: 16),
              ],
            ),
      ),
    );
  }

  /// V1 (5.1) 日付選択ウィジェット
  Widget _buildDatePicker(BuildContext context, TextTheme textTheme) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_today_outlined),
      title: const Text(AppStrings.recordModalDateLabel),
      trailing: Text(DateFormat.yMMMd('ja_JP').format(_selectedDate)),
      onTap: () async {
        final DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now().subtract(const Duration(days: 90)),
          lastDate: DateTime.now(),
        );
        if (pickedDate != null && pickedDate != _selectedDate) {
           await _loadRecordForDate(pickedDate);
           if (mounted) {
             setState(() {
               _selectedDate = pickedDate;
             });
           }
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
              decoration: BoxDecoration(
                border: Border.symmetric(
                  vertical: BorderSide(color: colorScheme.outlineVariant, width: 1),
                ),
              ),
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
               decoration: BoxDecoration(
                border: Border.symmetric(
                  vertical: BorderSide(color: colorScheme.outlineVariant, width: 1),
                ),
              ),
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
        segments: const <ButtonSegment<TestResult>>[
          ButtonSegment<TestResult>(
              value: TestResult.negative,
              label: Text(AppStrings.testResultNegative)),
          ButtonSegment<TestResult>(
              value: TestResult.positive,
              label: Text(AppStrings.testResultPositive)),
          ButtonSegment<TestResult>(
              value: TestResult.strongPositive,
              label: Text(AppStrings.testResultStrongPositive)),
        ],
        selected: <TestResult>{_selectedTestResult},
        onSelectionChanged: (Set<TestResult> newSelection) {
          setState(() {
            _selectedTestResult = newSelection.isNotEmpty ? newSelection.first : TestResult.none;
          });
        },
        multiSelectionEnabled: false,
        emptySelectionAllowed: true,
      ),
    );
  }

  /// V1.1 (3.3) 画像メモウィジェット (編集対応)
  Widget _buildImagePicker(
      BuildContext context, TextTheme textTheme, ColorScheme colorScheme) {
    final imagePathToShow = _imageFile?.path ?? _existingImagePath;

    return Column(
      children: [
        if (imagePathToShow != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(imagePathToShow),
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
               errorBuilder: (context, error, stackTrace) {
                   return Container(
                     height: 150,
                     width: double.infinity,
                     decoration: BoxDecoration(
                       color: colorScheme.surfaceContainerHighest,
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Center(
                       child: Icon(Icons.broken_image_outlined, color: colorScheme.outline),
                     ),
                   );
                 },
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text(
              AppStrings.recordModalImageChangeButton,
            ),
            onPressed: _showImageSourceActionSheet,
          ),
        ] else ...[
          OutlinedButton.icon(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text(AppStrings.recordModalImageAttachButton),
            onPressed: _showImageSourceActionSheet,
          ),
        ],
      ],
    );
  }

  /// V1 (11:41 AM) カメラ/ギャラリー選択 ActionSheet (編集対応: 削除追加)
  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text(AppStrings.imageSourceGallery),
              onTap: () {
                _pickImage(ImageSource.gallery);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text(AppStrings.imageSourceCamera),
              onTap: () {
                _pickImage(ImageSource.camera);
                Navigator.of(context).pop();
              },
            ),
            if (_imageFile != null || _existingImagePath != null)
             ListTile(
               leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
               title: Text(
                 AppStrings.imageDeleteOption,
                 style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
               onTap: () {
                 setState(() {
                   _imageFile = null;
                   _existingImagePath = null;
                 });
                 Navigator.of(context).pop();
               },
             ),
          ],
        ),
      ),
    );
  }


  /// V1.1 (3.3) 画像選択ロジック (image_picker)
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
      );
      if (pickedFile != null) {
        if (!mounted) return;
        setState(() {
          _imageFile = pickedFile;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.feedbackError)),
        );
      }
    }
  }

  /// (二次導線 TODO 8) タイミング記録トグルウィジェット
  Widget _buildTimingToggle(TextTheme textTheme, ColorScheme colorScheme) {
    return SwitchListTile(
        title: Text(
          AppStrings.recordModalTimingToggleLabel,
          style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        value: _alsoRecordTiming,
        onChanged: (bool value) {
          setState(() {
            _alsoRecordTiming = value;
          });
        },
        secondary: Icon(Icons.favorite, color: colorScheme.tertiary),
        contentPadding: EdgeInsets.zero,
      );
  }

  /// V1 (フロー 3) 記録保存ロジック (編集対応)
  void _submitRecord() {
    final double bbtValue = _currentBBTInteger + (_currentBBTFirstDecimal / 10.0);

    // (★ エラー箇所修正: 'existingIsTiming' は不要なので削除)
    // final cycleData = ref.read(currentCycleDataProvider).valueOrNull;
    // bool existingIsTiming = false;
    // CycleRecord? existingRecord;
    // if (cycleData != null && cycleData.records != null) {
    //    try {
    //      existingRecord = cycleData.records!.firstWhere(
    //        (r) => isSameDay(r.date, _selectedDate),
    //      );
    //      existingIsTiming = existingRecord.isTiming;
    //    } catch (e) {
    //      // 見つからない
    //    }
    // }

    final newRecord = CycleRecord(
      date: _selectedDate,
      bbt: bbtValue,
      testResult: _selectedTestResult,
      imagePath: _imageFile?.path ?? _existingImagePath,
      isTiming: _alsoRecordTiming, // (★ エラー箇所修正: _alsoRecordTiming を使用)
    );

    widget.onSubmit(newRecord);
    Navigator.pop(context);
  }
}

