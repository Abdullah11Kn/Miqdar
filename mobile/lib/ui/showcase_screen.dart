import 'package:flutter/material.dart';

import '../app.dart';
import '../l10n/strings.dart';
import '../showcase/showcase.dart';
import '../theme.dart';

/// What a scenario is and what to show in it, for whoever is presenting.
class ShowcaseGuide {
  const ShowcaseGuide({required this.icon, required this.title, required this.who, required this.summary, required this.steps});

  final IconData icon;
  final String title;
  final String who;
  final String summary;
  final List<String> steps;

  static ShowcaseGuide of(Showcase showcase, S s) => switch (showcase) {
        Showcase.firstRun => ShowcaseGuide(
            icon: MiqdarIcons.autoAwesome,
            title: s.tr('First Launch', 'أول تشغيل'),
            who: s.tr('A new user, no data yet', 'مستخدم جديد بلا بيانات'),
            summary: s.tr(
              'The phone has never opened Miqdar: the splash, Welcome, the body profile and the goal Miqdar works out.',
              'هاتف لم يفتح مقدار من قبل: شاشة البداية، الترحيب، البيانات الجسدية، والهدف الذي يحسبه مقدار.',
            ),
            steps: [
              s.tr('The animated logo, then Welcome with its wall of food photos', 'الشعار المتحرك، ثم شاشة الترحيب بصور الأطعمة'),
              s.tr('The language button on Welcome turns the whole app Arabic, right to left',
                  'زر اللغة في الترحيب يحوّل التطبيق كله إلى العربية من اليمين إلى اليسار'),
              s.tr('Get Started, then the Body Profile: age, height, weight, activity and goal',
                  'ابدأ، ثم البيانات الجسدية: العمر والطول والوزن والنشاط والهدف'),
              s.tr('The daily goal Miqdar calculates, with its safety limits (try an age under 18)',
                  'الهدف اليومي الذي يحسبه مقدار، مع حدود الأمان (جرّب عمرًا أقل من 18)'),
              s.tr('An empty Home, ready for the first meal on the scale', 'الرئيسية فارغة وجاهزة لأول وجبة على الميزان'),
            ],
          ),
        Showcase.everyday => ShowcaseGuide(
            icon: MiqdarIcons.restaurant,
            title: s.tr('Every Day with Miqdar', 'يوم مع مقدار'),
            who: s.tr('Khalid, 27, losing weight. Three weeks of meals', 'خالد، 27 سنة، يريد إنقاص وزنه. ثلاثة أسابيع من الوجبات'),
            summary: s.tr(
              'Three weeks of meals, weigh-ins and water, with every everyday feature in use. Lunch today is left for you to weigh live.',
              'ثلاثة أسابيع من الوجبات والأوزان والماء، وكل الميزات اليومية مستخدمة. غداء اليوم متروك لتزنه أمامهم.',
            ),
            steps: [
              s.tr('Home: the calorie ring, nutrient bars, water, and "Your goal could be" from his weight trend',
                  'الرئيسية: حلقة السعرات وأشرطة العناصر والماء، و"يمكن أن يكون هدفك" من اتجاه وزنه'),
              s.tr('Put food on the scale and Capture: the photo, the food Gemini names, calories from the weighed grams',
                  'ضع الطعام على الميزان واضغط التقاط: الصورة، واسم الطعام من Gemini، والسعرات من الوزن الفعلي'),
              s.tr('Add Next Food: weigh a mixed plate one food at a time', 'أضف الطعام التالي: زن طبقًا مختلطًا صنفًا بعد صنف'),
              s.tr("Diary: yesterday's kabsa with its leftovers weighed; Copy This Day to Today",
                  'السجل: كبسة الأمس مع وزن المتبقي منها، ونسخ اليوم إلى اليوم الحالي'),
              s.tr('A snack of dates: Gemini counted 3 pieces; change the count with − and +',
                  'وجبة تمر: عدّ Gemini ثلاث حبات، وغيّر العدد بـ − و +'),
              s.tr('Search: favourites and recent foods log again in one tap', 'البحث: المفضلة والأطعمة الأخيرة تُسجّل بلمسة واحدة'),
              s.tr('Scan a Barcode on Add Meal; the laban snacks came from a barcode',
                  'امسح الباركود من إضافة وجبة، ووجبات اللبن جاءت من باركود'),
              s.tr('Insights: charts, body weight, the Weekly Summary PDF', 'التحليلات: الرسوم والوزن وملخص الأسبوع PDF'),
            ],
          ),
        Showcase.diabetes => ShowcaseGuide(
            icon: MiqdarIcons.bloodtype,
            title: s.tr('Diabetes Mode', 'وضع السكري'),
            who: s.tr('Noura, 52, type 2 diabetes. Two weeks of meals and readings', 'نورة، 52 سنة، سكري النوع الثاني. أسبوعان من الوجبات والقراءات'),
            summary: s.tr(
              "Carbs come first, Miqdar's carb numbers, blood sugar beside meals, and the red warnings before eating.",
              'الكربوهيدرات أولًا، وأرقام الكربوهيدرات من مقدار، وسكر الدم بجانب الوجبات، والتحذيرات الحمراء قبل الأكل.',
            ),
            steps: [
              s.tr('Home: carbs come first, against her 45 g a meal', 'الرئيسية: الكربوهيدرات أولًا مقابل 45 غ لكل وجبة'),
              s.tr("The bell: yesterday's kunafa passed her sugar limit", 'الجرس: كنافة الأمس تجاوزت حد السكر لديها'),
              s.tr('Weigh a sweet drink or dessert: a red card before Save, the smaller portion that fits, one vibration',
                  'زن مشروبًا محلّى أو حلوى: بطاقة حمراء قبل الحفظ، والكمية الأصغر المناسبة، واهتزازة واحدة'),
              s.tr("The scale's own screen shows the warning too", 'شاشة الميزان نفسها تعرض التحذير أيضًا'),
              s.tr("A meal's screen: her blood sugar before and after it", 'شاشة الوجبة: سكر الدم قبلها وبعدها'),
              s.tr("Food Preferences: the carb numbers and sugar limit, with the no-medical-responsibility notice",
                  'تفضيلات الطعام: أرقام الكربوهيدرات وحد السكر، مع تنبيه عدم المسؤولية الطبية'),
              s.tr("Insights → Doctor's Report: a PDF of meals, carbs and readings", 'التحليلات ← تقرير الطبيب: ملف PDF بالوجبات والكربوهيدرات والقراءات'),
            ],
          ),
        Showcase.ramadan => ShowcaseGuide(
            icon: MiqdarIcons.calendarMonth,
            title: s.tr('Ramadan Mode', 'وضع رمضان'),
            who: s.tr('Faisal, 35, fasting. Eleven days of Ramadan', 'فيصل، 35 سنة، صائم. أحد عشر يومًا من رمضان'),
            summary: s.tr(
              'Iftar, Suhoor and Snack. The day runs noon to noon, so suhoor joins the night before.',
              'إفطار وسحور ووجبة خفيفة. اليوم من الظهر إلى الظهر، فيُحسب السحور مع الليلة التي قبله.',
            ),
            steps: [
              s.tr('Home: the fasting card and the Ramadan meal types', 'الرئيسية: بطاقة الصيام وأنواع وجبات رمضان'),
              s.tr('Diary: iftar with dates, laban, soup and samboosa, then suhoor before dawn on the same day',
                  'السجل: إفطار بالتمر واللبن والشوربة والسمبوسة، ثم السحور قبل الفجر في اليوم نفسه'),
              s.tr('Add a meal: the types offered are Iftar, Suhoor and Snack', 'أضف وجبة: الأنواع المتاحة إفطار وسحور ووجبة خفيفة'),
              s.tr('Meal reminders pause during Ramadan', 'تذكير الوجبات يتوقف في رمضان'),
              s.tr('Profile → Ramadan Mode turns it off again', 'ملفي ← وضع رمضان يوقفه'),
            ],
          ),
      };
}

