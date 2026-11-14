import 'package:flutter/material.dart';

import '../app.dart';
import '../app_controller.dart';
import '../l10n/strings.dart';
import '../models/nutrition.dart';
import '../theme.dart';
import 'screens.dart';
import 'diabetes_widgets.dart';
import 'widgets/charts_and_gauges.dart';

/// Server text may be English only, so Arabic screens show it only when it is translated.
bool hasArabicText(String text) => RegExp(r'[؀-ۿ]').hasMatch(text);

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    final isDark = context.mq.isDark;
    final account = controller.account;

    return ListView(
      padding: EdgeInsets.fromLTRB(0, 8, 0, MediaQuery.paddingOf(context).bottom + 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(s.navProfile, style: Theme.of(context).textTheme.headlineSmall),
        ),

        // The name's first letter, the name and where the diary lives. A hairline closes it.
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 24),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.mq.border))),
          child: Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: context.mq.primary,
                foregroundColor: context.mq.onPrimary,
                child: Text(
                  account.localizedName(s.isAr).characters.first.toUpperCase(),
                  style: MiqdarType.titleCard.copyWith(fontSize: 30, height: 36 / 30, color: context.mq.onPrimary),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.localizedName(s.isAr),
                      style: MiqdarType.titleSection.copyWith(fontSize: 28, height: 34 / 28, color: context.mq.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.isDemo
                          ? s.tr('Demo with sample data', 'عرض تجريبي ببيانات نموذجية')
                          : s.tr('Your diary stays on this phone', 'سجلك محفوظ على هذا الهاتف'),
                      style: MiqdarType.body.copyWith(fontSize: 14, color: context.mq.inkMuted),
                    ),
                  ],
                ),
              ),
              RoundIconButton(
                plain: true,
                tooltip: s.tr('Change your name', 'تغيير الاسم'),
                onPressed: () => _showEditNameSheet(context, controller),
                icon: MiqdarIcons.edit,
              ),
            ],
          ),
        ),

        MiqdarListGroup(
          title: s.tr('Appearance', 'المظهر'),
          children: [
            MiqdarSettingsRow(
              icon: MiqdarIcons.language,
              title: s.tr('Language', 'اللغة'),
              value: s.isAr ? 'العربية' : 'English',
              onTap: controller.toggleLocale,
            ),
            MiqdarSettingsRow(
              icon: isDark ? MiqdarIcons.darkMode : MiqdarIcons.lightMode,
              title: s.tr('Dark Mode', 'المظهر الداكن'),
              toggle: isDark,
              onTap: controller.toggleThemeMode,
            ),
            if (MediaQuery.sizeOf(context).width >= 780)
              MiqdarSettingsRow(
                icon: MiqdarIcons.devices,
                title: s.tr('Phone-sized layout', 'عرض بحجم الهاتف'),
                toggle: controller.forceMobileFrameOnDesktop,
                onTap: controller.toggleViewportFrame,
              ),
          ],
        ),

        MiqdarListGroup(
          title: s.tr('Settings', 'الإعدادات'),
          last: !account.isDemo,
          children: [
            if (!controller.account.isDemo)
              MiqdarSettingsRow(
                icon: MiqdarIcons.person,
                title: s.tr('Body Profile', 'بياناتك الجسدية'),
                subtitle: controller.bodyProfile == null
                    ? s.tr('Not filled in yet', 'لم تُملأ بعد')
                    : s.tr(
                        '${controller.bodyProfile!.heightCm.toStringAsFixed(0)} cm, ${controller.bodyProfile!.weightKg.toStringAsFixed(0)} kg',
                        '${controller.bodyProfile!.heightCm.toStringAsFixed(0)} سم، ${controller.bodyProfile!.weightKg.toStringAsFixed(0)} كغ',
                      ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BodyProfileScreen(editing: true)),
                ),
              ),
            MiqdarSettingsRow(
              icon: MiqdarIcons.trackChanges,
              title: s.tr('Daily Goals', 'الأهداف اليومية'),
              subtitle: controller.goals.trackingOnly
                  ? s.tr('Tracking without goals', 'تتبع بدون أهداف')
                  : s.tr(
                      '${controller.goals.calories.toStringAsFixed(0)} kcal a day',
                      '${controller.goals.calories.toStringAsFixed(0)} سعرة في اليوم',
                    ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GoalsScreen()),
              ),
            ),
            MiqdarSettingsRow(
              icon: MiqdarIcons.restaurantMenu,
              title: s.tr('Food Preferences', 'تفضيلات الطعام'),
              subtitle: s.tr('Allergies, foods to avoid, meal ideas', 'الحساسية، أطعمة تتجنبها، أفكار للوجبات'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MealSuggestionsScreen(showPreferences: true)),
              ),
            ),
            if (!controller.account.isDemo)
              MiqdarSettingsRow(
                icon: MiqdarIcons.notifications,
                title: s.tr('Meal Reminders', 'تذكير الوجبات'),
                value: !controller.reminderSettings.enabled
                    ? s.tr('Off', 'متوقف')
                    : controller.ramadanMode
                        ? s.tr('Paused for Ramadan', 'متوقف في رمضان')
                        : s.tr('On', 'مفعّل'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RemindersScreen()),
                ),
              ),
            MiqdarSettingsRow(
              icon: MiqdarIcons.calendarMonth,
              title: s.tr('Ramadan Mode', 'وضع رمضان'),
              subtitle: s.tr('Iftar, Suhoor and Snack; the day runs noon to noon', 'إفطار وسحور ووجبة خفيفة، واليوم من الظهر إلى الظهر'),
              toggle: controller.ramadanMode,
              onTap: () => controller.setRamadanMode(!controller.ramadanMode),
            ),
            MiqdarSettingsRow(
              icon: MiqdarIcons.scale,
              title: s.navDevices,
              value: controller.scaleDevice.online ? s.tr('Connected', 'متصل') : s.tr('Not connected', 'غير متصل'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DeviceSettingsScreen()),
              ),
            ),
            MiqdarSettingsRow(
              icon: MiqdarIcons.shield,
              title: s.tr('Privacy & Data', 'الخصوصية والبيانات'),
              subtitle: s.tr('Where your data goes, export, delete', 'أين تذهب بياناتك، التصدير، الحذف'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyAndDataScreen()),
              ),
            ),
          ],
        ),
        if (account.isDemo)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: OutlinedButton.icon(
              onPressed: () async {
                final navigator = Navigator.of(context);
                await controller.exitDemo();
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (_) => false,
                );
              },
              icon: const Icon(MiqdarIcons.logout),
              label: Text(s.tr('Exit Demo', 'الخروج من العرض التجريبي')),
            ),
          ),
      ],
    );
  }

  void _showEditNameSheet(BuildContext context, MiqdarController controller) {
    final s = S.of(context);
    final account = controller.account;
    final nameCtrl = TextEditingController(
      text: account.hasPersonalName ? account.localizedName(s.isAr) : '',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(22, 22, 22, MediaQuery.viewInsetsOf(ctx).bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.tr('Your name', 'اسمك'),
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: s.tr('What should we call you?', 'بماذا نناديك؟'),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                controller.updateAccountProfile(
                  displayName: name.isEmpty ? UserAccount.defaultName : name,
                  displayNameAr: name.isEmpty ? UserAccount.defaultNameAr : name,
                );
                Navigator.of(ctx).pop();
              },
              child: Text(s.tr('Save', 'حفظ')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Meal ideas, and the preferences that shape them.
class MealSuggestionsScreen extends StatefulWidget {
  const MealSuggestionsScreen({super.key, this.showPreferences = false});

  /// Opened from Food Preferences rather than from the ideas on the Home screen.
  final bool showPreferences;

  @override
  State<MealSuggestionsScreen> createState() => _MealSuggestionsScreenState();
}

class _MealSuggestionsScreenState extends State<MealSuggestionsScreen> {
  HealthProfile? draft;
  late final TextEditingController allergensCtrl = TextEditingController();
  late final TextEditingController dislikesCtrl = TextEditingController();
  bool initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    final profile = MiqdarScope.of(context).healthProfile;
    draft = profile;
    allergensCtrl.text = profile.allergens.join(', ');
    dislikesCtrl.text = profile.dislikedFoods.join(', ');
    initialized = true;
  }

  @override
  void dispose() {
    allergensCtrl.dispose();
    dislikesCtrl.dispose();
    super.dispose();
  }

  List<String> _csv(String value) => value
      .split(RegExp('[,،]'))
      .map((item) => item.trim().toLowerCase())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();

  void _toggleCondition(String value, bool selected) {
    final values = [...draft!.conditions];
    selected ? values.add(value) : values.remove(value);
    setState(() => draft = draft!.copyWith(conditions: values.toSet().toList()));
  }

  void _togglePreference(String value, bool selected) {
    final values = [...draft!.dietaryPreferences];
    selected ? values.add(value) : values.remove(value);
    setState(() => draft = draft!.copyWith(dietaryPreferences: values.toSet().toList()));
  }

  Future<void> _save(MiqdarController controller, S s) async {
    final messenger = ScaffoldMessenger.of(context);
    final value = (draft ?? controller.healthProfile).copyWith(
      allergens: _csv(allergensCtrl.text),
      dislikedFoods: _csv(dislikesCtrl.text),
    );
    setState(() => draft = value);
    await controller.updateHealthProfile(value);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(s.tr('Preferences saved', 'تم حفظ التفضيلات')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    final profile = draft ?? controller.healthProfile;

    final conditionLabels = <String, String>{
      'weight_management': s.tr('Managing my weight', 'إدارة الوزن'),
      'diabetes': s.tr('Watching sugar', 'الانتباه للسكر'),
      'hypertension': s.tr('Watching salt', 'الانتباه للملح'),
      'high_cholesterol': s.tr('Watching fat', 'الانتباه للدهون'),
      'kidney_disease': s.tr('Kidney diet', 'حمية الكلى'),
    };
    final preferenceLabels = <String, String>{
      'vegetarian': s.tr('Vegetarian', 'نباتي'),
      'vegan': s.tr('Vegan', 'نباتي صرف'),
    };
    final disclaimer = controller.recommendationDisclaimer;

    return Scaffold(
      appBar: AppBar(title: Text(s.mealIdeasTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                SurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: DiabetesQuestion(controller: controller),
                ),
                if (controller.diabetes.hasDiabetes) ...[
                  const SizedBox(height: 12),
                  CarbPlanCard(controller: controller),
                  const SizedBox(height: 12),
                  SugarLimitCard(controller: controller),
                  const SizedBox(height: 12),
                  GlucoseUnitCard(controller: controller),
                ],
                const SizedBox(height: 12),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: widget.showPreferences,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                      leading: Icon(MiqdarIcons.tune, color: context.mq.ink),
                      title: Text(
                        s.tr('Your preferences', 'تفضيلاتك'),
                        style: TextStyle(fontWeight: FontWeight.w600, color: context.mq.ink),
                      ),
                      children: [
                        Text(
                          s.tr('I am', 'أنا'),
                          style: TextStyle(fontWeight: FontWeight.w600, color: context.mq.ink),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...conditionLabels.entries.map((entry) => ChoiceChip(
                                  label: Text(entry.value),
                                  selected: profile.conditions.contains(entry.key),
                                  onSelected: (selected) => _toggleCondition(entry.key, selected),
                                )),
                            ...preferenceLabels.entries.map((entry) => ChoiceChip(
                                  label: Text(entry.value),
                                  selected: profile.dietaryPreferences.contains(entry.key),
                                  onSelected: (selected) => _togglePreference(entry.key, selected),
                                )),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: allergensCtrl,
                          decoration: InputDecoration(
                            labelText: s.tr('Allergies', 'الحساسية'),
                            hintText: s.tr('e.g. nuts, dairy, fish', 'مثال: مكسرات، ألبان، سمك'),
                            prefixIcon: const Icon(MiqdarIcons.noFood),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: dislikesCtrl,
                          decoration: InputDecoration(
                            labelText: s.tr('Foods to avoid', 'أطعمة تتجنبها'),
                            hintText: s.tr('e.g. tomato, egg', 'مثال: طماطم، بيض'),
                            prefixIcon: const Icon(MiqdarIcons.removeCircle),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: controller.recommendationsBusy ? null : () => _save(controller, s),
                          child: Text(s.tr('Save', 'حفظ')),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if (controller.recommendationsBusy && controller.mealSuggestions.isEmpty)
                  const LinearProgressIndicator()
                else if (controller.mealSuggestions.isEmpty)
                  SurfaceCard(
                    child: Text(
                      s.tr(
                        'No ideas fit your preferences. Try removing something you excluded.',
                        'لا توجد أفكار تناسب تفضيلاتك. جرّب إزالة بعض ما استبعدته.',
                      ),
                    ),
                  )
                else
                  ...controller.mealSuggestions.map(
                    (suggestion) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SuggestionCardWidget(suggestion: suggestion),
                    ),
                  ),
                if (disclaimer.isNotEmpty && (!s.isAr || hasArabicText(disclaimer))) ...[
                  const SizedBox(height: 6),
                  Text(disclaimer, style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The scale's true state and how to reach it.
class DeviceSettingsScreen extends StatefulWidget {
  const DeviceSettingsScreen({super.key});

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  bool checking = false;

  Future<void> _tryAgain(MiqdarController controller) async {
    setState(() => checking = true);
    await controller.connectToScale(controller.apiService.baseUrl);
    if (mounted) setState(() => checking = false);
  }

  Future<void> _zero(MiqdarController controller, S s) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await controller.tareScale();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          ok
              ? s.tr('Scale set to 0 g', 'تم تصفير الميزان إلى 0 غ')
              : s.tr('The scale did not respond', 'لم يستجب الميزان'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    final scale = controller.scaleDevice;


    return Scaffold(
      appBar: AppBar(title: Text(s.navDevices)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SurfaceCard(
                  child: Column(
                    children: [
                      ScaleStatusLabel(state: scale.visualState, shortConnected: true),
                      if (scale.online) ...[
                        const SizedBox(height: 10),
                        Text(
                          '${scale.effectiveWeightG.toStringAsFixed(0)} ${s.unitG}',
                          textDirection: TextDirection.ltr,
                          style: MiqdarType.numberXl.copyWith(color: context.mq.ink),
                        ),
                        Text(
                          scale.isStable
                              ? s.tr('Steady', 'مستقر')
                              : s.tr('Settling…', 'جارٍ الثبات…'),
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonal(
                            onPressed: controller.taringScale ? null : () => _zero(controller, s),
                            child: Text(s.tareScale),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.tr(
                            'Reading looks wrong? Leave only the empty plate on the scale, then zero it.',
                            'القراءة غير صحيحة؟ اترك الطبق الفارغ فقط على الميزان ثم صفّره.',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                if (!scale.online) ...[
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          s.tr('To connect', 'للاتصال'),
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: context.mq.ink),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.tr(
                            '1. Turn on the scale and wait about a minute.\n'
                            '2. Tap the Miqdar icon on its screen.\n'
                            '3. Keep this phone on the same Wi-Fi as the scale.',
                            '1. شغّل الميزان وانتظر دقيقة تقريباً.\n'
                            '2. اضغط أيقونة مقدار على شاشته.\n'
                            '3. أبقِ هذا الهاتف على شبكة Wi-Fi نفسها.',
                          ),
                          style: const TextStyle(height: 1.6),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: checking ? null : () => _tryAgain(controller),
                          icon: checking
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(MiqdarIcons.refresh),
                          label: Text(s.tr('Try Again', 'حاول مجدداً')),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                SurfaceCard(
                  padding: const EdgeInsets.all(16),
                  onTap: () => showScaleAddressDialog(context, controller),
                  child: Row(
                    children: [
                      Icon(MiqdarIcons.link, color: context.mq.ink),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.tr('Scale address', 'عنوان الميزان'),
                              style: TextStyle(fontWeight: FontWeight.w600, color: context.mq.ink),
                            ),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                controller.apiService.baseUrl,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        s.tr('Change', 'تغيير'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: context.mq.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (scale.online) ...[
                  const SizedBox(height: 14),
                  SurfaceCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(MiqdarIcons.photoCamera, color: context.mq.ink),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                scale.autoCapture
                                    ? s.tr('Automatic capture is on', 'الالتقاط التلقائي مفعّل')
                                    : s.tr('Automatic capture is off', 'الالتقاط التلقائي متوقف'),
                                style: TextStyle(fontWeight: FontWeight.w600, color: context.mq.ink),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                scale.autoCapture
                                    ? s.tr(
                                        'The scale takes the photo by itself when food settles.',
                                        'يلتقط الميزان الصورة تلقائياً عند ثبات الطعام.',
                                      )
                                    : s.tr(
                                        'Press Capture in Add Meal or on the scale.',
                                        'اضغط التقاط في إضافة وجبة أو على الميزان.',
                                      ),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What happens to the user's data, in plain words, with real export and delete.
class PrivacyAndDataScreen extends StatelessWidget {
  const PrivacyAndDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.tr('Privacy & Data', 'الخصوصية والبيانات'))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MiqdarSectionHeader(title: s.tr('Where your data goes', 'أين تذهب بياناتك')),
                      _PrivacyRow(
                        icon: MiqdarIcons.phoneIphone,
                        title: s.tr('This phone', 'هذا الهاتف'),
                        body: s.tr(
                          'Your meals, meal photos, goals, preferences, body profile and diabetes answers are stored here. There is no Miqdar account or cloud copy, so removing the app removes them. Your body profile and diabetes answers are not sent to Gemini.',
                          'تُحفظ هنا وجباتك وصورها وأهدافك وتفضيلاتك وبياناتك الجسدية وإجاباتك عن السكري. لا يوجد حساب أو نسخة سحابية لمقدار، لذا فإن حذف التطبيق يحذفها. لا تُرسل بياناتك الجسدية ولا إجاباتك عن السكري إلى Gemini.',
                        ),
                      ),
                      _PrivacyRow(
                        icon: MiqdarIcons.autoAwesome,
                        title: s.tr('Google Gemini', 'Google Gemini'),
                        body: s.tr(
                          'Each food photo you analyze is sent to Google, with its weight and any note or description you typed or said. Speaking a description may also go through Apple\'s speech service. On Gemini\'s free plan, Google may use what it receives to improve its products, so avoid including people or private items in the photo.',
                          'تُرسل كل صورة طعام تحللها إلى Google مع وزنها وأي ملاحظة أو وصف كتبته أو نطقته. وقد يمر الوصف المنطوق أيضاً عبر خدمة النطق من Apple. في خطة Gemini المجانية قد تستخدم Google ما تتلقاه لتحسين منتجاتها، لذا تجنب ظهور أشخاص أو أشياء خاصة في الصورة.',
                        ),
                      ),
                      _PrivacyRow(
                        icon: MiqdarIcons.barcodeScanner,
                        title: s.tr('Open Food Facts', 'Open Food Facts'),
                        body: s.tr(
                          'When you scan a barcode, only the barcode number is sent to Open Food Facts, a free public food database, to look up the product. No photo, account or other data goes with it.',
                          'عند مسح الباركود يُرسل رقم الباركود فقط إلى Open Food Facts، وهي قاعدة بيانات غذائية عامة ومجانية، للبحث عن المنتج. لا تُرسل معه صورة أو حساب أو أي بيانات أخرى.',
                        ),
                      ),
                      _PrivacyRow(
                        icon: MiqdarIcons.scale,
                        title: s.tr('Your scale', 'ميزانك'),
                        body: s.tr(
                          'The scale keeps the photos it takes in its own storage. Deleting data in this app does not remove them.',
                          'يحتفظ الميزان بالصور التي يلتقطها في ذاكرته. حذف البيانات من هذا التطبيق لا يزيلها.',
                        ),
                        isLast: true,
                      ),
                    ],
                ),
                const SizedBox(height: 32),
                FilledButton.tonalIcon(
                  onPressed: () => showExportSheet(context, days: 365),
                  icon: const Icon(MiqdarIcons.download),
                  label: Text(s.tr('Export My Meals', 'تصدير وجباتي')),
                ),
                if (!controller.account.isDemo) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: context.mq.danger, minimumSize: const Size.fromHeight(48)),
                    onPressed: () => _confirmDeleteAll(context, controller),
                    icon: const Icon(MiqdarIcons.deleteForever),
                    label: Text(s.tr('Delete All My Data', 'حذف جميع بياناتي')),
                  ),
                ],
                const SizedBox(height: 14),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      leading: Icon(MiqdarIcons.build, color: context.mq.ink),
                      title: Text(
                        s.tr('Troubleshooting', 'استكشاف الأخطاء'),
                        style: TextStyle(fontWeight: FontWeight.w600, color: context.mq.ink),
                      ),
                      children: [
                        _DiagnosticLine(
                          label: s.tr('Scale address', 'عنوان الميزان'),
                          value: controller.apiService.baseUrl,
                        ),
                        _DiagnosticLine(
                          label: s.tr('Scale status', 'حالة الميزان'),
                          value: controller.scaleConnectionIssue ??
                              (controller.scaleDevice.online
                                  ? s.tr('Connected', 'متصل')
                                  : s.tr('Not connected', 'غير متصل')),
                        ),
                        if (controller.activeModelName != null)
                          _DiagnosticLine(
                            label: s.tr('Last AI model', 'آخر نموذج ذكاء اصطناعي'),
                            value: controller.activeModelName!,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context, MiqdarController controller) async {
    final s = S.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.tr('Delete all your data?', 'حذف جميع بياناتك؟')),
        content: Text(
          s.tr(
            'This permanently deletes your meals, meal photos, goals and preferences from this phone. It cannot be undone. Photos stored on the scale stay there.',
            'سيحذف هذا وجباتك وصورها وأهدافك وتفضيلاتك نهائياً من هذا الهاتف ولا يمكن التراجع عنه. تبقى الصور المحفوظة في الميزان كما هي.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.tr('Cancel', 'إلغاء')),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: context.mq.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.tr('Delete Everything', 'حذف كل شيء')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await controller.deleteAllData();
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(s.tr('Could not delete your data. Try again.', 'تعذر حذف بياناتك. حاول مجدداً.')),
        ),
      );
      return;
    }
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }
}

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow({
    required this.icon,
    required this.title,
    required this.body,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool isLast;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 26, weight: 300, color: context.mq.ink),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: MiqdarType.titleCard.copyWith(color: context.mq.ink)),
                  const SizedBox(height: 4),
                  Text(body, style: MiqdarType.reading.copyWith(color: context.mq.ink)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _DiagnosticLine extends StatelessWidget {
  const _DiagnosticLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.mq.ink)),
            SelectableText(value, style: const TextStyle(fontSize: 13)),
          ],
        ),
      );
}

Future<void> showScaleAddressDialog(BuildContext context, MiqdarController controller) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ScaleAddressDialog(controller: controller),
    );

class _ScaleAddressDialog extends StatefulWidget {
  const _ScaleAddressDialog({required this.controller});

  final MiqdarController controller;

  @override
  State<_ScaleAddressDialog> createState() => _ScaleAddressDialogState();
}

class _ScaleAddressDialogState extends State<_ScaleAddressDialog> {
  late final String originalAddress = widget.controller.apiService.baseUrl;
  late final TextEditingController address = TextEditingController(text: originalAddress);
  bool connecting = false;
  bool failed = false;

  @override
  void dispose() {
    address.dispose();
    super.dispose();
  }

  Future<void> _connect(S s) async {
    if (address.text.trim().isEmpty) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      connecting = true;
      failed = false;
    });
    final ok = await widget.controller.connectToScale(address.text);
    if (!mounted) return;
    if (ok) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(s.tr('Scale connected', 'تم الاتصال بالميزان')),
        ),
      );
      return;
    }
    setState(() {
      connecting = false;
      failed = true;
    });
  }

  void _cancel() {
    // Do not stay pointed at an address that was tried and did not answer.
    if (failed) widget.controller.setApiBaseUrl(originalAddress);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      title: Text(s.tr('Scale address', 'عنوان الميزان')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.tr(
                'Type the address shown on the scale\'s screen.',
                'اكتب العنوان الظاهر على شاشة الميزان.',
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                controller: address,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enabled: !connecting,
                onSubmitted: (_) => _connect(s),
                decoration: const InputDecoration(hintText: 'foodscale.local'),
              ),
            ),
            const SizedBox(height: 8),
            ActionChip(
              avatar: const Icon(MiqdarIcons.wifi, size: 16),
              label: Text(s.tr('On my Wi-Fi: foodscale.local', 'على شبكتي: foodscale.local')),
              onPressed: connecting ? null : () => address.text = 'foodscale.local',
            ),
            if (failed) ...[
              const SizedBox(height: 10),
              Text(
                s.tr(
                  'No answer from this address. Check that the scale is on and on the same Wi-Fi.',
                  'لا يوجد رد من هذا العنوان. تأكد أن الميزان يعمل وعلى شبكة Wi-Fi نفسها.',
                ),
                style: TextStyle(color: context.mq.danger, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: connecting ? null : _cancel,
          child: Text(s.tr('Cancel', 'إلغاء')),
        ),
        FilledButton(
          onPressed: connecting ? null : () => _connect(s),
          child: connecting
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(failed ? s.tr('Try Again', 'حاول مجدداً') : s.tr('Connect', 'اتصال')),
        ),
      ],
    );
  }
}
