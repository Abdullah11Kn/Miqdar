import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../app_controller.dart';
import '../models/nutrition.dart';
import '../theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SignInScreen()));
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF075D33), Color(0xFF42A95F)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 142,
                    height: 116,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Image.asset('assets/branding/miqdar-logo.png', fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 26),
                  const Text('Miqdar', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: Colors.white)),
                  const Text('مقدار', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFFD7F6DC))),
                  const SizedBox(height: 18),
                  const Text('SEE IT. TRACK IT. LIVE HEALTHY.', style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w800, color: Color(0xFFD7F6DC))),
                  const SizedBox(height: 120),
                  const Text('Smart nutrition, measured precisely.', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text('AI recognition + real weight + health alerts', style: TextStyle(color: Color(0xFFD7F6DC))),
                ],
              ),
            ),
          ),
        ),
      );
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final email = TextEditingController(text: 'jehad@example.com');
  final password = TextEditingController(text: 'miqdar252');
  bool obscure = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Row(children: [
                Image.asset('assets/branding/miqdar-logo.png', width: 48, height: 42, fit: BoxFit.contain),
                const SizedBox(width: 8),
                const Text('Miqdar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: MiqdarColors.primary)),
              ]),
              const SizedBox(height: 54),
              Text('Welcome back', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text('Sign in to continue your nutrition journey.'),
              const SizedBox(height: 34),
              TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 18),
              TextField(
                controller: password,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Reset password'),
                      content: Text('A demonstration reset link will be sent to ${email.text.trim()}.'),
                      actions: [
                        FilledButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Send link')),
                      ],
                    ),
                  ),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PairingScreen())),
                child: const Text('Sign in'),
              ),
              const SizedBox(height: 34),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PairingScreen())),
                icon: const Icon(Icons.account_circle_outlined),
                label: const Text('Continue with Google'),
              ),
              const SizedBox(height: 44),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('New to Miqdar?'),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateAccountScreen())),
                  child: const Text('Create account'),
                ),
              ]),
            ],
          ),
        ),
      );
}

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  String goal = 'Lose weight';
  bool accepted = true;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create account')),
        body: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const Text('Set up your personalized nutrition profile.'),
            const SizedBox(height: 24),
            const TextField(decoration: InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Email')),
            const SizedBox(height: 16),
            const TextField(obscureText: true, decoration: InputDecoration(labelText: 'Password')),
            const SizedBox(height: 22),
            const Text('Primary goal', style: TextStyle(fontWeight: FontWeight.w800, color: MiqdarColors.dark)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: ['Lose weight', 'Maintain', 'Build muscle'].map((item) => ChoiceChip(
              label: Text(item),
              selected: goal == item,
              onSelected: (_) => setState(() => goal = item),
            )).toList()),
            const SizedBox(height: 22),
            CheckboxListTile(
              value: accepted,
              contentPadding: EdgeInsets.zero,
              title: const Text('I agree to the privacy policy and terms.'),
              onChanged: (value) => setState(() => accepted = value ?? false),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: accepted ? () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PairingScreen())) : null,
              child: const Text('Create account'),
            ),
          ],
        ),
      );
}

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  bool pairing = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pair your Miqdar')),
        body: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              const Text('Connect once for hands-free meal logging.'),
              const Spacer(),
              Container(
                width: 224,
                height: 224,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: MiqdarColors.softGreen),
                child: const Icon(Icons.scale_outlined, size: 108, color: MiqdarColors.primary),
              ),
              const SizedBox(height: 24),
              Text(pairing ? 'Pairing securely…' : 'Miqdar-015 found', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Signal strength: Excellent', style: TextStyle(color: MiqdarColors.primary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 28),
              const _InfoRow(icon: Icons.wifi, title: 'KFU-Lab-WiFi', subtitle: 'Secure network'),
              const Spacer(),
              FilledButton(
                onPressed: pairing ? null : () async {
                  setState(() => pairing = true);
                  await Future<void>.delayed(const Duration(milliseconds: 650));
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
                },
                child: Text(pairing ? 'Pairing…' : 'Pair device'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell())),
                child: const Text('I’ll do this later'),
              ),
            ],
          ),
        ),
      );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onScan: () => setState(() => index = 1)),
      const ScanScreen(),
      const HistoryScreen(),
      const AlertsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.center_focus_weak), selectedIcon: Icon(Icons.center_focus_strong), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onScan});
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final totals = controller.todayTotals;
    final goals = controller.goals;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Good morning,', style: TextStyle(color: MiqdarColors.muted)),
            Text('Jehad', style: Theme.of(context).textTheme.headlineSmall),
          ])),
          const CircleAvatar(backgroundColor: MiqdarColors.primary, foregroundColor: Colors.white, child: Text('J', style: TextStyle(fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(color: MiqdarColors.softGreen, borderRadius: BorderRadius.circular(15)),
          child: Row(children: [
            Icon(Icons.circle, size: 10, color: controller.connectionStatus.startsWith('API online') ? MiqdarColors.primary : MiqdarColors.warning),
            const SizedBox(width: 10),
            Expanded(child: Text(controller.connectionStatus, style: const TextStyle(color: MiqdarColors.primary, fontWeight: FontWeight.w800))),
            const Text('Miqdar-015', style: TextStyle(fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 16),
        _SurfaceCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Daily progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: MiqdarColors.dark)),
            const SizedBox(height: 18),
            Row(children: [
              _ProgressRing(value: totals.calories / goals.calories, center: '${totals.calories.toStringAsFixed(0)}\nkcal'),
              const SizedBox(width: 22),
              Expanded(child: Column(children: [
                _ProgressLine(label: 'Protein', value: totals.protein, target: goals.protein, unit: 'g'),
                _ProgressLine(label: 'Carbs', value: totals.carbohydrates, target: goals.carbohydrates, unit: 'g'),
                _ProgressLine(label: 'Sugar', value: totals.sugar, target: goals.sugar, unit: 'g'),
              ])),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(children: [
            SizedBox(height: 176, width: double.infinity, child: Image.asset('assets/branding/miqdar-food.png', fit: BoxFit.cover)),
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [MiqdarColors.dark.withValues(alpha: .88), Colors.transparent])))),
            Positioned(
              left: 20,
              top: 20,
              bottom: 20,
              width: 190,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Ready to measure?', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('Place food on the scale and capture a clear photo.', style: TextStyle(color: Colors.white)),
                const Spacer(),
                FilledButton.icon(onPressed: onScan, icon: const Icon(Icons.center_focus_strong), label: const Text('Start scan')),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 22),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Meal ideas for you', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: MiqdarColors.dark)),
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MealSuggestionsScreen())),
            child: const Text('See all'),
          ),
        ]),
        if (controller.recommendationsBusy && controller.mealSuggestions.isEmpty)
          const LinearProgressIndicator()
        else if (controller.mealSuggestions.isEmpty)
          const _InfoRow(
            icon: Icons.restaurant_menu,
            title: 'Set your food preferences',
            subtitle: 'Add health considerations and exclusions to generate meal ideas.',
          )
        else
          ...controller.mealSuggestions.take(2).map((suggestion) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SuggestionCard(suggestion: suggestion, compact: true),
              )),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Recent meals', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: MiqdarColors.dark)),
          Text('${controller.meals.length} in 90 days', style: const TextStyle(fontSize: 12)),
        ]),
        const SizedBox(height: 10),
        ...controller.meals.take(3).map((meal) => _MealRow(meal: meal)),
      ],
    );
  }
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final picker = ImagePicker();
  XFile? image;
  String hint = 'medjool dates';
  double weight = 120;

  @override
  void initState() {
    super.initState();
    _restoreInterruptedPick();
  }

  Future<void> _restoreInterruptedPick() async {
    try {
      final response = await picker.retrieveLostData();
      final files = response.files;
      if (!response.isEmpty && files != null && files.isNotEmpty && mounted) {
        setState(() => image = files.first);
      }
    } catch (_) {
      // The presentation flow still has a bundled demonstration image.
    }
  }

  Future<void> pick(ImageSource source) async {
    try {
      final selected = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 1600);
      if (selected != null) setState(() => image = selected);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera access is unavailable. You can continue with the demo image.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      children: [
        Text('Live scan', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text('Photo + scale weight are evaluated together.'),
        const SizedBox(height: 20),
        Container(
          height: 290,
          decoration: BoxDecoration(
            color: MiqdarColors.dark,
            borderRadius: BorderRadius.circular(26),
            image: DecorationImage(
              image: image == null
                  ? const AssetImage('assets/branding/miqdar-food.png')
                  : FileImage(File(image!.path)),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(MiqdarColors.dark.withValues(alpha: .34), BlendMode.darken),
            ),
          ),
          child: Stack(children: [
            if (image == null) const Positioned(
              left: 18,
              top: 18,
              child: Chip(
                avatar: Icon(Icons.auto_awesome, size: 17, color: MiqdarColors.primary),
                label: Text('Demo image ready'),
              ),
            ),
            Center(child: Container(width: 220, height: 160, decoration: BoxDecoration(border: Border.all(color: MiqdarColors.lime, width: 3), borderRadius: BorderRadius.circular(24)))),
            Positioned(left: 14, right: 14, bottom: 14, child: Row(children: [
              Expanded(child: FilledButton.tonalIcon(onPressed: () => pick(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: const Text('Camera'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton.tonalIcon(onPressed: () => pick(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Gallery'))),
            ])),
          ]),
        ),
        const SizedBox(height: 16),
        _SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.scale_outlined, color: MiqdarColors.primary),
            const SizedBox(width: 10),
            const Expanded(child: Text('Scale weight', style: TextStyle(fontWeight: FontWeight.w800, color: MiqdarColors.dark))),
            Text('${weight.toStringAsFixed(0)} g', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: MiqdarColors.primary)),
          ]),
          Slider(value: weight, min: 10, max: 500, divisions: 98, label: '${weight.toStringAsFixed(0)} g', onChanged: (value) => setState(() => weight = value)),
          DropdownButtonFormField<String>(
            initialValue: hint,
            decoration: const InputDecoration(labelText: 'Demo recognition hint'),
            items: const ['medjool dates', 'white rice', 'chicken breast', 'hummus', 'banana'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
            onChanged: (value) => setState(() => hint = value ?? hint),
          ),
          const SizedBox(height: 8),
          const Text('The hint is used only in offline/demo mode. A configured cloud provider ignores it or treats it as optional context.', style: TextStyle(fontSize: 11)),
        ])),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: controller.busy ? null : () async {
            final result = await controller.recognize(image: image, weightG: weight, hint: hint);
            if (!context.mounted) return;
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecognitionResultScreen(result: result)));
          },
          icon: controller.busy ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome),
          label: Text(controller.busy ? 'Recognizing…' : 'Recognize food'),
        ),
      ],
    );
  }
}