/// Starts a scenario, or leaves one, from the splash. Shows a short wait while the data is written.
Future<void> startShowcase(BuildContext context, Showcase? showcase) async {
  final controller = MiqdarScope.of(context);
  final s = S.of(context);
  final switcher = controller.switchShowcase;
  if (switcher == null) return;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(showcase == null
                  ? s.tr('Opening your diary…', 'جارٍ فتح سجلك…')
                  : s.tr('Preparing the scenario…', 'جارٍ تجهيز السيناريو…')),
            ),
          ],
        ),
      ),
    ),
  );
  await switcher(showcase);
}

class ShowcaseScreen extends StatelessWidget {
  const ShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    final c = context.mq;
    final current = controller.showcase;

    return Scaffold(
      appBar: AppBar(title: Text(s.tr('Showcase Scenarios', 'سيناريوهات العرض'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.paddingOf(context).bottom + 24),
        children: [
          Text(
            s.tr(
              'Each scenario starts Miqdar again from the splash, with its own sample data. Your own diary is kept apart, untouched, and comes back when you leave. The scale works in every scenario.',
              'كل سيناريو يبدأ مقدار من جديد من شاشة البداية ببيانات نموذجية خاصة به. سجلك محفوظ بعيدًا دون أي تغيير، ويعود عند الخروج. الميزان يعمل في كل السيناريوهات.',
            ),
            style: MiqdarType.body.copyWith(color: c.inkMuted),
          ),
          if (current != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.tr('Now showing: ${ShowcaseGuide.of(current, s).title}', 'المعروض الآن: ${ShowcaseGuide.of(current, s).title}'),
                    style: MiqdarType.bodyStrong.copyWith(color: c.ink),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => startShowcase(context, null),
                    icon: const Icon(MiqdarIcons.logout),
                    label: Text(s.tr('Back to My Diary', 'العودة إلى سجلي')),
                  ),
                ],
              ),
            ),
          ],
          for (final showcase in Showcase.values) ...[
            const SizedBox(height: 16),
            _ScenarioCard(showcase: showcase, current: showcase == current),
          ],
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({required this.showcase, required this.current});

