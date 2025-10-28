import 'package:flutter/material.dart';
// Provider を import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../constants/app_strings.dart';
// Provider を import
import '../providers/cycle_state_provider.dart';
// models を import (isSameDayのため)
import '../models/cycle_models.dart';


/// 画面遷移図 (SUB-02): タイミング記録専用モーダル
/// V1 (5.2) ユーザー要件変更に基づき新設
/// P2 タイミング記録を実行するUI。
// (編集フローのため ConsumerStatefulWidget に変更)
class TimingRecordModal extends ConsumerStatefulWidget {
  // フロー4: 保存時にHomeScreenへ日付を渡すコールバック
  final Function(DateTime date) onSubmit;
  final DateTime? initialDate; // 過去データ編集用
  // (編集フローのため cycleId を受け取る)
  final String cycleId;

  const TimingRecordModal({
    super.key,
    required this.onSubmit,
    this.initialDate,
    required this.cycleId, // cycleId を必須にする
  });

  @override
  ConsumerState<TimingRecordModal> createState() => _TimingRecordModalState();
}

// (編集フローのため ConsumerState に変更)
class _TimingRecordModalState extends ConsumerState<TimingRecordModal> {
  late DateTime _selectedDate;
  bool _isAlreadyRecorded = false; // 選択日に記録があるか
  bool _isLoading = false; // データロード中フラグ

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
    // (TODO 削除: 編集フローは _loadRecordForDate で実装済み)
  }

 /// 指定された日付の既存タイミング記録をロードする
  Future<void> _loadRecordForDate(DateTime date) async {
     if (!mounted) return;
     setState(() => _isLoading = true);

     final cycleData = ref.read(cycleDataProvider.notifier).getCycleById(widget.cycleId);
     CycleRecord? existingRecord;
     _isAlreadyRecorded = false; // デフォルトは未記録

     if (cycleData != null && cycleData.records != null) {
       try {
         existingRecord = cycleData.records!.firstWhere(
           (r) => isSameDay(r.date, date),
         );
         if (existingRecord.isTiming) {
            _isAlreadyRecorded = true; // タイミング記録があれば true
         }
       } catch (e) {
         // 見つからなかった場合
       }
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
                AppStrings.timingModalTitle,
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.timingModalBody,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              // V1 (5.1) 日付選択
              _buildDatePicker(context, textTheme),
              const SizedBox(height: 24),

              // V1 (5.2) 保存/キャンセルボタン
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
                    onPressed: _isAlreadyRecorded ? null : _submitTiming,
                    child: Text(
                      _isAlreadyRecorded ? AppStrings.timingRecordedLabel : AppStrings.saveButton,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16), // 下部の余白
            ],
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
          firstDate: DateTime.now().subtract(const Duration(days: 90)), // 過去90日
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

  /// V1 (フロー 4) タイミング記録保存ロジック
  void _submitTiming() {
    widget.onSubmit(_selectedDate);
    Navigator.pop(context); // モーダルを閉じる
  }
}