class RecognitionResultScreen extends StatelessWidget {
  const RecognitionResultScreen({super.key, required this.result});
  final RecognitionResult result;

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Recognition result')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: MiqdarColors.primary, borderRadius: BorderRadius.circular(24)),
            child: Column(children: [
              const Icon(Icons.check_circle, size: 54, color: Colors.white),
              const SizedBox(height: 10),
              Text(result.nameEn, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: Colors.white)),
              Text(result.nameAr, style: const TextStyle(fontSize: 18, color: Color(0xFFD7F6DC))),
              const SizedBox(height: 14),
              Text('${result.weightG.toStringAsFixed(0)} g • ${(result.confidence * 100).toStringAsFixed(0)}% confidence', style: const TextStyle(color: Colors.white)),
            ]),
          ),
          const SizedBox(height: 18),
          _VerificationBanner(result: result),
          const SizedBox(height: 18),
          _NutrientGrid(values: result.nutrients),
          const SizedBox(height: 18),
          _SurfaceCard(child: Row(children: [
            Icon(controller.alertEvaluationMs <= 4000 ? Icons.bolt : Icons.timer_off_outlined, color: controller.alertEvaluationMs <= 4000 ? MiqdarColors.primary : MiqdarColors.danger),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(controller.alertEvaluationMs <= 4000 ? 'Alert timing passed' : 'Alert timing missed', style: const TextStyle(fontWeight: FontWeight.w800, color: MiqdarColors.dark)),
              Text('Local alert evaluation: ${controller.alertEvaluationMs} ms • requirement ≤ 4,000 ms'),
            ])),
          ])),
          if (controller.alerts.isNotEmpty) ...[
            const SizedBox(height: 18),
            _AlertCard(alert: controller.alerts.first),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              await controller.saveLastRecognition();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainShell()), (_) => false);
            },
            child: const Text('Save meal'),
          ),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Scan again')),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int days = 90;

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Nutrition history', style: Theme.of(context).textTheme.headlineSmall),
            const Text('Review meals for at least 90 days.'),
          ])),
          IconButton.filledTonal(
            tooltip: 'Trends',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrendsScreen())),
            icon: const Icon(Icons.query_stats),
          ),
        ]),
        const SizedBox(height: 18),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7 days')),
            ButtonSegment(value: 30, label: Text('30 days')),
            ButtonSegment(value: 90, label: Text('90 days')),
          ],
          selected: {days},
          onSelectionChanged: (selection) async {
            setState(() => days = selection.first);
            await controller.setHistoryWindow(days);
          },
        ),
        const SizedBox(height: 18),
        _SurfaceCard(child: Row(children: [
          const Icon(Icons.calendar_month, color: MiqdarColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text('${controller.meals.length} meals loaded', style: const TextStyle(fontWeight: FontWeight.w800, color: MiqdarColors.dark))),
          Text('$days-day window'),
        ])),
        const SizedBox(height: 12),
        ...controller.meals.map((meal) => InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MealDetailScreen(meal: meal))),
          child: _MealRow(meal: meal),
        )),
      ],
    );
  }
}

