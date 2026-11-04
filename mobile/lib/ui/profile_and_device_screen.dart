import 'package:flutter/material.dart';

import '../app.dart';
import '../app_controller.dart';
import '../l10n/strings.dart';
import '../models/nutrition.dart';
import '../theme.dart';
import 'screens.dart';
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        Text(
          s.navProfile,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: context.mq.heroGradient,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: context.mq.onHero,
                foregroundColor: context.mq.hero,
                child: Text(
                  account.localizedName(s.isAr).characters.first.toUpperCase(),
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: context.mq.ink),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.localizedName(s.isAr),
                      style: MiqdarType.titleSection.copyWith(color: context.mq.onHero),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.isDemo
                          ? s.tr('Demo with sample data', 'عرض تجريبي ببيانات نموذجية')
                          : s.tr('Your diary stays on this phone', 'سجلك محفوظ على هذا الهاتف'),
                      style: MiqdarType.body.copyWith(fontSize: 14, color: context.mq.onHeroMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                style: IconButton.styleFrom(foregroundColor: context.mq.onHero),
                tooltip: s.tr('Change your name', 'تغيير الاسم'),
                onPressed: () => _showEditNameSheet(context, controller),
                icon: const Icon(MiqdarIcons.edit),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        Text(
          s.tr('Appearance', 'المظهر'),
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: context.mq.ink),
        ),
        const SizedBox(height: 10),
        SurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(MiqdarIcons.language, color: context.mq.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.tr('Language', 'اللغة'),
                      style: MiqdarType.bodyStrong.copyWith(color: context.mq.ink),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: MiqdarSegmented<String>(
                      options: const [
                        (value: 'en', label: 'English', icon: null),
                        (value: 'ar', label: 'العربية', icon: null),
                      ],
                      value: controller.locale.languageCode,
                      onChanged: (code) => controller.setLocale(Locale(code)),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  isDark ? MiqdarIcons.darkMode : MiqdarIcons.lightMode,
                  color: context.mq.primary,
                ),
                title: Text(
                  s.tr('Dark Mode', 'المظهر الداكن'),
                  style: TextStyle(fontWeight: FontWeight.w600, color: context.mq.ink),
                ),
                value: isDark,
                onChanged: (_) => controller.toggleThemeMode(),
              ),
              if (MediaQuery.sizeOf(context).width >= 780) ...[
                const Divider(height: 24),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(MiqdarIcons.devices, color: context.mq.primary),
                  title: Text(
                    s.tr('Phone-sized layout', 'عرض بحجم الهاتف'),
                    style: TextStyle(fontWeight: FontWeight.w600, color: context.mq.ink),
                  ),
                  value: controller.forceMobileFrameOnDesktop,
                  onChanged: (_) => controller.toggleViewportFrame(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),

        Text(
          s.tr('Settings', 'الإعدادات'),
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: context.mq.ink),
        ),
        const SizedBox(height: 10),
        if (!controller.account.isDemo)
          _ProfileNavRow(
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
        _ProfileNavRow(
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
        _ProfileNavRow(
          icon: MiqdarIcons.restaurantMenu,
          title: s.tr('Food Preferences', 'تفضيلات الطعام'),
          subtitle: s.tr('Allergies, foods to avoid, meal ideas', 'الحساسية، أطعمة تتجنبها، أفكار للوجبات'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MealSuggestionsScreen(showPreferences: true)),
          ),
        ),
        if (!controller.account.isDemo)
          _ProfileNavRow(
            icon: MiqdarIcons.notifications,
            title: s.tr('Meal Reminders', 'تذكير الوجبات'),
            subtitle: controller.reminderSettings.enabled ? s.tr('On', 'مفعّل') : s.tr('Off', 'متوقف'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RemindersScreen()),
            ),
          ),
        _ProfileNavRow(
          icon: MiqdarIcons.scale,
          title: s.navDevices,
          subtitle: controller.scaleDevice.online
              ? s.tr('Connected', 'متصل')
              : s.tr('Not connected', 'غير متصل'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DeviceSettingsScreen()),
          ),
        ),
        _ProfileNavRow(
          icon: MiqdarIcons.shield,
          title: s.tr('Privacy & Data', 'الخصوصية والبيانات'),
          subtitle: s.tr('Where your data goes, export, delete', 'أين تذهب بياناتك، التصدير، الحذف'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PrivacyAndDataScreen()),
          ),
        ),
        if (account.isDemo) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
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
        ],
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

class _ProfileNavRow extends StatelessWidget {
  const _ProfileNavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SurfaceCard(
          padding: const EdgeInsets.all(16),
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: context.mq.surfaceSunken,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 26, color: context.mq.ink),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: MiqdarType.titleCard.copyWith(fontSize: 16, color: context.mq.ink)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: MiqdarType.label.copyWith(fontWeight: FontWeight.w400, color: context.mq.inkMuted)),
                  ],
                ),
              ),
              Icon(MiqdarIcons.chevronRight, color: context.mq.inkMuted),
            ],
          ),
        ),
      );
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
                  padding: EdgeInsets.zero,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: widget.showPreferences,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                      leading: Icon(MiqdarIcons.tune, color: context.mq.primary),
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
                            ...conditionLabels.entries.map((entry) => FilterChip(
                                  label: Text(entry.value),
                                  selected: profile.conditions.contains(entry.key),
                                  onSelected: (selected) => _toggleCondition(entry.key, selected),
                                )),
                            ...preferenceLabels.entries.map((entry) => FilterChip(
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
                      Icon(MiqdarIcons.link, color: context.mq.primary),
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
                        Icon(MiqdarIcons.photoCamera, color: context.mq.primary),
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
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.tr('Where your data goes', 'أين تذهب بياناتك'),
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: context.mq.ink),
                      ),
                      const SizedBox(height: 14),
                      _PrivacyRow(
                        icon: MiqdarIcons.phoneIphone,
                        title: s.tr('This phone', 'هذا الهاتف'),
                        body: s.tr(
                          'Your meals, meal photos, goals, preferences and body profile are stored here. There is no Miqdar account or cloud copy, so removing the app removes them. Your body profile is not sent to Gemini.',
                          'تُحفظ هنا وجباتك وصورها وأهدافك وتفضيلاتك وبياناتك الجسدية. لا يوجد حساب أو نسخة سحابية لمقدار، لذا فإن حذف التطبيق يحذفها. لا تُرسل بياناتك الجسدية إلى Gemini.',
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
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => showExportSheet(context, days: 365),
                  icon: const Icon(MiqdarIcons.download),
                  label: Text(s.tr('Export My Meals', 'تصدير وجباتي')),
                ),
                if (!controller.account.isDemo) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.mq.danger,
                      side: BorderSide(color: context.mq.danger.withValues(alpha: 0.4)),
                    ),
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
                      leading: Icon(MiqdarIcons.build, color: context.mq.primary),
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
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.mq.danger),
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
        padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: context.mq.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: context.mq.ink)),
                  const SizedBox(height: 2),
                  Text(body, style: const TextStyle(fontSize: 13, height: 1.45)),
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
