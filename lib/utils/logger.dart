import 'package:logger/logger.dart';

// アプリ全体で使用するロガーインスタンス
final logger = Logger(
  printer: PrettyPrinter(
      methodCount: 1, // 表示するスタックトレースの深さ
      errorMethodCount: 5, // エラー時のスタックトレースの深さ
      lineLength: 100, // 1行の最大長
      colors: true, // 色付けする
      printEmojis: true, // 絵文字を表示する
      // *** 修正: 'printTime' (非推奨) を 'dateTimeFormat' に変更 ***
      dateTimeFormat: DateTimeFormat.none // 時刻を表示しない (必要な場合は DateTimeFormat.shortTime など)
      ),
);
