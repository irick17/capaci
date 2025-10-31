import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/cycle_models.dart';
// *** 修正: 'isSameDay' が競合するため、provider由来のものを hide します ***
import '../providers/cycle_state_provider.dart' hide isSameDay;
import '../utils/logger.dart';
import '../constants/app_strings.dart'; // AppStrings をインポート

// カレンダーに表示するイベントのラッパークラス
class CalendarEvent {
  final DateTime date;
  final String title;
  final Color color;
  final IconData? icon;
  final String? subtitle; // BBTなどの詳細情報用

  CalendarEvent(this.date, this.title, this.color, {this.icon, this.subtitle});

  @override
  String toString() => title;
}

/// 画面遷移図 (P1): カレンダー画面
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  // カレンダーの表示範囲
  final DateTime _firstDay = DateTime.now().subtract(const Duration(days: 365 * 2)); // 過去2年
  final DateTime _lastDay = DateTime.now().add(const Duration(days: 365)); // 未来1年

  // 選択中の日付とイベント
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  Map<DateTime, List<CalendarEvent>> _eventsMap = {};
  List<CalendarEvent> _selectedEvents = [];

  // カレンダーの表示形式 (月、2週間、週)
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _normalizeDate(DateTime.now()); // 時刻情報を除去
    
    // initState の完了後に Provider からデータをロード
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { // mounted チェックを追加
        _loadEventsFromProvider();
      }
    });
  }

  /// 時刻情報を除去した DateTime を返すヘルパー
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Provider から全周期データをロードし、イベントマップを作成する
  void _loadEventsFromProvider() {
    logger.d("CalendarScreen: Loading events from provider...");
    // mounted チェック (build メソッド実行後なので context は利用可能)
    if (!mounted) {
       logger.w("CalendarScreen: _loadEventsFromProvider called but widget not mounted.");
       return;
    }
    
    final allCycles = ref.read(cycleDataProvider); // state から直接リストを取得
    final newEventsMap = <DateTime, List<CalendarEvent>>{};
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    for (final cycle in allCycles) {
      // 生理期間を計算 (仮: 周期開始日から5日間とする)
      // TODO: 生理期間を記録する機能が実装されたら、それを反映する
      for (int i = 0; i < 5; i++) {
        final date = cycle.startDate.add(Duration(days: i));
        final dayKey = _normalizeDate(date);
        final event = CalendarEvent(dayKey, "生理", colorScheme.errorContainer.withAlpha(200), icon: Icons.water_drop_outlined);
        
        newEventsMap.putIfAbsent(dayKey, () => []).add(event);
      }

      // 各記録をイベントとして追加
      if (cycle.records != null) {
        for (final record in cycle.records!) {
          final dayKey = _normalizeDate(record.date);
          newEventsMap.putIfAbsent(dayKey, () => []);

          // LH陽性/強陽性
          if (record.testResult == TestResult.positive || record.testResult == TestResult.strongPositive) {
            final event = CalendarEvent(dayKey, "LH ${record.testResult.name}", colorScheme.primary, icon: Icons.opacity_rounded);
             if (!newEventsMap[dayKey]!.any((e) => e.title.startsWith("LH"))) {
                newEventsMap[dayKey]!.add(event);
             }
          }
          
          // タイミング
          if (record.isTiming) {
             final event = CalendarEvent(dayKey, AppStrings.helpLegendTiming, colorScheme.tertiary, icon: Icons.favorite);
              if (!newEventsMap[dayKey]!.any((e) => e.title == AppStrings.helpLegendTiming)) {
                 newEventsMap[dayKey]!.add(event);
              }
          }
          
           // BBT 記録
           if (record.bbt != null) {
             final event = CalendarEvent(dayKey, "BBT", colorScheme.secondary, icon: Icons.thermostat_outlined, subtitle: "${record.bbt?.toStringAsFixed(2)} ℃");
              if (!newEventsMap[dayKey]!.any((e) => e.title == "BBT")) {
                 newEventsMap[dayKey]!.add(event);
              }
           }
        }
      }
    }
    
    // TODO: 予測排卵日 (黄色の丸) を prediction_logic から取得して newEventsMap に追加する

    setState(() {
      _eventsMap = newEventsMap;
      _selectedEvents = _getEventsForDay(_selectedDay); // 選択日のイベントも更新
    });
     logger.d("CalendarScreen: Events loaded. Map size: ${_eventsMap.length}");
  }

  /// 指定された日付のイベントリストを取得する
  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final dayKey = _normalizeDate(day);
    return _eventsMap[dayKey] ?? [];
  }

  /// 日付が選択されたときの処理
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    final normalizedSelectedDay = _normalizeDate(selectedDay);
    // *** 修正: ここで table_calendar の isSameDay を使用 ***
    if (!isSameDay(_selectedDay, normalizedSelectedDay)) {
      setState(() {
        _selectedDay = normalizedSelectedDay;
        _focusedDay = focusedDay; // フォーカスも選択日に合わせる
        _selectedEvents = _getEventsForDay(normalizedSelectedDay);
      });
       logger.d("Day selected: $_selectedDay, Events: $_selectedEvents");
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("カレンダー"),
        elevation: 0,
        // (任意) AppBar の色をホームと合わせる
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: Column(
        children: [
          TableCalendar<CalendarEvent>(
            locale: 'ja_JP', // 日本語化
            firstDay: _firstDay,
            lastDay: _lastDay,
            focusedDay: _focusedDay,
            // *** 修正: ここで table_calendar の isSameDay を使用 ***
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            startingDayOfWeek: StartingDayOfWeek.sunday, // 日曜始まり
            eventLoader: _getEventsForDay, // 日付ごとのイベントリストを返す関数

            // --- ヘッダーのスタイル ---
            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonVisible: true, // 月/週 切り替えボタン
              formatButtonShowsNext: false,
              formatButtonDecoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              formatButtonTextStyle: TextStyle(color: colorScheme.onSecondaryContainer),
              titleTextStyle: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
              leftChevronIcon: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: colorScheme.onSurface),
              rightChevronIcon: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: colorScheme.onSurface),
            ),
            
            // --- カレンダー本体のスタイル ---
            calendarStyle: CalendarStyle(
              // --- マーカー (イベント) のスタイル ---
              markerSize: 5.0,
              markerMargin: const EdgeInsets.symmetric(horizontal: 0.5),
              markerDecoration: BoxDecoration(
                color: colorScheme.secondary, // デフォルトマーカー色
                shape: BoxShape.circle,
              ),
              // --- 選択日のスタイル ---
              selectedDecoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
              // --- 今日のスタイル ---
              todayDecoration: BoxDecoration(
                color: colorScheme.primaryContainer.withAlpha(100),
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
              // --- 範囲外の日付 ---
              outsideDaysVisible: false, // 月外の日付を非表示
              // --- 週末のスタイル ---
              weekendTextStyle: TextStyle(color: colorScheme.primary.withAlpha(200)),
              // holidayTextStyle: TextStyle(color: Colors.red[600]), // (祝日対応は別途)
            ),

            // --- 日付ごとのマーカーをカスタマイズ ---
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isNotEmpty) {
                  return Positioned(
                    bottom: 4, // マーカーの位置調整
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      // 最大4つまで表示 (重複を避ける)
                      children: events.take(4).map((event) {
                        if (event.icon != null) {
                           // アイコンマーカー
                           return Padding(
                             padding: const EdgeInsets.symmetric(horizontal: 1.5),
                             child: Icon(event.icon, color: event.color, size: 12),
                           );
                        } else {
                           // 通常の点マーカー
                           return Container(
                             width: 6,
                             height: 6,
                             margin: const EdgeInsets.symmetric(horizontal: 1.0),
                             decoration: BoxDecoration(
                               color: event.color,
                               shape: BoxShape.circle,
                             ),
                           );
                        }
                      }).toList(),
                    ),
                  );
                }
                return null;
              },
            ),
            
            onDaySelected: _onDaySelected,
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay; // フォーカス日を更新
            },
          ),
          
          // --- 選択日のイベント一覧 ---
          const Divider(),
          Expanded(
            child: _selectedEvents.isEmpty
              ? Center(
                  child: Text(
                    "選択した日の記録はありません",
                    style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _selectedEvents.length,
                  itemBuilder: (context, index) {
                    final event = _selectedEvents[index];
                    return Card(
                       elevation: 0,
                       color: event.color.withAlpha(50), // イベントカラーを背景に
                       child: ListTile(
                         leading: event.icon != null ? Icon(event.icon, color: event.color, size: 28) : null,
                         title: Text(
                            event.title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                         // BBT などの詳細情報を subtitle に表示
                         subtitle: event.subtitle != null 
                           ? Text(
                               event.subtitle!,
                               style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                             ) 
                           : null,
                       ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

