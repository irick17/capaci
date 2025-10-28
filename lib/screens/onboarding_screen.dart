import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../constants/app_strings.dart';
import '../providers/cycle_state_provider.dart';
import '../providers/settings_provider.dart';

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
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_lastPeriodDate != null && _averageCycleLength != null) {
        // P3: Riverpod経由で初期データを永続化
        ref
            .read(cycleDataProvider.notifier)
            .createInitialCycle(_lastPeriodDate!, _averageCycleLength!, _isRegular);

        // P3: オンボーディング完了状態を保存
        ref.read(onboardingProvider.notifier).completeOnboarding();

        // StartupWrapper が自動的に HomeScreen へ遷移させる
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.feedbackError)),
        );
      }
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
                    if (!_pageController.hasClients || _pageController.page == null) {
                       return const Row();
                    }
                    final currentPage = _pageController.page!.round();
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
                  if (!_pageController.hasClients || _pageController.page == null) {
                       return const SizedBox.shrink();
                  }
                  final currentPage = _pageController.page!.round();
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
              ),
              readOnly: true,
              controller: TextEditingController(
                text: _lastPeriodDate == null
                    ? ''
                    : DateFormat.yMMMd('ja_JP').format(_lastPeriodDate!),
              ),
              onTap: () async {
                final DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 90)),
                  lastDate: DateTime.now(),
                );
                if (pickedDate != null) {
                  setState(() {
                    _lastPeriodDate = pickedDate;
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
                _averageCycleLength = int.tryParse(value!);
              },
            ),
            const SizedBox(height: 16),

            // V1 (2) 周期の規則性
            Text(AppStrings.onboardingFormLabel3, style: textTheme.bodyLarge),
            // (警告修正: RadioListTile -> ListTile + Radio)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(AppStrings.onboardingFormOptionA),
              leading: Radio<bool>(
                value: true,
                groupValue: _isRegular,
                onChanged: (bool? value) {
                  if (value != null) {
                    setState(() {
                      _isRegular = value;
                    });
                  }
                },
              ),
              onTap: () => setState(() => _isRegular = true), // ListTile タップでも変更
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(AppStrings.onboardingFormOptionB),
              leading: Radio<bool>(
                value: false,
                groupValue: _isRegular,
                onChanged: (bool? value) {
                   if (value != null) {
                    setState(() {
                      _isRegular = value;
                    });
                  }
                },
              ),
               onTap: () => setState(() => _isRegular = false), // ListTile タップでも変更
            ),
          ],
        ),
      ),
    );
  }
}

