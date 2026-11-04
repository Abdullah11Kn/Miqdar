import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../app_controller.dart';
import '../l10n/strings.dart';
import '../models/body_profile.dart';
import '../models/nutrition.dart';
import '../theme.dart';
import 'screens.dart';
import 'widgets/charts_and_gauges.dart';

/// The required profile and the goal it suggests. As a gate it leads into the app;
/// with [editing] it was opened from Profile and goes back there.
class BodyProfileScreen extends StatefulWidget {
  const BodyProfileScreen({super.key, this.firstRun = false, this.editing = false});

  /// A brand new user has no goals of their own to keep.
  final bool firstRun;
  final bool editing;

  @override
  State<BodyProfileScreen> createState() => _BodyProfileScreenState();
}

class _BodyProfileScreenState extends State<BodyProfileScreen> {
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _target = TextEditingController();

  BodySex? _sex;
  ActivityLevel? _activity;
  WeightGoal? _goal;
  double? _pace;
  bool? _pregnant;

  bool _showErrors = false;
  bool _loaded = false;
  bool _saving = false;
  BodyProfile? _profile;
  GoalSuggestion? _suggestion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final saved = MiqdarScope.of(context).bodyProfile;
    if (saved == null) return;
    _sex = saved.sex;
    _age.text = '${saved.ageOn(DateTime.now())}';
    _height.text = _plain(saved.heightCm);
    _weight.text = _plain(saved.weightKg);
    _activity = saved.activity;
    _goal = saved.goal;
    _target.text = saved.targetWeightKg == null ? '' : _plain(saved.targetWeightKg!);
    _pace = saved.weeklyPaceKg;
    _pregnant = saved.sex == BodySex.female ? saved.pregnantOrBreastfeeding : null;
  }

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    _target.dispose();
    super.dispose();
  }

  String _plain(double value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  /// Accepts Arabic digits and a decimal comma, as Arabic keyboards type them.
  double? _number(TextEditingController field) {
    var text = field.text.trim().replaceAll('٫', '.').replaceAll(',', '.');
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    for (var i = 0; i < arabic.length; i++) {
      text = text.replaceAll(arabic[i], '$i');
    }
    return double.tryParse(text);
  }

  bool get _changingWeight => _goal == WeightGoal.lose || _goal == WeightGoal.gain;

  BodyProfile? _buildProfile(DateTime now) {
    final age = _number(_age);
    final height = _number(_height);
    final weight = _number(_weight);
    final sex = _sex;
    final activity = _activity;
    final goal = _goal;
    if (sex == null || age == null || height == null || weight == null || activity == null || goal == null) {
      return null;
    }
    if (sex == BodySex.female && _pregnant == null) return null;
    return BodyProfile(
      sex: sex,
      birthYear: now.year - age.round(),
      heightCm: height,
      weightKg: weight,
      activity: activity,
      goal: goal,
      targetWeightKg: _changingWeight ? _number(_target) : null,
      weeklyPaceKg: _changingWeight ? _pace : null,
      pregnantOrBreastfeeding: sex == BodySex.female && _pregnant == true,
    );
  }

  void _calculate(MiqdarController controller) {
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final profile = _buildProfile(now);
    if (profile == null || profile.problems(now).isNotEmpty) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() {
      _profile = profile;
      _suggestion = suggestGoals(profile, controller.goals, now);
    });
  }

  void _leave() {
    if (widget.editing) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
    }
  }

  /// [goals] null keeps the goals the user already has.
  Future<void> _finish(MiqdarController controller, NutritionGoals? goals) async {
    setState(() => _saving = true);
    await controller.saveBodyProfile(_profile!);
    if (goals != null) {
      await controller.updateGoals(goals);
      await controller.rememberGoalWeight(_profile!.weightKg);
    }
    if (mounted) _leave();
  }

  String? _errorFor(BodyProfileProblem problem, S s, {required bool empty}) {
    if (!_showErrors) return null;
    final profile = _buildProfile(DateTime.now());
    final hasProblem = empty || (profile?.problems(DateTime.now()).contains(problem) ?? false);
    if (!hasProblem) return null;
    return switch (problem) {
      BodyProfileProblem.age => s.tr('Enter an age from 5 to 110', 'أدخل عمراً من 5 إلى 110'),
      BodyProfileProblem.height => s.tr('Enter a height from 100 to 250 cm', 'أدخل طولاً من 100 إلى 250 سم'),
      BodyProfileProblem.weight => s.tr('Enter a weight from 20 to 300 kg', 'أدخل وزناً من 20 إلى 300 كغ'),
      BodyProfileProblem.target => _goal == WeightGoal.lose
          ? s.tr('Your target must be below your current weight', 'يجب أن يكون هدفك أقل من وزنك الحالي')
          : s.tr('Your target must be above your current weight', 'يجب أن يكون هدفك أعلى من وزنك الحالي'),
      BodyProfileProblem.targetUnderweight => s.tr(
          'This target is underweight for your height, so the app does not offer it',
          'هذا الهدف أقل من الوزن الصحي لطولك، لذا لا يقدمه التطبيق',
        ),
      BodyProfileProblem.pace => s.tr('Choose a weekly pace', 'اختر معدلاً أسبوعياً'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    final showingResult = _suggestion != null;

    return PopScope(
      canPop: widget.editing && !showingResult,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && showingResult) setState(() => _suggestion = null);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: widget.editing,
          leading: showingResult ? BackButton(onPressed: () => setState(() => _suggestion = null)) : null,
          title: Text(
            showingResult
                ? s.tr('Your Daily Goal', 'هدفك اليومي')
                : s.tr('Body Profile', 'بياناتك الجسدية'),
          ),
          actions: [
            // Test builds only: release builds must answer the profile.
            if (!kReleaseMode && !widget.editing && !showingResult)
              TextButton(
                onPressed: () {
                  controller.skipBodyProfile();
                  _leave();
                },
                child: Text(s.tr('Skip', 'تخطي')),
              ),
          ],
        ),
        bottomNavigationBar: showingResult
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    onPressed: () => _calculate(controller),
                    child: Text(s.tr('Calculate My Goal', 'احسب هدفي')),
                  ),
                ),
              ),
        body: SafeArea(child: showingResult ? _result(controller, s) : _form(s)),
      ),
    );
  }

  Widget _form(S s) {
    final c = context.mq;
    Widget missing(bool isMissing) => _showErrors && isMissing
        ? Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(s.tr('Please choose one', 'يرجى اختيار واحد'),
                style: MiqdarType.caption.copyWith(color: c.danger)),
          )
        : const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Text(
          s.tr(
            'Your daily goal is calculated from these answers. They stay on this phone and are not sent to Gemini.',
            'يُحسب هدفك اليومي من هذه الإجابات. تبقى على هذا الهاتف ولا تُرسل إلى Gemini.',
          ),
          style: MiqdarType.body.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: 16),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(s.tr('Sex', 'الجنس')),
              _chips<BodySex>(
                values: BodySex.values,
                selected: _sex,
                label: (v) => v == BodySex.male ? s.tr('Male', 'ذكر') : s.tr('Female', 'أنثى'),
                onSelected: (v) => setState(() => _sex = v),
              ),
              missing(_sex == null),
              if (_sex == BodySex.female) ...[
                const SizedBox(height: 16),
                _label(s.tr('Pregnant or breastfeeding?', 'هل أنتِ حامل أو مرضع؟')),
                _chips<bool>(
                  values: const [false, true],
                  selected: _pregnant,
                  label: (v) => v ? s.tr('Yes', 'نعم') : s.tr('No', 'لا'),
                  onSelected: (v) => setState(() => _pregnant = v),
                ),
                missing(_pregnant == null),
              ],
              const SizedBox(height: 16),
              _numberField(
                _age,
                s.tr('Age', 'العمر'),
                s.tr('years', 'سنة'),
                _errorFor(BodyProfileProblem.age, s, empty: _number(_age) == null),
              ),
              const SizedBox(height: 12),
              _numberField(
                _height,
                s.tr('Height', 'الطول'),
                s.tr('cm', 'سم'),
                _errorFor(BodyProfileProblem.height, s, empty: _number(_height) == null),
              ),
              const SizedBox(height: 12),
              _numberField(
                _weight,
                s.tr('Weight', 'الوزن'),
                s.tr('kg', 'كغ'),
                _errorFor(BodyProfileProblem.weight, s, empty: _number(_weight) == null),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(s.tr('How active are you?', 'ما مستوى نشاطك؟')),
              _chips<ActivityLevel>(
                values: ActivityLevel.values,
                selected: _activity,
                label: (v) => switch (v) {
                  ActivityLevel.sedentary => s.tr('Mostly sitting', 'جلوس معظم الوقت'),
                  ActivityLevel.light => s.tr('Light, 1 to 3 days a week', 'خفيف، 1 إلى 3 أيام أسبوعياً'),
                  ActivityLevel.moderate => s.tr('Moderate, 3 to 5 days', 'متوسط، 3 إلى 5 أيام'),
                  ActivityLevel.active => s.tr('Active, 6 to 7 days', 'نشط، 6 إلى 7 أيام'),
                  ActivityLevel.veryActive => s.tr('Very active or physical job', 'نشط جداً أو عمل بدني'),
                },
                onSelected: (v) => setState(() => _activity = v),
              ),
              missing(_activity == null),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(s.tr('What is your goal?', 'ما هدفك؟')),
              _chips<WeightGoal>(
                values: WeightGoal.values,
                selected: _goal,
                label: (v) => switch (v) {
                  WeightGoal.lose => s.tr('Lose weight', 'خسارة الوزن'),
                  WeightGoal.maintain => s.tr('Keep my weight', 'الحفاظ على الوزن'),
                  WeightGoal.gain => s.tr('Gain weight', 'زيادة الوزن'),
                },
                onSelected: (v) => setState(() => _goal = v),
              ),
              missing(_goal == null),
              if (_changingWeight) ...[
                const SizedBox(height: 16),
                _numberField(
                  _target,
                  s.tr('Target weight', 'الوزن المستهدف'),
                  s.tr('kg', 'كغ'),
                  _targetError(s),
                ),
                const SizedBox(height: 16),
                _label(s.tr('Weekly pace', 'المعدل الأسبوعي')),
                _chips<double>(
                  values: const [0.25, 0.5],
                  selected: _pace,
                  label: (v) => s.tr('$v kg a week', '$v كغ في الأسبوع'),
                  onSelected: (v) => setState(() => _pace = v),
                ),
                if (_errorFor(BodyProfileProblem.pace, s, empty: _pace == null) case final error?)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(error, style: MiqdarType.caption.copyWith(color: c.danger)),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String? _targetError(S s) {
    if (!_showErrors) return null;
    return _errorFor(BodyProfileProblem.target, s, empty: _number(_target) == null) ??
        _errorFor(BodyProfileProblem.targetUnderweight, s, empty: false);
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: MiqdarType.bodyStrong.copyWith(color: context.mq.ink)),
      );

  Widget _chips<T>({
    required List<T> values,
    required T? selected,
    required String Function(T) label,
    required ValueChanged<T> onSelected,
  }) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final value in values)
            ChoiceChip(
              label: Text(label(value)),
              selected: selected == value,
              onSelected: (_) => onSelected(value),
            ),
        ],
      );

  Widget _numberField(TextEditingController field, String label, String unit, String? error) => TextField(
        controller: field,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
        onChanged: (_) {
          if (_showErrors) setState(() {});
        },
        decoration: InputDecoration(labelText: label, suffixText: unit, errorText: error, errorMaxLines: 2),
      );

  Widget _result(MiqdarController controller, S s) {
    final c = context.mq;
    final suggestion = _suggestion!;
    final goals = suggestion.goals;

    if (goals == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(MiqdarIcons.help, color: c.accentInk),
                const SizedBox(height: 10),
                Text(
                  s.tr('Ask a doctor or dietitian', 'استشر طبيباً أو أخصائي تغذية'),
                  style: MiqdarType.titleCard.copyWith(color: c.ink),
                ),
                const SizedBox(height: 6),
                Text(
                  suggestion.block == GoalBlock.underAge
                      ? s.tr(
                          'The calculation is meant for adults, so the app does not suggest a calorie goal under 18.',
                          'هذا الحساب مخصص للبالغين، لذا لا يقترح التطبيق هدفاً للسعرات لمن هم دون 18 عاماً.',
                        )
                      : s.tr(
                          'The calculation does not fit pregnancy or breastfeeding, so the app does not suggest a calorie goal.',
                          'هذا الحساب لا يناسب الحمل أو الرضاعة، لذا لا يقترح التطبيق هدفاً للسعرات.',
                        ),
                  style: MiqdarType.body.copyWith(color: c.inkMuted),
                ),
                const SizedBox(height: 6),
                Text(
                  s.tr(
                    'You can still record your meals, and set goals by hand in Daily Goals if you are given any.',
                    'يمكنك تسجيل وجباتك، وتحديد أهدافك يدوياً في الأهداف اليومية إذا نُصحت بها.',
                  ),
                  style: MiqdarType.body.copyWith(color: c.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: _saving
                ? null
                // A new user has no goals yet, so the default target must not stand in for one.
                : () => _finish(controller, widget.firstRun ? controller.goals.copyWith(trackingOnly: true) : null),
            child: Text(s.tr('Continue', 'متابعة')),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(s.tr('Eat about', 'تناول حوالي'), style: MiqdarType.body.copyWith(color: c.inkMuted)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(999)),
                    child: Text(s.tr('Estimate', 'تقدير'), style: MiqdarType.caption.copyWith(color: c.accentInk)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${goals.calories.toStringAsFixed(0)} ${s.tr('kcal a day', 'سعرة في اليوم')}',
                style: MiqdarType.numberLg.copyWith(color: c.ink),
              ),
              const SizedBox(height: 16),
              _goalRow(s.tr('Protein', 'البروتين'), goals.protein, c.nProtein, s),
              _goalRow(s.tr('Carbs', 'الكربوهيدرات'), goals.carbohydrates, c.nCarbs, s),
              _goalRow(s.tr('Fat', 'الدهون'), goals.fat, c.nFat, s),
            ],
          ),
        ),
        if (suggestion.limitedToMinimum) ...[
          const SizedBox(height: 12),
          SurfaceCard(
            color: c.accentSoft,
            child: Text(
              s.tr(
                'Your plan would go below the safe minimum, so the goal is set at the minimum. A slower pace may suit you better.',
                'خطتك ستنزل عن الحد الأدنى الآمن، لذا ضُبط الهدف عند الحد الأدنى. قد يناسبك معدل أبطأ.',
              ),
              style: MiqdarType.body.copyWith(color: c.ink),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          s.tr(
            'Estimated from your answers with the Mifflin-St Jeor formula. It is not medical advice. You can change any number in Daily Goals.',
            'تقدير من إجاباتك باستخدام معادلة ميفلين-سانت جيور، وليس نصيحة طبية. يمكنك تغيير أي رقم في الأهداف اليومية.',
          ),
          style: MiqdarType.caption.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: _saving ? null : () => _finish(controller, goals),
          child: Text(s.tr('Use These Goals', 'استخدم هذه الأهداف')),
        ),
        if (!widget.firstRun) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _saving ? null : () => _finish(controller, null),
            child: Text(
              s.tr(
                'Keep My Current Goals (${controller.goals.calories.toStringAsFixed(0)} kcal)',
                'أبقِ أهدافي الحالية (${controller.goals.calories.toStringAsFixed(0)} سعرة)',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _goalRow(String label, double grams, Color mark, S s) {
    final c = context.mq;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: mark, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: MiqdarType.body.copyWith(color: c.ink))),
          Text(
            '${grams.toStringAsFixed(0)} ${s.unitG}',
            style: MiqdarType.bodyStrong.copyWith(color: c.ink),
          ),
        ],
      ),
    );
  }
}