class MealDetailScreen extends StatelessWidget {
  const MealDetailScreen({super.key, required this.meal});
  final MealEntry meal;

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Meal details')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MiqdarColors.softGreen,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: MiqdarColors.primary,
                foregroundColor: Colors.white,
                child: Text(
                  meal.nameEn.isEmpty ? '?' : meal.nameEn.substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(meal.mealType, style: const TextStyle(fontSize: 12, color: MiqdarColors.primary, fontWeight: FontWeight.w800)),
                Text(meal.nameEn, style: Theme.of(context).textTheme.titleLarge),
                Text(meal.nameAr, style: const TextStyle(fontSize: 16, color: MiqdarColors.primary)),
              ])),
              Text('${meal.nutrients.calories.toStringAsFixed(0)}\nkcal', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800, color: MiqdarColors.primary)),
            ]),
          ),
          const SizedBox(height: 14),
          Text('${DateFormat('EEE, d MMM yyyy • h:mm a').format(meal.eatenAt.toLocal())} • ${meal.weightG.toStringAsFixed(0)} g • ${(meal.confidence * 100).toStringAsFixed(0)}% confidence'),
          const SizedBox(height: 18),
          const Text('Nutrition facts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: MiqdarColors.dark)),
          const SizedBox(height: 10),
          _NutrientGrid(values: meal.nutrients),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () => _showEditMealSheet(context, controller),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit meal'),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: MiqdarColors.danger),
            onPressed: () => _confirmDelete(context, controller),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete meal'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditMealSheet(
    BuildContext context,
    MiqdarController controller,
  ) async {
    var selectedType = meal.mealType;
    final weightController = TextEditingController(text: meal.weightG.toStringAsFixed(0));
    final updated = await showModalBottomSheet<MealEntry>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(22, 22, 22, MediaQuery.viewInsetsOf(context).bottom + 22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Edit meal', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: selectedType,
              decoration: const InputDecoration(labelText: 'Meal type'),
              items: const ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Meal']
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (value) => setSheetState(() => selectedType = value ?? selectedType),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Weight (g)'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                final weight = double.tryParse(weightController.text.trim());
                if (weight == null || weight <= 0) return;
                final factor = meal.weightG <= 0 ? 1.0 : weight / meal.weightG;
                Navigator.of(sheetContext).pop(meal.copyWith(
                  mealType: selectedType,
                  weightG: weight,
                  nutrients: meal.nutrients.scaledBy(factor),
                ));
              },
              child: const Text('Save changes'),
            ),
          ]),
        ),
      ),
    );
    weightController.dispose();
    if (updated == null) return;
    await controller.updateMeal(updated);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MiqdarController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this meal?'),
        content: const Text('This removes the entry from nutrition history.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.deleteMeal(meal.id);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class TrendsScreen extends StatelessWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final meals = controller.meals;
    final totals = meals.fold(NutritionValues.zero(), (sum, meal) => sum + meal.nutrients);
    final divisor = meals.isEmpty ? 1 : meals.length;
    final recent = meals.take(7).toList().reversed.toList();
    final averageCalories = totals.calories / divisor;
    final referenceCalories = controller.goals.calories / 3;
    final consistency = referenceCalories <= 0
        ? 0.0
        : (1 - ((averageCalories - referenceCalories).abs() / referenceCalories))
            .clamp(0.0, 1.0)
            .toDouble();
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition trends')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Text('Patterns across your nutrition history'),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _MetricCard(label: 'Average calories', value: averageCalories.toStringAsFixed(0), detail: 'kcal / meal')),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(label: 'Goal consistency', value: '${(consistency * 100).round()}%', detail: 'vs meal reference')),
          ]),
          const SizedBox(height: 22),
          const Text('Calories vs goal', style: TextStyle(fontWeight: FontWeight.w800, color: MiqdarColors.dark)),
          const SizedBox(height: 10),
          _WeeklyTrendChart(meals: recent, target: referenceCalories),
          const SizedBox(height: 22),
          const Text('Macro balance', style: TextStyle(fontWeight: FontWeight.w800, color: MiqdarColors.dark)),
          const SizedBox(height: 10),
          _MacroBalance(values: totals),
          const SizedBox(height: 22),
          const Text('Average per logged meal', style: TextStyle(fontWeight: FontWeight.w800, color: MiqdarColors.dark)),
          const SizedBox(height: 12),
          _TrendBar(label: 'Calories', value: totals.calories / divisor, target: controller.goals.calories / 3, unit: 'kcal'),
          _TrendBar(label: 'Protein', value: totals.protein / divisor, target: controller.goals.protein / 3, unit: 'g'),
          _TrendBar(label: 'Carbohydrates', value: totals.carbohydrates / divisor, target: controller.goals.carbohydrates / 3, unit: 'g'),
          _TrendBar(label: 'Sugar', value: totals.sugar / divisor, target: controller.goals.sugar / 3, unit: 'g'),
          _TrendBar(label: 'Sodium', value: totals.sodium / divisor, target: controller.goals.sodium / 3, unit: 'mg'),
          const SizedBox(height: 16),
          const _InfoRow(icon: Icons.info_outline, title: '90-day retention', subtitle: 'The local database seeds and queries a full 90-day window.'),
        ],
      ),
    );
  }
}

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Health alerts', style: Theme.of(context).textTheme.headlineSmall),
            const Text('Sugar, sodium, potassium, carbs and calories'),
          ])),
          IconButton.filledTonal(
            tooltip: 'Manage thresholds',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GoalsScreen())),
            icon: const Icon(Icons.tune),
          ),
        ]),
        const SizedBox(height: 18),
        _SurfaceCard(child: Row(children: [
          const Icon(Icons.bolt, color: MiqdarColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text('Last evaluation: ${controller.alertEvaluationMs} ms', style: const TextStyle(fontWeight: FontWeight.w800, color: MiqdarColors.dark))),
          const Text('SLO ≤ 4 s'),
        ])),
        const SizedBox(height: 14),
        if (controller.alerts.isEmpty)
          const _InfoRow(icon: Icons.check_circle_outline, title: 'No active alerts', subtitle: 'Your current meal totals are within configured thresholds.')
        else
          ...controller.alerts.map((alert) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _AlertCard(alert: alert))),
      ],
    );
  }
}

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  NutritionGoals? draft;

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    draft ??= controller.goals;
    return Scaffold(
      appBar: AppBar(title: const Text('Goals & limits')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Text('These are user-configurable prototype thresholds, not medical recommendations.'),
          const SizedBox(height: 18),
          _GoalSlider(label: 'Calories', value: draft!.calories, min: 1000, max: 4000, unit: 'kcal', onChanged: (v) => setState(() => draft = draft!.copyWith(calories: v))),
          _GoalSlider(label: 'Sugar', value: draft!.sugar, min: 10, max: 150, unit: 'g', onChanged: (v) => setState(() => draft = draft!.copyWith(sugar: v))),
          _GoalSlider(label: 'Sodium', value: draft!.sodium, min: 500, max: 5000, unit: 'mg', onChanged: (v) => setState(() => draft = draft!.copyWith(sodium: v))),
          _GoalSlider(label: 'Potassium', value: draft!.potassium, min: 1000, max: 6000, unit: 'mg', onChanged: (v) => setState(() => draft = draft!.copyWith(potassium: v))),
          _GoalSlider(label: 'Carbohydrates', value: draft!.carbohydrates, min: 50, max: 500, unit: 'g', onChanged: (v) => setState(() => draft = draft!.copyWith(carbohydrates: v))),
          _GoalSlider(label: 'Protein', value: draft!.protein, min: 30, max: 250, unit: 'g', onChanged: (v) => setState(() => draft = draft!.copyWith(protein: v))),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: () async {
              await controller.updateGoals(draft!);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Save thresholds'),
          ),
        ],
      ),
    );
  }
}

