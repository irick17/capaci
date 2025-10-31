import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../constants/app_strings.dart';
import '../providers/cycle_state_provider.dart';
import '../providers/settings_provider.dart';
// logger を import
import '../utils/logger.dart';

/// 画面遷移図 (SUB-01): オンボーディング画面
/// V1.1 (3.2) / V1 (フロー 1)
/// 初回起動時に表示され、初期情報を入力する。
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  DateTime? _lastPeriodDate;
  int? _averageCycleLength;
  bool _isRegular = true; // デフォルトは規則的

  @override
  void dispose() {
    _pageController.dispose(); // PageController を dispose
    super.dispose();
  }


  /// V1 (フロー 1) / V1.1 (3.2) オンボーディング完了処理
  void _submitOnboarding() {
    logger.d("Attempting to submit onboarding..."); // Log submission attempt
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      logger.d("Form validated and saved. LastPeriod=$_lastPeriodDate, AvgLength=$_averageCycleLength, IsRegular=$_isRegular");

      if (_lastPeriodDate != null && _averageCycleLength != null) {
        // *** 追加ログ: createInitialCycle 呼び出し直前 ***
        logger.d("Calling createInitialCycle with: StartDate=$_lastPeriodDate, AvgLength=$_averageCycleLength, IsRegular=$_isRegular");
        // P3: Riverpod経由で初期データを永続化
        // Use async/await to ensure completion before proceeding (optional but good practice)
        try {
           ref
              .read(cycleDataProvider.notifier)
              .createInitialCycle(_lastPeriodDate!, _averageCycleLength!, _isRegular)
              .then((_) { // Use .then() if you don't need to wait here
                  logger.d("createInitialCycle call completed (async).");
                  // P3: オンボーディング完了状態を保存
                  logger.d("Calling completeOnboarding...");
                  ref.read(onboardingProvider.notifier).completeOnboarding();
                  logger.d("Onboarding marked as complete.");
                  // StartupWrapper が自動的に HomeScreen へ遷移させる
              }).catchError((e, stackTrace) {
                 logger.e("Error during createInitialCycle call", error: e, stackTrace: stackTrace);
                 // Show error feedback to user if needed
                 if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('初期データの保存に失敗しました: $e')),
                    );
                 }
              });

        } catch (e, stackTrace) {
           // Catch synchronous errors if any (less likely here)
           logger.e("Synchronous error calling createInitialCycle or completeOnboarding", error: e, stackTrace: stackTrace);
             if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('エラーが発生しました: $e')),
                );
             }
        }


      } else {
        logger.w("Validation passed but data is null. LastPeriod=$_lastPeriodDate, AvgLength=$_averageCycleLength");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.feedbackError)), // More specific error?
        );
      }
    } else {
       logger.w("Form validation failed.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          children: [
            // V1 (2) スライド 1
            _buildPage(
              context,
              icon: Icons.lightbulb_outline_rounded,
              title: AppStrings.onboardingTitle1,
              body: AppStrings.onboardingBody1,
            ),
            // V1 (2) スライド 2
            _buildPage(
              context,
              icon: Icons.hourglass_bottom_rounded,
              title: AppStrings.onboardingTitle2,
              body: AppStrings.onboardingBody2,
            ),
            // V1 (2) スライド 3 (フォーム)
            _buildFormPage(context, textTheme, colorScheme),
          ],
        ),
      ),
      // ページインジケーターと進む/完了ボタン
      bottomNavigationBar: BottomAppBar(
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ページインジケーター (AnimatedBuilder を使用)
              AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    // Check hasClients before accessing page
                    if (!_pageController.hasClients || _pageController.positions.isEmpty) {
                       return const Row(); // Return empty row if controller not ready
                    }
                    // Use page.round() for simplicity, ensure it handles edge cases if needed
                    final currentPage = _pageController.page?.round() ?? 0;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) {
                        return Container(
                          width: 8.0,
                          height: 8.0,
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: currentPage == index
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                          ),
                        );
                      }),
                    );
                  }),
              // 進む/完了ボタン (AnimatedBuilder を使用)
              AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                   if (!_pageController.hasClients || _pageController.positions.isEmpty) {
                       return const SizedBox.shrink(); // Return empty if controller not ready
                    }
                   final currentPage = _pageController.page?.round() ?? 0;
                  return FilledButton(
                    onPressed: () {
                      if (currentPage < 2) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _submitOnboarding(); // 最終ページで完了処理
                      }
                    },
                    child: Text(currentPage < 2
                        ? AppStrings.nextButton
                        : AppStrings.onboardingCompleteButton),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// スライド1, 2 の共通レイアウト
  Widget _buildPage(BuildContext context,
      {required IconData icon, required String title, required String body}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(title,
              style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(body,
              style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  /// スライド3 (フォーム) のレイアウト
  Widget _buildFormPage(
      BuildContext context, TextTheme textTheme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView( // Allow scrolling for smaller screens
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // V1 (2) タイトル
              Text(AppStrings.onboardingTitle3, style: textTheme.headlineMedium),
              const SizedBox(height: 8),
              // V1 (2) 本文
              Text(AppStrings.onboardingBody3, style: textTheme.bodyMedium),
              const SizedBox(height: 32),

              // V1 (2) 前回の生理開始日
              TextFormField(
                decoration: const InputDecoration(
                  labelText: AppStrings.onboardingFormLabel1,
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  hintText: '日付を選択', // Add hint text
                ),
                readOnly: true,
                // Use controller for better state management with DatePicker
                controller: TextEditingController(
                  text: _lastPeriodDate == null
                      ? ''
                      // Use a consistent format, 'ja_JP' locale might need `intl` initialization
                      : DateFormat.yMMMd('ja').format(_lastPeriodDate!),
                ),
                onTap: () async {
                  final DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _lastPeriodDate ?? DateTime.now(), // Provide initialDate
                    firstDate: DateTime.now().subtract(const Duration(days: 90)),
                    lastDate: DateTime.now(),
                     locale: const Locale('ja', 'JP'), // Set locale for DatePicker
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _lastPeriodDate = pickedDate;
                      // Update controller text manually
                      // (This might require accessing the controller instance if defined outside build)
                      // For simplicity, relying on setState rebuild here.
                    });
                  }
                },
                validator: (value) {
                  if (_lastPeriodDate == null) {
                    return AppStrings.requiredError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // V1 (2) 平均周期
              TextFormField(
                decoration: const InputDecoration(
                  labelText: AppStrings.onboardingFormLabel2,
                  prefixIcon: Icon(Icons.repeat_rounded), // アイコン修正
                  hintText: '例: 28', // Add hint text
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppStrings.requiredError;
                  }
                  final number = int.tryParse(value);
                  if (number == null || number < 10 || number > 60) {
                    return AppStrings.cycleLengthError;
                  }
                  return null;
                },
                onSaved: (value) {
                  // Ensure value is not null before parsing
                  if (value != null) {
                    _averageCycleLength = int.tryParse(value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // V1 (2) 周期の規則性
              Text(AppStrings.onboardingFormLabel3, style: textTheme.bodyLarge),
              // *** 修正: InkWell/Row/Radio (非推奨警告) を RadioListTile に変更 ***
              RadioListTile<bool>(
                title: const Text(AppStrings.onboardingFormOptionA),
                value: true,
                groupValue: _isRegular,
                onChanged: (bool? value) {
                  if (value != null) {
                    setState(() {
                      _isRegular = value;
                    });
                  }
                },
                contentPadding: EdgeInsets.zero, // 余白を削除
              ),
              RadioListTile<bool>(
                title: const Text(AppStrings.onboardingFormOptionB),
                value: false,
                groupValue: _isRegular,
                onChanged: (bool? value) {
                  if (value != null) {
                    setState(() {
                      _isRegular = value;
                    });
                  }
                },
                contentPadding: EdgeInsets.zero, // 余白を削除
              ),
            ],
          ),
        ),
      ),
    );
  }
}

