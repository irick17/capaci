/// タイミング法アプリに関連する数値データ整理表 (V1) に基づく
/// アプリケーションのコアロジックを構成する定数 (Duration版)
class AppLogic {
  /// LHサージ開始から排卵までの平均時間
  static const Duration lhSurgeToOvulation = Duration(hours: 39);

  /// LHピークから排卵までの平均時間
  static const Duration lhPeakToOvulation = Duration(hours: 17);

  /// 精子の受精能獲得に必要な時間 (安全マージン込み)
  static const Duration spermCapacitationTime = Duration(hours: 7);

  /// 卵子の寿命
  static const Duration eggLifespan = Duration(hours: 18);

  /// 精子の寿命
  static const Duration spermLifespan = Duration(days: 4);

  // --- グラフ表示用 ---
  /// 排卵ウィンドウ (卵子の寿命に基づく)
  static const Duration ovulationWindow = eggLifespan;
}

