/// UXライティング (マイクロコピー) 定義書 V1 に基づく
/// アプリケーション全体の文言（マイクロコピー）を管理するクラス
class AppStrings {
  // 1. 基本トーン＆マナー (コンセプト)
  static const String appConcept = "焦る妊活から、「賢く待つ」妊活へ。";

  // 2. SUB-01 オンボーディング画面 (P3)
  static const String onboardingTitle1 = "ようこそ";
  static const String onboardingBody1 = "「焦る妊活」から、「賢く待つ」妊活へ。";
  static const String onboardingTitle2 = "精子の「待機時間」を知る";
  static const String onboardingBody2 =
      "大切なのは、排卵の「瞬間」ではありません。排卵時に「準備万端の精子」が待機していることです。このアプリは、その「重なり」を可視化します。";
  static const String onboardingTitle3 = "あなたの周期を教えてください";
  static const String onboardingBody3 =
      "より正確な予測グラフ（安心グラフ）を作成するために、基本的な情報をお伺いします。";
  static const String onboardingFormLabel1 = "前回の生理開始日";
  static const String onboardingFormLabel2 = "あなたの平均的な周期（例：28日）";
  static const String onboardingFormLabel3 = "周期は規則的ですか？";
  static const String onboardingFormOptionA = "はい（規則的）";
  static const String onboardingFormOptionB = "いいえ（不規則/わからない）";
  static const String onboardingCompleteButton = "グラフを作成する";
  // --- オンボーディング仮文言 -> 正式化 ---
  static const String nextButton = '次へ';
  static const String requiredError = '入力してください';
  static const String cycleLengthError = '10～60の範囲で入力してください';


  // 3. GA-01 ホーム (グラフ) 画面
  static const String homeTitle = "安心グラフ"; // V1 (3.1) で仮に設定
  // 3.1. SUB-03 初回ホーム (Empty State)
  static const String emptyStateTitleA = "あなたの「安心グラフ」です";
  static const String emptyStateBodyA =
      "まずは、今日の検査結果を「＋」ボタンから記録してみましょう。予測（点線）が、あなたの記録で「確定（実線）」に変わっていきます。";
  static const String emptyStateCoachMark = "ここから記録";
  static const String emptyStateTitleB = "一緒にグラフを作りましょう";
  static const String emptyStateBodyB =
      "周期が不規則なため、まずはデータを記録することから始めます。「＋」ボタンから今日の検査結果を記録してください。あなたのデータで、グラフが完成していきます。";

  // 3.2. P1 GOLDEN TIME 状態カード
  static const String goldenTimeTitle = "GOLDEN TIME です";
  static const String goldenTimeBody =
      "予測排卵ゾーン（赤帯）と精子の待機時間（青バー）が重なる、最もおすすめの期間です。";

  // 3.3. P0/P3 ヘルプ機能 (モーダル)
  static const String helpModalTitle = "グラフの読み方";
  static const String helpLegendLH = "LHレベル（棒グラフ）";
  static const String helpLegendLHDesc = "排卵検査薬の記録（陰性/陽性/強陽性）";
  static const String helpLegendBBT = "基礎体温（折れ線）";
  static const String helpLegendBBTDesc = "毎朝の基礎体温の記録（任意）";
  static const String helpLegendOvulation = "排卵ゾーン（予測/赤帯）";
  static const String helpLegendOvulationDesc = "排卵が予測される期間";
  static const String helpLegendOvulationConfirmed = "排卵ゾーン (BBT確定)";
  static const String helpLegendOvulationConfirmedDesc = "基礎体温の上昇で排卵が推定された期間";
  static const String helpLegendSperm = "精子の待機バー（青バー）";
  static const String helpLegendSpermDesc = "タイミング後、精子が受精能力を持つ期間";
  // (TODO 4: 予測バーの凡例を追加)
  static const String helpLegendSpermPredicted = "精子の待機バー（予測）";
  static const String helpLegendSpermPredictedDesc = "排卵予測に基づく、推奨タイミング期間";
  static const String helpLegendTiming = "タイミング記録（♡）";
  static const String helpLegendTimingDesc = "タイミングを取った日の記録";
  static const String helpModalConclusion =
      "このグラフの「赤帯」と「青バー」が重なることが、「賢く待つ」状態の目安です。基礎体温（折れ線）が上昇すると、排卵が起こった可能性を示します。";


  // 4. P2 入力アクション (ツールチップ)
  static const String fabTooltip = "今日の記録";
  static const String timingButtonTooltip = "タイミングを記録する";

  // 5. SUB-02 記録モーダル (P2)
  // 5.1. 記録モーダル (「＋」FABから)
  static const String recordModalTitle = "今日の記録";
  static const String recordModalDateLabel = "日付";
  static const String recordModalBBTLabel = "基礎体温（任意）";
  static const String recordModalBBTHint = "例: 36.50";
  static const String recordModalBBTError = "数値を入力してください";
  static const String recordModalTestLabel = "検査結果（任意）";
  static const String testResultNegative = "陰性";
  static const String testResultPositive = "陽性";
  static const String testResultStrongPositive = "強陽性";
  static const String recordModalImageLabel = "画像メモ（任意）";
  static const String recordModalImageAttachButton = "写真を添付する";
  static const String recordModalImageChangeButton = "写真を変更する";
  static const String cancelButton = "キャンセル"; // 共通
  static const String saveButton = "記録する"; // 共通
  static const String recordModalTimingToggleLabel = "（♡）タイミングも記録する";


  // 5.2. タイミング記録モーダル (「♡」ボタンから)
  static const String timingModalTitle = "タイミングの記録";
  static const String timingModalBody =
      "（♡）タイミングを記録しますか？この記録は、グラフの「青バー」を確定させるために使われます。";
  static const String timingRecordedLabel = "記録済み";


  // --- 画像選択肢 (record_modal.dart 仮文言 -> 正式化) ---
  static const String imageSourceGallery = 'ギャラリーから選択';
  static const String imageSourceCamera = 'カメラで撮影';
  static const String imageDeleteOption = '画像を削除';


  // 6. SUB-04 P1フィードバック (トースト/SnackBar)
  static const String feedbackGoldenTime = "GOLDEN TIME が始まりました。";
  static const String feedbackGraphUpdated = "グラフが更新されました。";
  static const String feedbackRecordSaved = "記録しました。";
  static const String feedbackDataMissing = "記録がありませんでした。予測グラフを表示します。";
  static const String feedbackError = "エラーが発生しました。もう一度お試しください。";

}

