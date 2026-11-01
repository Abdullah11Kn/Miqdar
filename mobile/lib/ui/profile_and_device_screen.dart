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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            gradient: MiqdarColors.heroGradient,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                foregroundColor: MiqdarColors.emeraldDeep,
                child: Text(
                  account.localizedName(s.isAr).characters.first.toUpperCase(),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.localizedName(s.isAr),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.isDemo
                          ? s.tr('Demo with sample data', 'عرض تجريبي ببيانات نموذجية')
                          : s.tr('Your diary stays on this phone', 'سجلك محفوظ على هذا الهاتف'),
                      style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                style: IconButton.styleFrom(foregroundColor: Colors.white),
                tooltip: s.tr('Change your name', 'تغيير الاسم'),
                onPressed: () => _showEditNameSheet(context, controller),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        Text(
          s.tr('Appearance', 'المظهر'),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
        ),
        const SizedBox(height: 10),
        SurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.language_rounded, color: MiqdarColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.tr('Language', 'اللغة'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('English')),
                      ButtonSegment(value: 'ar', label: Text('العربية')),
                    ],
                    selected: {controller.locale.languageCode},
                    onSelectionChanged: (sel) => controller.setLocale(Locale(sel.first)),
                  ),
                ],
              ),
              const Divider(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: MiqdarColors.primary,
                ),
                title: Text(
                  s.tr('Dark Mode', 'المظهر الداكن'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                value: isDark,
                onChanged: (_) => controller.toggleThemeMode(),
              ),
              if (MediaQuery.sizeOf(context).width >= 780) ...[
                const Divider(height: 24),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.devices_rounded, color: MiqdarColors.primary),
                  title: Text(
                    s.tr('Phone-sized layout', 'عرض بحجم الهاتف'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
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
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
        ),
        const SizedBox(height: 10),
        _ProfileNavRow(
          icon: Icons.track_changes_rounded,
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
          icon: Icons.restaurant_menu_rounded,
          title: s.tr('Food Preferences', 'تفضيلات الطعام'),
          subtitle: s.tr('Allergies, foods to avoid, meal ideas', 'الحساسية، أطعمة تتجنبها، أفكار للوجبات'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MealSuggestionsScreen(showPreferences: true)),
          ),
        ),
        _ProfileNavRow(
          icon: Icons.scale_rounded,
          title: s.navDevices,
          subtitle: controller.scaleDevice.online
              ? s.tr('Connected', 'متصل')
              : s.tr('Not connected', 'غير متصل'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DeviceSettingsScreen()),
          ),
        ),
        _ProfileNavRow(
          icon: Icons.shield_outlined,
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
            icon: const Icon(Icons.logout_rounded),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: MiqdarColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: MiqdarColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: MiqdarColors.muted),
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
                      leading: const Icon(Icons.tune_rounded, color: MiqdarColors.primary),
                      title: Text(
                        s.tr('Your preferences', 'تفضيلاتك'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      children: [
                        Text(
                          s.tr('I am', 'أنا'),
                          style: const TextStyle(fontWeight: FontWeight.w800),
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
                            prefixIcon: const Icon(Icons.no_food_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: dislikesCtrl,
                          decoration: InputDecoration(
                            labelText: s.tr('Foods to avoid', 'أطعمة تتجنبها'),
                            hintText: s.tr('e.g. tomato, egg', 'مثال: طماطم، بيض'),
                            prefixIcon: const Icon(Icons.remove_circle_outline_rounded),
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

    final String status;
    final Color statusColor;
    if (!scale.online) {
      status = s.tr('Not connected', 'غير متصل');
      statusColor = MiqdarColors.warning;
    } else if (scale.sensorError != null) {
      status = s.tr('Weight sensor not responding', 'حساس الوزن لا يستجيب');
      statusColor = MiqdarColors.danger;
    } else if (scale.simulated) {
      status = s.tr('Simulated scale, not real food', 'ميزان محاكاة، ليس طعاماً حقيقياً');
      statusColor = MiqdarColors.warning;
    } else {
      status = s.tr('Connected', 'متصل');
      statusColor = MiqdarColors.primary;
    }

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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.circle, size: 10, color: statusColor),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              status,
                              style: TextStyle(fontWeight: FontWeight.w800, color: statusColor),
                            ),
                          ),
                        ],
                      ),
                      if (scale.online) ...[
                        const SizedBox(height: 10),
                        Text(
                          '${scale.effectiveWeightG.toStringAsFixed(0)} ${s.unitG}',
                          style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900),
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
                          child: FilledButton.tonalIcon(
                            onPressed: controller.taringScale ? null : () => _zero(controller, s),
                            icon: const Icon(Icons.exposure_zero_rounded),
                            label: Text(s.tareScale),
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
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
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
                              : const Icon(Icons.refresh_rounded),
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
                      const Icon(Icons.link_rounded, color: MiqdarColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.tr('Scale address', 'عنوان الميزان'),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                controller.apiService.baseUrl,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        s.tr('Change', 'تغيير'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: MiqdarColors.primary,
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
                        const Icon(Icons.camera_alt_outlined, color: MiqdarColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                scale.autoCapture
                                    ? s.tr('Automatic capture is on', 'الالتقاط التلقائي مفعّل')
                                    : s.tr('Automatic capture is off', 'الالتقاط التلقائي متوقف'),
                                style: const TextStyle(fontWeight: FontWeight.w800),
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
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
                      ),
                      const SizedBox(height: 14),
                      _PrivacyRow(
                        icon: Icons.phone_iphone_rounded,
                        title: s.tr('This phone', 'هذا الهاتف'),
                        body: s.tr(
                          'Your meals, meal photos, goals and preferences are stored here. There is no Miqdar account or cloud copy, so removing the app removes them.',
                          'تُحفظ هنا وجباتك وصورها وأهدافك وتفضيلاتك. لا يوجد حساب أو نسخة سحابية لمقدار، لذا فإن حذف التطبيق يحذفها.',
                        ),
                      ),
                      _PrivacyRow(
                        icon: Icons.auto_awesome_rounded,
                        title: s.tr('Google Gemini', 'Google Gemini'),
                        body: s.tr(
                          'Each food photo you analyze is sent to Google, with its weight and any note you typed. On Gemini\'s free plan, Google may use what it receives to improve its products, so avoid including people or private items in the photo.',
                          'تُرسل كل صورة طعام تحللها إلى Google مع وزنها وأي ملاحظة كتبتها. في خطة Gemini المجانية قد تستخدم Google ما تتلقاه لتحسين منتجاتها، لذا تجنب ظهور أشخاص أو أشياء خاصة في الصورة.',
                        ),
                      ),
                      _PrivacyRow(
                        icon: Icons.scale_rounded,
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
                  icon: const Icon(Icons.download_rounded),
                  label: Text(s.tr('Export My Meals', 'تصدير وجباتي')),
                ),
                if (!controller.account.isDemo) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MiqdarColors.danger,
                      side: BorderSide(color: MiqdarColors.danger.withValues(alpha: 0.4)),
                    ),
                    onPressed: () => _confirmDeleteAll(context, controller),
                    icon: const Icon(Icons.delete_forever_outlined),
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
                      leading: const Icon(Icons.build_outlined, color: MiqdarColors.primary),
                      title: Text(
                        s.tr('Troubleshooting', 'استكشاف الأخطاء'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
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
            style: FilledButton.styleFrom(backgroundColor: MiqdarColors.danger),
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
            Icon(icon, size: 20, color: MiqdarColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(body, style: const TextStyle(fontSize: 12.5, height: 1.45)),
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
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
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
              avatar: const Icon(Icons.wifi_rounded, size: 16),
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
                style: const TextStyle(color: MiqdarColors.danger, fontSize: 13, fontWeight: FontWeight.w700),
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