class MealSuggestionsScreen extends StatefulWidget {
  const MealSuggestionsScreen({super.key});

  @override
  State<MealSuggestionsScreen> createState() => _MealSuggestionsScreenState();
}

class _MealSuggestionsScreenState extends State<MealSuggestionsScreen> {
  static const conditionLabels = <String, String>{
    'diabetes': 'Diabetes / blood-sugar awareness',
    'hypertension': 'Hypertension / sodium awareness',
    'high_cholesterol': 'High cholesterol',
    'weight_management': 'Weight management',
    'kidney_disease': 'Kidney condition (clinician targets required)',
  };
  static const preferenceLabels = <String, String>{
    'vegetarian': 'Vegetarian',
    'vegan': 'Vegan',
  };

  HealthProfile? draft;
  late final TextEditingController allergens;
  late final TextEditingController dislikes;
  bool initialized = false;

  @override
  void initState() {
    super.initState();
    allergens = TextEditingController();
    dislikes = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    final profile = MiqdarScope.of(context).healthProfile;
    draft = profile;
    allergens.text = profile.allergens.join(', ');
    dislikes.text = profile.dislikedFoods.join(', ');
    initialized = true;
  }

  @override
  void dispose() {
    allergens.dispose();
    dislikes.dispose();
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
    final profile = draft ?? controller.healthProfile;
    return Scaffold(
      appBar: AppBar(title: const Text('Meal suggestions')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6E7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF0D9A8)),
            ),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, color: MiqdarColors.warning),
              SizedBox(width: 12),
              Expanded(child: Text(
                'Miqdar uses your selected considerations, configured nutrition targets, and the last 14 days of meals. Suggestions are general planning support, not diagnosis or medical advice.',
              )),
            ]),
          ),
          const SizedBox(height: 22),
          const Text('Health considerations', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: MiqdarColors.dark)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: conditionLabels.entries.map((entry) => FilterChip(
              label: Text(entry.value),
              selected: profile.conditions.contains(entry.key),
              onSelected: (selected) => _toggleCondition(entry.key, selected),
            )).toList(),
          ),
          const SizedBox(height: 18),
          const Text('Dietary preferences', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: MiqdarColors.dark)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: preferenceLabels.entries.map((entry) => FilterChip(
              label: Text(entry.value),
              selected: profile.dietaryPreferences.contains(entry.key),
              onSelected: (selected) => _togglePreference(entry.key, selected),
            )).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: allergens,
            decoration: const InputDecoration(
              labelText: 'Allergens or foods to exclude',
              hintText: 'Example: nuts, dairy, fish',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: dislikes,
            decoration: const InputDecoration(
              labelText: 'Disliked foods',
              hintText: 'Example: tomato, egg',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: controller.recommendationsBusy ? null : () async {
              final value = profile.copyWith(
                allergens: _csv(allergens.text),
                dislikedFoods: _csv(dislikes.text),
              );
              setState(() => draft = value);
              await controller.updateHealthProfile(value);
            },
            icon: controller.recommendationsBusy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(controller.recommendationsBusy ? 'Updating suggestions…' : 'Save and refresh suggestions'),
          ),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Suggested next meals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: MiqdarColors.dark)),
            if (controller.recommendationsOffline)
              const Chip(label: Text('Offline')),
          ]),
          const SizedBox(height: 10),
          if (controller.mealSuggestions.isEmpty && !controller.recommendationsBusy)
            const _InfoRow(icon: Icons.restaurant_menu, title: 'No suggestions yet', subtitle: 'Save the profile to calculate meal ideas.')
          else
            ...controller.mealSuggestions.map((suggestion) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SuggestionCard(suggestion: suggestion),
                )),
          if (controller.recommendationDisclaimer.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(controller.recommendationDisclaimer, style: const TextStyle(fontSize: 12, color: MiqdarColors.muted)),
          ],
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
        children: [
          Text('Profile', style: Theme.of(context).textTheme.headlineSmall),
          const Text('Account, device and preferences'),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: MiqdarColors.primary, borderRadius: BorderRadius.circular(24)),
            child: const Row(children: [
              CircleAvatar(radius: 34, backgroundColor: Colors.white, foregroundColor: MiqdarColors.primary, child: Text('J', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800))),
              SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Jehad Hasan Alharbi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('jehad@example.com', style: TextStyle(color: Color(0xFFD0F0D8))),
                SizedBox(height: 8),
                Text('Miqdar member', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              ])),
            ]),
          ),
          const SizedBox(height: 22),
          const Text('Account & device', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: MiqdarColors.dark)),
          const SizedBox(height: 10),
          const _InfoRow(icon: Icons.person_outline, title: 'Personal information', subtitle: 'Jehad Hasan Alharbi'),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GoalsScreen())),
            child: const _InfoRow(icon: Icons.track_changes, title: 'Goals & limits', subtitle: 'Calories • Nutrients • Custom thresholds'),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MealSuggestionsScreen())),
            child: const _InfoRow(icon: Icons.restaurant_menu, title: 'Smart meal suggestions', subtitle: 'Health considerations • Preferences • Recent meals'),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DeviceSettingsScreen())),
            child: const _InfoRow(icon: Icons.link, title: 'Connected device', subtitle: 'Miqdar-015 • Online'),
          ),
          const _InfoRow(icon: Icons.wifi, title: 'Wi-Fi network', subtitle: 'KFU-Lab-WiFi'),
          const SizedBox(height: 18),
          const _PreferenceSwitch(),
        ],
      );
}

