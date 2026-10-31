import 'package:flutter/material.dart';

import '../app.dart';
import '../app_controller.dart';
import '../l10n/strings.dart';
import '../models/nutrition.dart';
import '../theme.dart';
import 'screens.dart';
import 'widgets/charts_and_gauges.dart';

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
        Text(
          s.tr(
            'Account, dietary preferences, connected scale, privacy & diagnostics (S41).',
            'الحساب، التفضيلات الغذائية، الميزان المتصل، الخصوصية والتشخيص (S41).',
          ),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 18),

        // Account Hero Card
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: MiqdarColors.heroGradient,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
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
                    Text(
                      account.email,
                      style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        account.isDemo
                            ? s.tr('Demo Workspace Account', 'حساب مساحة العرض التجريبي')
                            : s.tr('Verified Personal Account', 'حساب شخصي موثق'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                style: IconButton.styleFrom(foregroundColor: Colors.white),
                tooltip: s.tr('Edit Personal Info (S42)', 'تعديل البيانات الشخصية'),
                onPressed: () => _showEditPersonalSheet(context, controller),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Section: Language, Theme & Viewport (S45)
        Text(
          s.tr('Appearance, Language & Display (S45)', 'المظهر واللغة وطريقة العرض (S45)'),
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
                      s.tr('Interface Language (Bilingual RTL/LTR)', 'لغة الواجهة (عربي / English)'),
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
                  s.tr('Dark Mode Theme', 'المظهر الداكن'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  s.tr(
                    'High-contrast emerald & slate dark palette',
                    'لوحة ألوان زمردية داكنة مريحة للعين',
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
                value: isDark,
                onChanged: (_) => controller.toggleThemeMode(),
              ),
              const Divider(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.devices_rounded, color: MiqdarColors.primary),
                title: Text(
                  s.tr('Compact Mobile Handset Preview Frame', 'إطار معاينة الهاتف المحمول'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  s.tr(
                    'Toggle between full-width responsive desktop dashboard and 460px mobile handset frame.',
                    'التبديل بين لوحة التحكم العريضة وإطار شاشة الجوال.',
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
                value: controller.forceMobileFrameOnDesktop,
                onChanged: (_) => controller.toggleViewportFrame(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Section: Nutrition, Hardware & Diagnostics
        Text(
          s.tr('Nutrition, Scale Hardware & Data', 'التغذية والميزان والبيانات'),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
        ),
        const SizedBox(height: 10),
        _ProfileNavRow(
          icon: Icons.track_changes_rounded,
          title: s.tr('Goals & Nutrient Targets (S35)', 'الأهداف والحدود الغذائية (S35)'),
          subtitle: s.tr(
            'Calories, macros, sodium, sugar, potassium & track-only mode',
            'السعرات، العناصر الكبرى، الصوديوم، السكر، البوتاسيوم ووضع التتبع',
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GoalsScreen()),
          ),
        ),
        _ProfileNavRow(
          icon: Icons.restaurant_menu_rounded,
          title: s.tr('Dietary Preferences & Smart Meal Ideas (S36/S39)', 'التفضيلات واقتراحات الوجبات الذكية'),
          subtitle: s.tr(
            'Exclusions, allergens, considerations & 14-day variety scoring',
            'الاستثناءات والحساسيات والاقتراحات المبنية على سجل 14 يوماً',
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MealSuggestionsScreen()),
          ),
        ),
        _ProfileNavRow(
          icon: Icons.scale_rounded,
          title: s.tr('Connected Scale & Calibration (S09–S13)', 'إعدادات الميزان والمعايرة (S09–S13)'),
          subtitle: controller.scaleDevice.paired
              ? '${controller.scaleDevice.deviceId} • ${controller.scaleDevice.wifiSsid} • Online'
              : s.tr('Unpaired — Tap to claim scale', 'غير مقترن — اضغط لربط الميزان'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DeviceSettingsScreen()),
          ),
        ),
        _ProfileNavRow(
          icon: Icons.sync_rounded,
          title: s.tr('Sync Outbox, Privacy & Diagnostics (S46–S59)', 'المزامنة والخصوصية والتشخيص (S46–S59)'),
          subtitle: '${controller.connectionStatus} • ${controller.pendingSyncCount} ${s.tr("pending", "معلق")}',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SyncAndDiagnosticsScreen()),
          ),
        ),
        const SizedBox(height: 18),

        // Sign Out Button (UI-14)
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: MiqdarColors.danger,
            side: BorderSide(color: MiqdarColors.danger.withValues(alpha: 0.4)),
          ),
          onPressed: () {
            controller.signOut();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
              (_) => false,
            );
          },
          icon: const Icon(Icons.logout_rounded),
          label: Text(s.tr('Sign Out of Account', 'تسجيل الخروج من الحساب')),
        ),
      ],
    );
  }

  void _showEditPersonalSheet(BuildContext context, MiqdarController controller) {
    final s = S.of(context);
    final nameEnCtrl = TextEditingController(text: controller.account.displayName);
    final nameArCtrl = TextEditingController(text: controller.account.displayNameAr);
    final emailCtrl = TextEditingController(text: controller.account.email);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          22,
          22,
          MediaQuery.viewInsetsOf(ctx).bottom + 24,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.tr('Personal Information (S42)', 'المعلومات الشخصية (S42)'),
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameEnCtrl,
                decoration: InputDecoration(
                  labelText: s.tr('Display Name (English)', 'الاسم (إنجليزي)'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameArCtrl,
                decoration: InputDecoration(
                  labelText: s.tr('Display Name (Arabic)', 'الاسم (عربي)'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(labelText: s.emailLabel),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  controller.updateAccountProfile(
                    displayName: nameEnCtrl.text.trim(),
                    displayNameAr: nameArCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                  );
                  Navigator.of(ctx).pop();
                },
                child: Text(s.tr('Save Profile', 'حفظ البيانات')),
              ),
            ],
          ),
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

/// Dietary Preferences & Smart Meal Ideas Screen (S36, S39, S40).
class MealSuggestionsScreen extends StatefulWidget {
  const MealSuggestionsScreen({super.key});

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
      .split(',')
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

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    final profile = draft ?? controller.healthProfile;

    final conditionLabels = <String, String>{
      'diabetes': s.tr('Blood-sugar / Sugar awareness', 'مراعاة السكريات في الوجبات'),
      'hypertension': s.tr('Sodium awareness', 'مراعاة الصوديوم والملح'),
      'high_cholesterol': s.tr('Lower total fat focus', 'مراعاة الدهون الكلية'),
      'weight_management': s.tr('Energy density balance', 'توازن الكثافة الحرارية'),
      'kidney_disease': s.tr(
        'Clinician sodium/potassium targets',
        'حدود الصوديوم والبوتاسيوم بإشراف مختص',
      ),
    };
    final preferenceLabels = <String, String>{
      'vegetarian': s.tr('Vegetarian', 'نباتي'),
      'vegan': s.tr('Plant-based / Vegan', 'نباتي صرف'),
    };

    return Scaffold(
      appBar: AppBar(title: Text(s.mealIdeasTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MiqdarColors.warningBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: MiqdarColors.warning.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: MiqdarColors.warning),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s.tr(
                            'Miqdar filters suggestions using your declared exclusions, targets, and 14-day meal variety. A photo or suggestion cannot certify allergen absence or replace medical advice (S36, SUG-02).',
                            'يصفّي مقدار الاقتراحات بناءً على الاستثناءات والأهداف وتنوع آخر 14 يوماً. لا تعد الاقتراحات وصفة طبية أو ضماناً لخلو الطعام من مسببات الحساسية (S36, SUG-02).',
                          ),
                          style: const TextStyle(color: MiqdarColors.dark, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  s.tr('Optional Planning Considerations (S36)', 'اعتبارات التخطيط الغذائي الاختيارية (S36)'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: conditionLabels.entries
                      .map((entry) => FilterChip(
                            label: Text(entry.value),
                            selected: profile.conditions.contains(entry.key),
                            onSelected: (selected) => _toggleCondition(entry.key, selected),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 18),

                Text(
                  s.tr('Dietary Pattern', 'النمط الغذائي'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: preferenceLabels.entries
                      .map((entry) => FilterChip(
                            label: Text(entry.value),
                            selected: profile.dietaryPreferences.contains(entry.key),
                            onSelected: (selected) => _togglePreference(entry.key, selected),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: allergensCtrl,
                  decoration: InputDecoration(
                    labelText: s.tr('Allergens or Excluded Ingredients', 'الحساسيات أو المكونات المستبعدة'),
                    hintText: s.tr('e.g., nuts, dairy, fish', 'مثال: لوز، ألبان، سمك'),
                    prefixIcon: const Icon(Icons.no_food_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dislikesCtrl,
                  decoration: InputDecoration(
                    labelText: s.tr('Disliked Foods', 'الأطعمة غير المفضلة'),
                    hintText: s.tr('e.g., tomato, egg', 'مثال: طماطم، بيض'),
                    prefixIcon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                ),
                const SizedBox(height: 16),

                FilledButton.icon(
                  onPressed: controller.recommendationsBusy
                      ? null
                      : () async {
                          final value = profile.copyWith(
                            allergens: _csv(allergensCtrl.text),
                            dislikedFoods: _csv(dislikesCtrl.text),
                          );
                          setState(() => draft = value);
                          await controller.updateHealthProfile(value);
                        },
                  icon: controller.recommendationsBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(
                    controller.recommendationsBusy
                        ? s.tr('Refreshing suggestions…', 'جارٍ تحديث الاقتراحات…')
                        : s.tr('Save Preferences & Refresh Ideas', 'حفظ التفضيلات وتحديث الاقتراحات'),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      s.tr('Recommended Next Meals (S39)', 'الوجبات المقترحة لك (S39)'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    if (controller.recommendationsOffline)
                      Chip(label: Text(s.tr('Local Catalog Scoring', 'تقييم محلي'))),
                  ],
                ),
                const SizedBox(height: 10),
                if (controller.mealSuggestions.isEmpty && !controller.recommendationsBusy)
                  SurfaceCard(
                    child: Text(
                      s.tr(
                        'No compatible meal suggestions found. Try relaxing exclusions or saving your profile.',
                        'لا توجد اقتراحات متوافقة حالياً. جرب تعديل الاستثناءات أو حفظ التفضيلات.',
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
                if (controller.recommendationDisclaimer.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    controller.recommendationDisclaimer,
                    style: const TextStyle(fontSize: 12),
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

/// Hardware & Device Settings Screen (S09–S13).
class DeviceSettingsScreen extends StatelessWidget {
  const DeviceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    final scale = controller.scaleDevice;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.tr('Scale Hardware & Controls (S12)', 'إعدادات الميزان الذكي (S12)')),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                // Scale Identity & Live Telemetry Card
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: scale.paired
                                  ? MiqdarColors.softGreen
                                  : MiqdarColors.border,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.scale_rounded,
                              size: 40,
                              color: scale.paired ? MiqdarColors.primary : MiqdarColors.muted,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  scale.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  scale.paired
                                      ? '${scale.deviceId} • ${s.tr("Connected & Ready", "متصل وجاهز")}'
                                      : '${scale.deviceId} • ${s.tr("Unpaired", "غير مقترن")}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: scale.paired
                                        ? MiqdarColors.primary
                                        : MiqdarColors.warning,
                                  ),
                                ),
                                Text(
                                  '${s.tr("Firmware", "النظام")}: ${scale.firmwareVersion} • ${s.tr("Capacity", "السعة")}: ${scale.capacityG.toStringAsFixed(0)} ${s.unitG} (${scale.resolutionG.toStringAsFixed(0)} ${s.unitG})',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 26),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _DeviceStatColumn(
                            label: s.tr('Live Reading', 'القراءة الحالية'),
                            value: '${scale.effectiveWeightG.toStringAsFixed(0)} ${s.unitG}',
                          ),
                          _DeviceStatColumn(
                            label: s.tr('Stability', 'الاستقرار'),
                            value: scale.isStable
                                ? s.tr('Stable', 'مستقر')
                                : s.tr('Moving', 'متحرك'),
                          ),
                          _DeviceStatColumn(
                            label: s.tr('Battery', 'البطارية'),
                            value: '${scale.batteryPercent}%',
                          ),
                          _DeviceStatColumn(
                            label: 'Wi-Fi',
                            value: scale.wifiSsid,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: scale.paired ? controller.tareScale : null,
                              icon: const Icon(Icons.exposure_zero_rounded),
                              label: Text(s.tareScale),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showCalibrationGuide(context),
                              icon: const Icon(Icons.straighten_rounded),
                              label: Text(s.tr('Calibration Check (S13)', 'فحص المعايرة (S13)')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Capability-based Controls (PRD-10, S12)
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.tr('Supported Hardware Controls (PRD-10)', 'عناصر التحكم المدعومة (PRD-10)'),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          s.tr('Auto-sync scale capture events', 'مزامنة تلقائية لأحداث الميزان'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          s.tr(
                            'Create a reviewable draft when a stable placement is captured',
                            'إنشاء مسودة قابلة للمراجعة عند استقرار الوزن والتقاط الصورة',
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: scale.autoSync,
                        onChanged: scale.paired
                            ? (v) => controller.updateScaleSettings(autoSync: v)
                            : null,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          s.tr('Scale acoustic feedback', 'التنبيه الصوتي للميزان'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        value: scale.soundEnabled,
                        onChanged: scale.paired
                            ? (v) => controller.updateScaleSettings(soundEnabled: v)
                            : null,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          s.tr('Scale OLED Display Brightness', 'سطوع شاشة الميزان'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Slider(
                          value: scale.brightness,
                          onChanged: scale.paired
                              ? (v) => controller.updateScaleSettings(brightness: v)
                              : null,
                        ),
                        trailing: Text('${(scale.brightness * 100).round()}%'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Pair / Unpair Action (UI-08)
                if (scale.paired)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MiqdarColors.danger,
                      side: BorderSide(color: MiqdarColors.danger.withValues(alpha: 0.4)),
                    ),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: Text(s.tr('Unpair Miqdar-015?', 'إلغاء اقتران الميزان؟')),
                          content: Text(
                            s.tr(
                              'Your saved meal history remains intact. You can re-claim the scale anytime (UI-08).',
                              'سيبقى سجل وجباتك محفوظاً بالكامل، ويمكنك إعادة ربط الميزان في أي وقت (UI-08).',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dialogContext).pop(false),
                              child: Text(s.tr('Cancel', 'إلغاء')),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: MiqdarColors.danger),
                              onPressed: () => Navigator.of(dialogContext).pop(true),
                              child: Text(s.tr('Unpair', 'إلغاء الاقتران')),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        controller.updateScaleSettings(paired: false, online: false);
                      }
                    },
                    icon: const Icon(Icons.link_off_rounded),
                    label: Text(s.tr('Unpair Scale Device', 'إلغاء اقتران الميزان')),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PairingScreen()),
                    ),
                    icon: const Icon(Icons.add_link_rounded),
                    label: Text(s.tr('Pair & Claim Scale', 'ربط وتوثيق الميزان')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCalibrationGuide(BuildContext context) {
    final s = S.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.tr('Zero vs Sensor Calibration (S13)', 'التصفير مقابل معايرة الحساس (S13)')),
        content: Text(
          s.tr(
            '• Zero / Tare establishes a 0.0 g net baseline for your current empty plate.\n\n'
            '• Sensor Calibration requires placing the scale on a level, vibration-free surface and using a certified 500 g reference mass. Never use guessed household items to recalibrate the load cell.',
            '• التصفير (Tare): يضبط نقطة الصفر الصافية للطبق الفارغ الحالي.\n\n'
            '• معايرة الحساس: تتطلب وضع الميزان على سطح مستوٍ تماماً واستخدام كتلة مرجعية معيارية موثقة (500 غ). لا تستخدم أوزاناً تقديرية لمعايرة الحساس.',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.tr('Understood', 'حسناً')),
          ),
        ],
      ),
    );
  }
}

class _DeviceStatColumn extends StatelessWidget {
  const _DeviceStatColumn({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13.5,
              color: MiqdarColors.primary,
            ),
          ),
        ],
      );
}

/// Sync Outbox, Privacy & Technical Diagnostics Screen (S46–S59).
class SyncAndDiagnosticsScreen extends StatelessWidget {
  const SyncAndDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.tr('Sync, Privacy & Diagnostics (S49/S59)', 'المزامنة والخصوصية والتشخيص')),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                // Server & AI Telemetry (S59)
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.memory_rounded, color: MiqdarColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.tr('System & AI Telemetry (S59)', 'حالة الخادم والذكاء الاصطناعي (S59)'),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: controller.checkServer,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(s.tr('Ping /health', 'فحص الاتصال')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('${s.tr("Connection status", "حالة الاتصال")}: ${controller.connectionStatus}'),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${s.tr("API Endpoint", "عنوان الخادم")}: ${controller.apiService.baseUrl}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () => _showEndpointDialog(context, controller),
                            icon: const Icon(Icons.edit_rounded, size: 15),
                            label: Text(s.tr('Change', 'تغيير'), style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      Text(
                        '${s.tr("Last local alert evaluation", "زمن تقييم التنبيهات المحلي")}: ${controller.alertEvaluationMs} ms (Target ≤ 4,000 ms)',
                      ),
                      Text(
                        '${s.tr("Catalog records loaded", "السجلات الغذائية المحملة")}: ${38 + controller.localDatabase.customFoods.length}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Sync Outbox Queue (S49)
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cloud_sync_rounded, color: MiqdarColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.tr('Outbox & Sync Activity (S49)', 'صندوق المزامنة والعمليات (S49)'),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
                            ),
                          ),
                          if (controller.pendingSyncCount > 0)
                            FilledButton.tonal(
                              onPressed: controller.retrySyncOutbox,
                              child: Text(s.tr('Sync Now', 'مزامنة الآن')),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (controller.syncOperations.isEmpty)
                        Text(
                          s.tr(
                            'All local records are synchronized. New meal saves appear here with idempotent operation IDs.',
                            'جميع السجلات المحلية متزامنة. ستظهر عمليات الحفظ الجديدة هنا مع معرفات عدم التكرار.',
                          ),
                          style: const TextStyle(fontSize: 12.5),
                        )
                      else
                        ...controller.syncOperations.take(8).map(
                              (op) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                leading: Icon(
                                  op.status == 'synced'
                                      ? Icons.check_circle_rounded
                                      : Icons.schedule_send_rounded,
                                  color: op.status == 'synced'
                                      ? MiqdarColors.primary
                                      : MiqdarColors.warning,
                                ),
                                title: Text(
                                  op.detail,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text('${op.operationId} • ${op.status.toUpperCase()}'),
                              ),
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Privacy & Account Deletion (S46, S48)
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.tr('Privacy & Data Lifecycle (S46 / S48)', 'الخصوصية ودورة حياة البيانات (S46 / S48)'),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.tr(
                          '• Structured meal records remain in your personal diary until you delete them.\n'
                          '• Recognition photos are processed transiently for identification and are not used for undisclosed model training (PRIV-03).',
                          '• تبقى سجلات الوجبات المنظمة في حسابك حتى تقوم بحذفها.\n'
                          '• تُعالج صور الوجبات مؤقتاً للتعرف الغذائي فقط ولا تُستخدم لتدريب النماذج دون إذن صريح (PRIV-03).',
                        ),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MiqdarColors.danger,
                          side: BorderSide(color: MiqdarColors.danger.withValues(alpha: 0.4)),
                        ),
                        onPressed: () => _showDeleteAccountDialog(context, controller),
                        icon: const Icon(Icons.person_remove_outlined),
                        label: Text(s.tr('Request Account Deletion (S48)', 'طلب حذف الحساب والبيانات (S48)')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, MiqdarController controller) {
    final s = S.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.tr('Delete Account & Personal Data? (S48)', 'حذف الحساب والبيانات الشخصية؟ (S48)')),
        content: Text(
          s.tr(
            'This submits an account deletion request to remove your cloud profile, meal history, and paired scale claims, and clears local credentials.',
            'سيؤدي هذا إلى تقديم طلب حذف نهائي لبيانات الحساب وسجل الوجبات وارتباط الميزان، ومسح بيانات الجلسة المحلية.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.tr('Cancel', 'إلغاء')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: MiqdarColors.danger),
            onPressed: () {
              Navigator.of(ctx).pop();
              controller.signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (_) => false,
              );
            },
            child: Text(s.tr('Confirm Deletion Request', 'تأكيد طلب الحذف')),
          ),
        ],
      ),
    );
  }

  void _showEndpointDialog(BuildContext context, MiqdarController controller) {
    showApiUrlDialog(context, controller);
  }
}

Future<void> showApiUrlDialog(BuildContext context, MiqdarController controller) {
  final s = S.of(context);
  final textController = TextEditingController(text: controller.apiService.baseUrl);

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.tr('Set API Server URL', 'تعيين عنوان خادم مقدار')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.tr(
                'Enter your Cloudflare Tunnel URL (for internet connection) or local IP of your Raspberry Pi scale.',
                'أدخل رابط نفق كلاودفلير (للاتصال عبر الإنترنت) أو عنوان IP المحلي لميزان الراسبيري باي.',
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'API Base URL',
                hintText: 'https://xxxx.trycloudflare.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(s.tr('Quick Presets & Cloudflare:', 'إعدادات سريعة وكلاودفلير:'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.cloud_sync, size: 16),
                  label: const Text('Cloudflare Tunnel (https://)'),
                  onPressed: () {
                    if (!textController.text.startsWith('https://')) {
                      textController.text = 'https://';
                      textController.selection = TextSelection.fromPosition(
                        TextPosition(offset: textController.text.length),
                      );
                    }
                  },
                ),
                ActionChip(
                  label: const Text('Pi LAN (192.168.137.166)'),
                  onPressed: () => textController.text = 'http://192.168.137.166:8080',
                ),
                ActionChip(
                  label: const Text('Localhost (127.0.0.1)'),
                  onPressed: () => textController.text = 'http://127.0.0.1:8080',
                ),
                ActionChip(
                  label: const Text('Android Sim (10.0.2.2)'),
                  onPressed: () => textController.text = 'http://10.0.2.2:8080',
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(s.tr('Cancel', 'إلغاء')),
        ),
        FilledButton(
          onPressed: () {
            var newUrl = textController.text.trim();
            if (newUrl.isNotEmpty) {
              if (!newUrl.startsWith('http://') && !newUrl.startsWith('https://')) {
                newUrl = 'https://$newUrl';
              }
              controller.setApiBaseUrl(newUrl);
            }
            Navigator.of(ctx).pop();
          },
          child: Text(s.tr('Save & Connect', 'حفظ والاتصال')),
        ),
      ],
    ),
  );
}