  final Showcase showcase;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.mq;
    final guide = ShowcaseGuide.of(showcase, s);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        border: current ? Border.all(color: c.ink, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(guide.icon, color: c.ink, size: 26),
              const SizedBox(width: 12),
              Expanded(child: Text(guide.title, style: MiqdarType.titleCard.copyWith(color: c.ink))),
            ],
          ),
          const SizedBox(height: 6),
          Text(guide.who, style: MiqdarType.bodyStrong.copyWith(fontSize: 14, color: c.inkMuted)),
          const SizedBox(height: 8),
          Text(guide.summary, style: MiqdarType.body.copyWith(color: c.ink)),
          const SizedBox(height: 12),
          ShowcaseSteps(guide: guide),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => startShowcase(context, showcase),
            icon: Icon(current ? MiqdarIcons.replay : MiqdarIcons.arrowForward),
            label: Text(current ? s.tr('Start Again', 'ابدأ من جديد') : s.tr('Start from the Splash', 'ابدأ من شاشة البداية')),
          ),
        ],
      ),
    );
  }
}

/// The numbered things to show in a scenario.
class ShowcaseSteps extends StatelessWidget {
  const ShowcaseSteps({super.key, required this.guide});

  final ShowcaseGuide guide;

  @override
  Widget build(BuildContext context) {
    final c = context.mq;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < guide.steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Text('${i + 1}', style: MiqdarType.bodyStrong.copyWith(fontSize: 14, color: c.inkMuted)),
                ),
                Expanded(child: Text(guide.steps[i], style: MiqdarType.body.copyWith(fontSize: 15, color: c.ink))),
              ],
            ),
          ),
      ],
    );
  }
}

/// A slim line on Home inside a scenario: which one, what to show, and the way back.
class ShowcaseBanner extends StatelessWidget {
  const ShowcaseBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final showcase = controller.showcase;
    if (showcase == null) return const SizedBox.shrink();
    final s = S.of(context);
    final c = context.mq;
    final guide = ShowcaseGuide.of(showcase, s);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 4, 4),
      decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(MiqdarIcons.science, color: c.accentInk, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.tr('${guide.title} · sample data', '${guide.title} · بيانات نموذجية'),
              style: MiqdarType.label.copyWith(color: c.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (sheet) => SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(guide.title, style: Theme.of(sheet).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(guide.who, style: MiqdarType.body.copyWith(color: c.inkMuted)),
                      const SizedBox(height: 16),
                      ShowcaseSteps(guide: guide),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.of(sheet).pop();
                          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ShowcaseScreen()));
                        },
                        child: Text(s.tr('All Scenarios', 'كل السيناريوهات')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            child: Text(s.tr('What to Show', 'ماذا أعرض')),
          ),
        ],
      ),
    );
  }
}