class DeviceSettingsScreen extends StatefulWidget {
  const DeviceSettingsScreen({super.key});

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  bool autoSync = true;
  bool sound = true;
  bool paired = true;
  double brightness = .75;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Device settings')),
        body: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            _SurfaceCard(child: Row(children: [
              Container(width: 86, height: 64, decoration: BoxDecoration(color: MiqdarColors.softGreen, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.scale_outlined, color: MiqdarColors.primary, size: 42)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(paired ? 'Miqdar-015 • Online' : 'Miqdar-015 • Unpaired', style: TextStyle(fontWeight: FontWeight.w800, color: paired ? MiqdarColors.primary : MiqdarColors.muted)),
                const Text('Firmware 0.9.2'),
                Text(paired ? 'Last sync: just now' : 'Connect to resume syncing'),
              ])),
            ])),
            const SizedBox(height: 20),
            const _InfoRow(icon: Icons.wifi, title: 'KFU-Lab-WiFi', subtitle: 'Excellent signal'),
            SwitchListTile(title: const Text('Auto-sync meals'), value: autoSync, onChanged: (value) => setState(() => autoSync = value)),
            ListTile(
              title: const Text('Display brightness'),
              subtitle: Slider(value: brightness, onChanged: (value) => setState(() => brightness = value)),
              trailing: Text('${(brightness * 100).round()}%'),
            ),
            SwitchListTile(title: const Text('Recognition sound'), value: sound, onChanged: (value) => setState(() => sound = value)),
            const _InfoRow(icon: Icons.system_update_alt, title: 'Firmware', subtitle: 'Version 0.9.2 is current'),
            const SizedBox(height: 26),
            OutlinedButton(
              onPressed: paired ? () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Unpair Miqdar-015?'),
                    content: const Text('You can pair the scale again from the connection screen.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Unpair')),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  setState(() => paired = false);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Miqdar-015 was unpaired.')));
                }
              } : null,
              child: Text(paired ? 'Unpair device' : 'Device unpaired'),
            ),
          ],
        ),
      );
}

class _PreferenceSwitch extends StatefulWidget {
  const _PreferenceSwitch();

  @override
  State<_PreferenceSwitch> createState() => _PreferenceSwitchState();
}

class _PreferenceSwitchState extends State<_PreferenceSwitch> {
  bool enabled = true;
  @override
  Widget build(BuildContext context) => SwitchListTile(
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: const BorderSide(color: MiqdarColors.border)),
        title: const Text('Push notifications', style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: const Text('Alerts and meal summaries'),
        value: enabled,
        onChanged: (value) => setState(() => enabled = value),
      );
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion, this.compact = false});
  final MealSuggestion suggestion;
  final bool compact;

  @override
  Widget build(BuildContext context) => _SurfaceCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const CircleAvatar(
              backgroundColor: MiqdarColors.softGreen,
              foregroundColor: MiqdarColors.primary,
              child: Icon(Icons.restaurant),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(suggestion.nameEn, style: const TextStyle(fontWeight: FontWeight.w800, color: MiqdarColors.dark, fontSize: 16)),
              if (suggestion.nameAr.isNotEmpty) Text(suggestion.nameAr),
            ])),
            Text('${suggestion.portionG.toStringAsFixed(0)} g', style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Chip(label: Text('${suggestion.nutrients.calories.toStringAsFixed(0)} kcal')),
            Chip(label: Text('${suggestion.nutrients.protein.toStringAsFixed(1)} g protein')),
            if (!compact) Chip(label: Text('${suggestion.nutrients.sodium.toStringAsFixed(0)} mg sodium')),
          ]),
          const SizedBox(height: 8),
          Text(
            suggestion.why.join(' • '),
            maxLines: compact ? 2 : null,
            overflow: compact ? TextOverflow.ellipsis : null,
          ),
        ]),
      );
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: MiqdarColors.border)),
        child: child,
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: MiqdarColors.border)),
        child: Row(children: [
          CircleAvatar(backgroundColor: MiqdarColors.softGreen, foregroundColor: MiqdarColors.primary, child: Icon(icon)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: MiqdarColors.dark)),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(fontSize: 12)),
          ])),
          const Icon(Icons.chevron_right, color: MiqdarColors.muted),
        ]),
      );
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.value, required this.center});
  final double value;
  final String center;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 112,
        height: 112,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(width: 112, height: 112, child: CircularProgressIndicator(value: value.clamp(0.0, 1.0).toDouble(), strokeWidth: 11, backgroundColor: MiqdarColors.softGreen, color: MiqdarColors.primary, strokeCap: StrokeCap.round)),
          Text(center, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, color: MiqdarColors.dark)),
        ]),
      );
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.label, required this.value, required this.target, required this.unit});
  final String label;
  final double value;
  final double target;
  final String unit;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))), Text('${value.toStringAsFixed(0)}/${target.toStringAsFixed(0)} $unit', style: const TextStyle(fontSize: 11))]),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: (value / target).clamp(0.0, 1.0).toDouble(), minHeight: 8, borderRadius: BorderRadius.circular(8), backgroundColor: MiqdarColors.softGreen),
        ]),
      );
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.meal});
  final MealEntry meal;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: MiqdarColors.border)),
        child: Row(children: [
          const CircleAvatar(backgroundColor: MiqdarColors.softGreen, foregroundColor: MiqdarColors.primary, child: Icon(Icons.restaurant)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(meal.nameEn, style: const TextStyle(fontWeight: FontWeight.w800, color: MiqdarColors.dark)),
            Text('${DateFormat('d MMM • h:mm a').format(meal.eatenAt.toLocal())} • ${meal.weightG.toStringAsFixed(0)} g', style: const TextStyle(fontSize: 11)),
          ])),
          Text('${meal.nutrients.calories.toStringAsFixed(0)}\nkcal', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800, color: MiqdarColors.primary)),
        ]),
      );
}

class _NutrientGrid extends StatelessWidget {
  const _NutrientGrid({required this.values});
  final NutritionValues values;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Calories', values.calories, 'kcal', Icons.local_fire_department_outlined),
      ('Protein', values.protein, 'g', Icons.fitness_center),
      ('Carbs', values.carbohydrates, 'g', Icons.grain),
      ('Fat', values.fat, 'g', Icons.water_drop_outlined),
      ('Sugar', values.sugar, 'g', Icons.cookie_outlined),
      ('Sodium', values.sodium, 'mg', Icons.science_outlined),
      ('Potassium', values.potassium, 'mg', Icons.bolt_outlined),
      ('Fiber', values.fiber, 'g', Icons.eco_outlined),
    ];
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.65,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items.map((item) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: MiqdarColors.border)),
        child: Row(children: [
          Icon(item.$4, color: MiqdarColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.$1, style: const TextStyle(fontSize: 11)),
            Text('${item.$2.toStringAsFixed(item.$2 >= 100 ? 0 : 1)} ${item.$3}', style: const TextStyle(fontWeight: FontWeight.w800, color: MiqdarColors.dark)),
          ])),
        ]),
      )).toList(),
    );
  }
}

class _VerificationBanner extends StatelessWidget {
  const _VerificationBanner({required this.result});
  final RecognitionResult result;

  @override
  Widget build(BuildContext context) {
    final verified = result.verificationStatus == 'verified_official_record';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: verified ? MiqdarColors.softGreen : const Color(0xFFFFF3E4), borderRadius: BorderRadius.circular(17)),
      child: Row(children: [
        Icon(verified ? Icons.verified_outlined : Icons.info_outline, color: verified ? MiqdarColors.primary : MiqdarColors.warning),
        const SizedBox(width: 10),
        Expanded(child: Text(verified ? 'Verified official nutrient record' : 'Prototype nutrient seed — sync an exact official record before production', style: const TextStyle(fontWeight: FontWeight.w700))),
        Chip(label: Text(result.isMock ? 'Offline' : (result.model ?? result.provider))),
      ]),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});
  final HealthAlert alert;

  @override
  Widget build(BuildContext context) {
    final critical = alert.severity == 'critical';
    final color = critical ? MiqdarColors.danger : MiqdarColors.warning;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withValues(alpha: .3))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(critical ? Icons.warning_amber_rounded : Icons.notifications_active_outlined, color: color),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(alert.severity.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(alert.message, style: const TextStyle(color: MiqdarColors.dark)),
          const SizedBox(height: 4),
          Text('Evaluated in ${alert.evaluationMs} ms', style: const TextStyle(fontSize: 11)),
        ])),
      ]),
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({required this.label, required this.value, required this.target, required this.unit});
  final String label;
  final double value;
  final double target;
  final String unit;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: _SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: MiqdarColors.dark))), Text('${value.toStringAsFixed(0)} $unit')]),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: (value / target).clamp(0.0, 1.0).toDouble(), minHeight: 12, borderRadius: BorderRadius.circular(8), backgroundColor: MiqdarColors.softGreen),
          const SizedBox(height: 6),
          Text('Per-meal reference ${(target).toStringAsFixed(0)} $unit', style: const TextStyle(fontSize: 11)),
        ])),
      );
}

class _GoalSlider extends StatelessWidget {
  const _GoalSlider({required this.label, required this.value, required this.min, required this.max, required this.unit, required this.onChanged});
  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: MiqdarColors.dark))), Text('${value.toStringAsFixed(0)} $unit', style: const TextStyle(fontWeight: FontWeight.w800, color: MiqdarColors.primary))]),
          Slider(value: value.clamp(min, max).toDouble(), min: min, max: max, divisions: 100, onChanged: onChanged),
        ])),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MiqdarColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Color(0xFFD7F6DC), fontSize: 11)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
          Text(detail, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ]),
      );
}

class _WeeklyTrendChart extends StatelessWidget {
  const _WeeklyTrendChart({required this.meals, required this.target});
  final List<MealEntry> meals;
  final double target;

  @override
  Widget build(BuildContext context) => Container(
        height: 220,
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: MiqdarColors.border),
        ),
        child: CustomPaint(
          painter: _WeeklyTrendPainter(meals: meals, target: target),
          child: const SizedBox.expand(),
        ),
      );
}

class _WeeklyTrendPainter extends CustomPainter {
  const _WeeklyTrendPainter({required this.meals, required this.target});
  final List<MealEntry> meals;
  final double target;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(34, 8, size.width - 46, size.height - 38);
    final gridPaint = Paint()..color = MiqdarColors.border..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    if (meals.isEmpty) return;

    var maxY = target * 1.25;
    for (final meal in meals) {
      maxY = math.max(maxY, meal.nutrients.calories).toDouble();
    }
    if (maxY <= 0) maxY = 1;
    final targetY = chart.bottom - (target / maxY).clamp(0.0, 1.0).toDouble() * chart.height;
    final targetPaint = Paint()..color = MiqdarColors.warning..strokeWidth = 1.4;
    for (var x = chart.left; x < chart.right; x += 10) {
      canvas.drawLine(Offset(x, targetY), Offset(math.min(x + 5, chart.right).toDouble(), targetY), targetPaint);
    }

    final path = Path();
    final pointPaint = Paint()..color = MiqdarColors.primary;
    for (var i = 0; i < meals.length; i++) {
      final x = meals.length == 1 ? chart.center.dx : chart.left + chart.width * i / (meals.length - 1);
      final y = chart.bottom - (meals[i].nutrients.calories / maxY).clamp(0.0, 1.0).toDouble() * chart.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
      final label = DateFormat('d').format(meals[i].eatenAt.toLocal());
      final textPainter = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(fontSize: 9, color: MiqdarColors.muted)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, chart.bottom + 8));
    }
    canvas.drawPath(path, Paint()..color = MiqdarColors.primary..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _WeeklyTrendPainter oldDelegate) =>
      oldDelegate.meals != meals || oldDelegate.target != target;
}

class _MacroBalance extends StatelessWidget {
  const _MacroBalance({required this.values});
  final NutritionValues values;

  @override
  Widget build(BuildContext context) {
    final protein = values.protein * 4;
    final carbs = values.carbohydrates * 4;
    final fat = values.fat * 9;
    final total = protein + carbs + fat;
    double percent(double value) => total <= 0 ? 0.0 : value / total;
    final entries = [
      ('Protein', percent(protein), MiqdarColors.primary),
      ('Carbs', percent(carbs), MiqdarColors.warning),
      ('Fat', percent(fat), const Color(0xFF5A91D8)),
    ];
    return _SurfaceCard(
      child: Row(children: [
        SizedBox(
          width: 116,
          height: 116,
          child: CustomPaint(
            painter: _MacroDonutPainter(values: entries.map((entry) => (entry.$2, entry.$3)).toList()),
            child: const Center(child: Text('history\nview', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: MiqdarColors.dark))),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(child: Column(children: entries.map((entry) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: entry.$3, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(entry.$1, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text('${(entry.$2 * 100).round()}%'),
          ]),
        )).toList())),
      ]),
    );
  }
}

class _MacroDonutPainter extends CustomPainter {
  const _MacroDonutPainter({required this.values});
  final List<(double, Color)> values;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);
    var start = -math.pi / 2;
    for (final value in values) {
      final sweep = math.pi * 2 * value.$1;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()..color = value.$2..style = PaintingStyle.stroke..strokeWidth = 14..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _MacroDonutPainter oldDelegate) => oldDelegate.values != values;
}
