import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../app_controller.dart';
import '../data/food_catalog.dart';
import '../l10n/strings.dart';
import '../models/nutrition.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'screens.dart';
import 'widgets/charts_and_gauges.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final picker = ImagePicker();
  late int modeIndex = widget.initialTab; // 0: Smart Scan, 1: Search Catalog, 2: Custom Food

  XFile? image;
  Uint8List? imageBytes;
  String? imageFileName;
  String? selectedSampleAsset;
  String? selectedSampleLabelEn;
  String? selectedSampleLabelAr;
  String? hint;
  double weight = 180;
  PortionSource portionSource = PortionSource.scale;
  late final TextEditingController weightTextCtrl = TextEditingController(text: '180');
  late final TextEditingController hintTextCtrl = TextEditingController();
  RecognitionException? lastError;

  static const List<({String asset, String labelEn, String labelAr, double defaultWeightG})>
      _samplePhotos = [
    (
      asset: 'assets/demo/kabsa.jpg',
      labelEn: 'Chicken Kabsa',
      labelAr: 'كبسة دجاج',
      defaultWeightG: 280,
    ),
    (
      asset: 'assets/demo/shawarma.jpeg',
      labelEn: 'Shawarma',
      labelAr: 'شاورما دجاج',
      defaultWeightG: 180,
    ),
    (
      asset: 'assets/demo/jareesh.jpeg',
      labelEn: 'Jareesh',
      labelAr: 'جريش سعودي',
      defaultWeightG: 240,
    ),
    (
      asset: 'assets/demo/pizza.jpeg',
      labelEn: 'Cheese Pizza',
      labelAr: 'بيتزا بالجبن',
      defaultWeightG: 165,
    ),
    (
      asset: 'assets/demo/burger.jpg',
      labelEn: 'Beef Burger',
      labelAr: 'برجر لحم',
      defaultWeightG: 220,
    ),
  ];

  // Catalog Search state
  final searchCtrl = TextEditingController();
  String selectedCategory = 'All';

  // Custom Food form state
  final customNameEnCtrl = TextEditingController();
  final customNameArCtrl = TextEditingController();
  final customBasisCtrl = TextEditingController(text: '100');
  final customPortionCtrl = TextEditingController(text: '150');
  final customKcalCtrl = TextEditingController();
  final customProteinCtrl = TextEditingController();
  final customCarbsCtrl = TextEditingController();
  final customFatCtrl = TextEditingController();
  final customSugarCtrl = TextEditingController();
  final customFiberCtrl = TextEditingController();
  final customSodiumCtrl = TextEditingController();
  final customPotassiumCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _restoreInterruptedPick();
  }

  @override
  void dispose() {
    weightTextCtrl.dispose();
    hintTextCtrl.dispose();
    searchCtrl.dispose();
    customNameEnCtrl.dispose();
    customNameArCtrl.dispose();
    customBasisCtrl.dispose();
    customPortionCtrl.dispose();
    customKcalCtrl.dispose();
    customProteinCtrl.dispose();
    customCarbsCtrl.dispose();
    customFatCtrl.dispose();
    customSugarCtrl.dispose();
    customFiberCtrl.dispose();
    customSodiumCtrl.dispose();
    customPotassiumCtrl.dispose();
    super.dispose();
  }

  Future<void> _restoreInterruptedPick() async {
    try {
      final response = await picker.retrieveLostData();
      final files = response.files;
      if (!response.isEmpty && files != null && files.isNotEmpty && mounted) {
        final bytes = await files.first.readAsBytes();
        if (!mounted) return;
        setState(() {
          image = files.first;
          imageBytes = bytes;
          imageFileName = files.first.name;
          selectedSampleAsset = null;
          hint = null;
        });
      }
    } catch (_) {}
  }

  Future<void> _pickFromFileSystem() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic'],
      );
      if (file == null) return;
      final bytes = await file.xFile.readAsBytes();
      if (bytes.isEmpty) return;
      if (!mounted) return;
      setState(() {
        image = file.xFile;
        imageBytes = bytes;
        imageFileName = file.name;
        selectedSampleAsset = null;
        selectedSampleLabelEn = null;
        selectedSampleLabelAr = null;
        hint = null;
        lastError = null;
      });
    } catch (e) {
      if (!mounted) return;
      final s = S.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.tr('Could not open file: $e', 'تعذر فتح الملف: $e'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final selected = await picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1600,
      );
      if (selected == null) return;
      final bytes = await selected.readAsBytes();
      if (!mounted) return;
      setState(() {
        image = selected;
        imageBytes = bytes;
        imageFileName = selected.name;
        selectedSampleAsset = null;
        selectedSampleLabelEn = null;
        selectedSampleLabelAr = null;
        hint = null;
        lastError = null;
      });
    } catch (_) {
      if (!mounted) return;
      if (source == ImageSource.camera) {
        await _pickImage(ImageSource.gallery);
        return;
      }
      final s = S.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.tr(
              'Photo picker unavailable. Try choosing from Mac / Files.',
              'معرض الصور غير متاح. جرب اختيار ملف من الماك.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _captureFromScaleCamera() async {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);

    if (!controller.scaleDevice.online) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.tr(
              'Scale is offline. Tap the Miqdar Scale icon on the Raspberry Pi, then enter the address shown on its screen.',
              'الميزان غير متصل. اضغط أيقونة Miqdar Scale على الراسبيري باي ثم أدخل العنوان الظاهر على شاشته.',
            ),
          ),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: s.tr('Configure URL', 'ضبط الرابط'),
            textColor: Colors.white,
            onPressed: () => showApiUrlDialog(context, controller),
          ),
        ),
      );
      return;
    }

    setState(() => lastError = null);
    try {
      final res = await controller.captureFromScale();
      if (!mounted || res == null) return;
      setState(() {
        weight = res.weightG;
        weightTextCtrl.text = res.weightG.toStringAsFixed(0);
        portionSource = PortionSource.scale;
        imageBytes = res.imageBytes;
        imageFileName = '${res.nameEn}.jpg';
      });
    } on RecognitionException catch (e) {
      if (!mounted) return;
      // The scale published this failure with its photo; MainShell is already showing it.
      if (e.eventId != null) return;
      final rawMsg = e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(rawMsg),
          backgroundColor: MiqdarColors.danger,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: s.tr('Change URL', 'تغيير الرابط'),
            textColor: Colors.white,
            onPressed: () => showApiUrlDialog(context, controller),
          ),
        ),
      );
    }
  }

  Future<void> _selectSamplePhoto(
    ({String asset, String labelEn, String labelAr, double defaultWeightG}) sample,
  ) async {
    try {
      final data = await rootBundle.load(sample.asset);
      final bytes = data.buffer.asUint8List();
      if (!mounted) return;
      setState(() {
        image = null;
        imageBytes = bytes;
        imageFileName = '${sample.labelEn}.jpg';
        selectedSampleAsset = sample.asset;
        selectedSampleLabelEn = sample.labelEn;
        selectedSampleLabelAr = sample.labelAr;
        hint = null;
        lastError = null;
      });
      _setWeight(sample.defaultWeightG, source: PortionSource.manual);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        selectedSampleAsset = sample.asset;
        selectedSampleLabelEn = sample.labelEn;
        selectedSampleLabelAr = sample.labelAr;
      });
    }
  }

  void _showImageSourceSheet(BuildContext context, S s, bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141C18) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              s.tr('Choose Meal Photo', 'اختر صورة الوجبة'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF111815),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              s.tr(
                'Select from your Mac files, photo gallery, or camera',
                'اختر من ملفات جهازك، أو معرض الصور، أو الكاميرا',
              ),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? MiqdarColors.darkMuted : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 18),
            _PhotoSourceTile(
              icon: Icons.folder_open_rounded,
              title: s.tr('Browse Mac / Device Files', 'تصفح ملفات الماك / الجهاز'),
              subtitle: s.tr('Choose any JPG, PNG, WEBP, or HEIC image file', 'اختر أي صورة بصيغة JPG أو PNG أو WEBP'),
              highlight: true,
              isDark: isDark,
              onTap: () {
                Navigator.of(ctx).pop();
                _pickFromFileSystem();
              },
            ),
            const SizedBox(height: 10),
            _PhotoSourceTile(
              icon: Icons.photo_library_outlined,
              title: s.tr('Photo Library', 'معرض الصور'),
              subtitle: s.tr('Select from your photo albums', 'اختر من ألبوم الصور في النظام'),
              highlight: false,
              isDark: isDark,
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 10),
            _PhotoSourceTile(
              icon: Icons.camera_alt_outlined,
              title: s.tr('Camera', 'الكاميرا'),
              subtitle: s.tr('Snap a live photo of your plate', 'التقط صورة حية لطبقك'),
              highlight: false,
              isDark: isDark,
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 10),
            _PhotoSourceTile(
              icon: Icons.scale_rounded,
              title: s.tr('Scale Camera Snapshot', 'التقاط بكاميرا الميزان'),
              subtitle: s.tr('Trigger Camera Module 3 snapshot on physical scale', 'التقاط صورة للطبق باستخدام كاميرا الميزان المدمجة'),
              highlight: false,
              isDark: isDark,
              onTap: () {
                Navigator.of(ctx).pop();
                _captureFromScaleCamera();
              },
            ),
            const SizedBox(height: 10),
            _PhotoSourceTile(
              icon: Icons.science_outlined,
              title: s.tr('Sample Demo Dishes', 'عينات أطباق تجريبية'),
              subtitle: s.tr('Test with pre-configured meal photos', 'اختر من عينات الأطباق الجاهزة للاختبار'),
              highlight: false,
              isDark: isDark,
              onTap: () {
                Navigator.of(ctx).pop();
                _showSampleDishesSheet(context, s, isDark);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSampleDishesSheet(BuildContext context, S s, bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141C18) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.tr('Sample Test Dishes', 'عينات أطباق تجريبية'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF111815),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.tr(
                          'Pre-configured photos for evaluating vision AI recognition.',
                          'صور مجهزة لاختبار وتقييم التعرف البصري بالذكاء الاصطناعي.',
                        ),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? MiqdarColors.darkMuted : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                itemCount: _samplePhotos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final sample = _samplePhotos[idx];
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _selectSamplePhoto(sample);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1B2420) : const Color(0xFFF7F9F8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? MiqdarColors.darkBorder : const Color(0xFFE5EAE7),
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              sample.asset,
                              width: 58,
                              height: 58,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.tr(sample.labelEn, sample.labelAr),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF111815),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${s.tr("Portion", "الحصة")}: ${sample.defaultWeightG.toInt()} g',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? MiqdarColors.darkMuted : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: isDark ? MiqdarColors.darkMuted : const Color(0xFF9CA3AF),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setWeight(double newWeight, {required PortionSource source}) {
    final clamped = newWeight.clamp(1.0, 5000.0).toDouble();
    setState(() {
      weight = clamped;
      portionSource = source;
      weightTextCtrl.text = clamped.toStringAsFixed(clamped % 1 == 0 ? 0 : 1);
    });
  }

  Future<void> _runAiRecognition(MiqdarController controller) async {
    if (weight <= 0) {
      final s = S.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.tr(
              'The scale reads 0 g. Put the food on the plate or enter a weight.',
              'الميزان يقرأ 0 غ. ضع الطعام على الطبق أو أدخل الوزن.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (imageBytes == null && selectedSampleAsset == null) {
      final s = S.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.tr(
              'Please add or take a photo of your meal first.',
              'يرجى التقاط صورة أو اختيار ملف صورة للوجبة أولاً.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    setState(() => lastError = null);
    final typedHint = hintTextCtrl.text.trim();
    final effectiveHint = typedHint.isNotEmpty ? typedHint : hint;
    try {
      final result = await controller.recognize(
        image: image,
        customImageBytes: imageBytes,
        assetPath: imageBytes == null ? selectedSampleAsset : null,
        weightG: weight,
        hint: effectiveHint,
        portionSource: portionSource,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RecognitionResultScreen(
            result: result,
            previewBytes: imageBytes,
            previewAsset: imageBytes == null ? selectedSampleAsset : null,
          ),
        ),
      );
    } on RecognitionException catch (e) {
      if (!mounted) return;
      setState(() => lastError = e);
    } catch (e) {
      if (!mounted) return;
      setState(() => lastError = RecognitionException('ERROR', e.toString()));
    }
  }

  Future<void> _runOfflineDemo(MiqdarController controller) async {
    setState(() => lastError = null);
    final typedHint = hintTextCtrl.text.trim();
    final effectiveHint = typedHint.isNotEmpty
        ? typedHint
        : (hint ?? (selectedSampleLabelEn ?? 'chicken kabsa').toLowerCase());
    final demo = await controller.useOfflineDemo(
      weightG: weight,
      hint: effectiveHint,
      portionSource: portionSource,
    );
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecognitionResultScreen(
          result: demo,
          previewBytes: imageBytes,
          previewAsset: imageBytes == null ? (selectedSampleAsset ?? 'assets/demo/kabsa.jpg') : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Dynamically sync live weight from physical scale when in scale mode
    if (portionSource == PortionSource.scale &&
        controller.scaleDevice.online &&
        !controller.taringScale) {
      final currentGrams = controller.scaleDevice.effectiveWeightG.clamp(0.0, 5000.0).toDouble();
      if ((weight - currentGrams).abs() >= 0.5) {
        weight = currentGrams;
        weightTextCtrl.text = currentGrams.toStringAsFixed(0);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      children: [
        // Clean Page Header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.tr('Log a Meal', 'تسجيل وجبة'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF111815),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.tr(
                      'Snap or upload a photo, weigh on scale, or search foods.',
                      'ارفع صورة للذكاء الاصطناعي، زِن بالميزان، أو ابحث في الدليل.',
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? MiqdarColors.darkMuted : const Color(0xFF5A655E),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Custom iOS-style Sliding Mode Pill Bar
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151F1B) : const Color(0xFFEAECE9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _ModeSegmentTab(
                label: s.tr('Smart Scan', 'مسح ذكي'),
                icon: Icons.camera_enhance_rounded,
                selected: modeIndex == 0,
                onTap: () => setState(() => modeIndex = 0),
              ),
              _ModeSegmentTab(
                label: s.tr('Food Catalog', 'دليل الأطعمة'),
                icon: Icons.search_rounded,
                selected: modeIndex == 1,
                onTap: () => setState(() => modeIndex = 1),
              ),
              _ModeSegmentTab(
                label: s.tr('Custom Food', 'طعام مخصص'),
                icon: Icons.edit_note_rounded,
                selected: modeIndex == 2,
                onTap: () => setState(() => modeIndex = 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (modeIndex == 0)
          _buildCameraAndScaleMode(context, controller, s, isDark)
        else if (modeIndex == 1)
          _buildCatalogSearchMode(context, controller, s)
        else
          _buildCustomFoodMode(context, controller, s),
      ],
    );
  }

  Widget _buildCameraAndScaleMode(
    BuildContext context,
    MiqdarController controller,
    S s,
    bool isDark,
  ) {
    final scale = controller.scaleDevice;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final cameraSection = _buildCameraSection(context, controller, s, isDark);
        final scaleSection = _buildSmartScaleCard(context, controller, s, scale, isDark);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: cameraSection),
                  const SizedBox(width: 18),
                  Expanded(flex: 5, child: scaleSection),
                ],
              )
            else ...[
              scaleSection,
              const SizedBox(height: 14),
              cameraSection,
            ],

            if (lastError != null) ...[
              const SizedBox(height: 14),
              _RecognitionErrorCard(
                error: lastError!,
                onUseOfflineDemo: () => _runOfflineDemo(controller),
                onOpenSearch: () => setState(() {
                  if (lastError!.candidates.isNotEmpty) {
                    searchCtrl.text = lastError!.candidates.first;
                  }
                  modeIndex = 1;
                }),
                onOpenCustom: () => setState(() => modeIndex = 2),
              ),
            ],

            const SizedBox(height: 16),
            // Primary Analyze Action Button
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: controller.busy ? null : () => _runAiRecognition(controller),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (controller.busy)
                    const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(Icons.auto_awesome_rounded, size: 20),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      controller.busy
                          ? s.recognizingFood
                          : s.tr('Analyze Meal with AI', 'تحليل الوجبة بالذكاء الاصطناعي'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: controller.busy ? null : () => _runOfflineDemo(controller),
                icon: const Icon(Icons.bolt_rounded, size: 17),
                label: Text(
                  s.tr('Instant offline preview', 'معاينة فورية بدون اتصال'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCameraSection(
    BuildContext context,
    MiqdarController controller,
    S s,
    bool isDark,
  ) {
    if (imageBytes == null && selectedSampleAsset == null) {
      return _buildEmptyPhotoZone(context, s, isDark);
    }
    return _buildSelectedPhotoView(context, s, isDark);
  }

  Widget _buildEmptyPhotoZone(BuildContext context, S s, bool isDark) {
    final controller = MiqdarScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121B17) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF22302A) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                  : const Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.add_a_photo_outlined,
              size: 27,
              color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            s.tr('Add Your Meal Photo', 'أضف صورة وجبتك'),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.tr(
              'Snap with physical scale camera or pick a meal image file',
              'التقط بكاميرا الميزان أو اختر ملف صورة للطبق',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? MiqdarColors.darkMuted : const Color(0xFF6B7280),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          // Primary action: Capture with Scale Camera
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: controller.busy ? null : _captureFromScaleCamera,
            icon: controller.busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.camera_alt_rounded, size: 20),
            label: Text(
              controller.busy
                  ? s.tr('Capturing & Analyzing via Gemini...', 'جاري الالتقاط والتحليل عبر جيميني...')
                  : s.tr('Capture from Scale Camera', 'التقاط بكاميرا الميزان وحلل'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
            ),
          ),
          const SizedBox(height: 8),
          // Secondary dual actions: Photos / Files
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFCBD5E1),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _pickFromFileSystem,
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: Text(
                    s.tr('Choose File', 'ملف صورة'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFCBD5E1),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: Text(
                    s.tr('Photos', 'الصور'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Discreet testing link for demo dishes
          TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            onPressed: () => _showSampleDishesSheet(context, s, isDark),
            icon: const Icon(Icons.science_outlined, size: 15),
            label: Text(
              s.tr('Testing? Try a sample dish photo', 'للاختبار السريع: اختر طبقاً تجريبياً'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? MiqdarColors.darkMuted : const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPhotoView(BuildContext context, S s, bool isDark) {
    return Container(
      height: 236,
      decoration: BoxDecoration(
        color: const Color(0xFF111815),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: imageBytes != null
                  ? MemoryImage(imageBytes!)
                  : AssetImage(selectedSampleAsset!) as ImageProvider,
              fit: BoxFit.cover,
            ),
            // Natural vignette gradient for legibility
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
            // Top bar: status badge + clear button
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: Color(0xFF34D399),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              imageFileName ??
                                  (selectedSampleAsset != null
                                      ? s.tr(
                                          selectedSampleLabelEn ?? '',
                                          selectedSampleLabelAr ?? '',
                                        )
                                      : s.tr('Meal Photo Loaded', 'تم تحميل الصورة')),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.65),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(32, 32),
                      padding: const EdgeInsets.all(6),
                    ),
                    tooltip: s.tr('Remove photo', 'إزالة الصورة'),
                    onPressed: () => setState(() {
                      image = null;
                      imageBytes = null;
                      imageFileName = null;
                      selectedSampleAsset = null;
                      selectedSampleLabelEn = null;
                      selectedSampleLabelAr = null;
                    }),
                    icon: const Icon(Icons.close_rounded, size: 16),
                  ),
                ],
              ),
            ),
            // Bottom bar: Change photo button
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.65),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 38),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showImageSourceSheet(context, s, isDark),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 17),
                      label: Text(
                        s.tr('Change Photo', 'تغيير الصورة'),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartScaleCard(
    BuildContext context,
    MiqdarController controller,
    S s,
    ScaleDeviceState scale,
    bool isDark,
  ) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF111815);
    final textSecondary = isDark ? const Color(0xFF9CA8A1) : const Color(0xFF5A655E);
    final isLiveMode = portionSource == PortionSource.scale;

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Live Scale Telemetry Header & Tare Button
          Row(
            children: [
              // Online / Live Pulse indicator
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: scale.online
                      ? (isLiveMode ? const Color(0xFF10B981) : const Color(0xFF3B82F6))
                      : const Color(0xFF9CA3AF),
                  shape: BoxShape.circle,
                  boxShadow: scale.online
                      ? [
                          BoxShadow(
                            color: (isLiveMode ? const Color(0xFF10B981) : const Color(0xFF3B82F6))
                                .withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        scale.displayName.isNotEmpty ? scale.displayName : scale.deviceId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => showApiUrlDialog(context, controller),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: scale.online
                              ? (isLiveMode
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : const Color(0xFF3B82F6).withValues(alpha: 0.15))
                              : Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              scale.online
                                  ? (scale.simulated
                                      ? s.tr('SIMULATED', 'محاكاة')
                                      : (isLiveMode ? s.tr('LIVE', 'مباشر') : s.tr('ONLINE', 'متصل')))
                                  : s.tr('OFFLINE', 'غير متصل'),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: scale.online
                                    ? (isLiveMode ? const Color(0xFF059669) : const Color(0xFF2563EB))
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.edit_outlined,
                              size: 10,
                              color: scale.online
                                  ? (isLiveMode ? const Color(0xFF059669) : const Color(0xFF2563EB))
                                  : const Color(0xFF6B7280),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Battery Indicator
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.battery_charging_full_rounded,
                    size: 15,
                    color: scale.batteryPercent > 20
                        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                        : const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${scale.batteryPercent}%',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              // Tare Button
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFF2F5F3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                onPressed: controller.taringScale
                    ? null
                    : () async {
                        final tared = await controller.tareScale();
                        if (tared) _setWeight(0, source: PortionSource.scale);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              tared
                                  ? s.tr('Scale tared to 0 g.', 'تم تصفير الميزان إلى 0 غرام.')
                                  : s.tr(
                                      'Could not zero: keep the plate still and try again.',
                                      'تعذر التصفير: أبقِ الطبق ثابتاً وحاول مرة أخرى.',
                                    ),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                icon: const Icon(Icons.exposure_zero_rounded, size: 14),
                label: Text(
                  s.tr('Tare', 'تصفير'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (scale.online && (scale.simulated || scale.sensorError != null)) ...[
            Text(
              scale.sensorError != null
                  ? s.tr(
                      'Load cell not responding: check the HX711 wiring.',
                      'حساس الوزن لا يستجيب: تحقق من توصيلات HX711.',
                    )
                  : s.tr(
                      'Simulation: weight and photo are not from a real scale.',
                      'محاكاة: الوزن والصورة ليسا من ميزان حقيقي.',
                    ),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD97706),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // 2. Offline banner OR Live Sync status banner / Revert to Live Scale button
          if (!scale.online)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => showApiUrlDialog(context, controller),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 16, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.scaleConnectionIssue ??
                            s.tr(
                              'Scale offline • Tap to enter Cloudflare URL',
                              'الميزان غير متصل • اضغط لضبط رابط النفق',
                            ),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Color(0xFFDC2626)),
                  ],
                ),
              ),
            )
          else if (!isLiveMode)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _setWeight(scale.effectiveWeightG, source: PortionSource.scale),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.tr(
                          'Manual portion: ${weight.toStringAsFixed(0)} g',
                          'وزن يدوي: ${weight.toStringAsFixed(0)} غرام',
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                    Text(
                      s.tr('↺ Sync Live (${scale.effectiveWeightG.toStringAsFixed(0)}g)', '↺ ربط بالميزان (${scale.effectiveWeightG.toStringAsFixed(0)}غ)'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.sensors_rounded,
                    size: 15,
                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      scale.isStable
                          ? s.tr('Live Weight Active • Place items on scale', 'قراءة الميزان المباشرة نشطة • ضع الصحن على الميزان')
                          : s.tr('Measuring live weight in motion…', 'جاري قياس الوزن المباشر…'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: scale.isStable
                          ? const Color(0xFF10B981).withValues(alpha: 0.2)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      scale.isStable ? s.tr('STABLE', 'مستقر') : s.tr('MOTION', 'حركة'),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                        color: scale.isStable
                            ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                            : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // 3. Tactile Digital Scale Display + Stepper Buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0E1512) : const Color(0xFFF6F8F6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? MiqdarColors.darkBorder : const Color(0xFFE4EAE6),
              ),
            ),
            child: Row(
              children: [
                _RoundStepButton(
                  icon: Icons.remove_rounded,
                  onTap: () => _setWeight(weight - 10, source: PortionSource.manual),
                ),
                Expanded(
                  child: TextField(
                    controller: weightTextCtrl,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                      letterSpacing: -0.8,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      suffixText: ' ${s.unitG}',
                      suffixStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                      ),
                    ),
                    onChanged: (raw) {
                      final parsed = double.tryParse(normalizeDigits(raw).trim());
                      if (parsed != null && parsed > 0) {
                        setState(() {
                          weight = parsed.clamp(1.0, 5000.0);
                          portionSource = PortionSource.manual;
                        });
                      }
                    },
                  ),
                ),
                _RoundStepButton(
                  icon: Icons.add_rounded,
                  onTap: () => _setWeight(weight + 10, source: PortionSource.manual),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 4. Clean Quick Portion Presets
          Row(
            children: [100.0, 150.0, 200.0, 300.0].map((preset) {
              final selected = (weight - preset).abs() < 2;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _setWeight(preset, source: PortionSource.manual),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? (isDark
                                ? const Color(0xFF10B981).withValues(alpha: 0.18)
                                : const Color(0xFF059669).withValues(alpha: 0.12))
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : const Color(0xFFF3F5F3)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? (isDark ? const Color(0xFF10B981) : const Color(0xFF059669))
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '${preset.toInt()}${s.unitG}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                              : textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // 5. Scale Camera Capture & Recognize Action Button
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: controller.scaleWorking ? null : _captureFromScaleCamera,
            icon: controller.scaleWorking
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.camera_alt_rounded, size: 20),
            label: Text(
              controller.scaleWorking
                  ? s.tr('Capturing & Analyzing via Gemini...', 'جاري الالتقاط والتحليل عبر جيميني...')
                  : s.tr('Capture from Scale Camera', 'التقاط وزِن بكاميرا الميزان'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
          const SizedBox(height: 12),

          // 6. Optional AI Context Input
          TextField(
            controller: hintTextCtrl,
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              hintText: s.tr(
                'Optional note for AI (e.g. grilled, homemade, no sauce)…',
                'ملاحظة اختيارية للذكاء الاصطناعي (مثال: مشوي، منزلي، بدون صوص)…',
              ),
              prefixIcon: const Icon(Icons.edit_outlined, size: 17),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogSearchMode(
    BuildContext context,
    MiqdarController controller,
    S s,
  ) {
    final categories = [
      'All',
      'Traditional Dish',
      'Fruit',
      'Protein',
      'Grain',
      'Legume',
      'Vegetable',
      'Dairy',
      'Sandwich',
      'Fast Food',
      'Salad',
      if (controller.localDatabase.customFoods.isNotEmpty) 'Custom',
    ];
    final results = controller.searchCatalog(
      searchCtrl.text,
      category: selectedCategory,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: searchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: s.tr(
              'Search in English or Arabic (e.g., Kabsa, كبسة, تمر, Jareesh)',
              'ابحث بالعربية أو الإنجليزية (مثال: كبسة، تمر، جريش، سليق)',
            ),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: searchCtrl.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      searchCtrl.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final selected = selectedCategory == cat;
              final label = cat == 'All'
                  ? s.tr('All (${MiqdarFoodCatalog.builtInFoods.length})', 'الكل')
                  : cat;
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => setState(() => selectedCategory = cat),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        if (results.isEmpty)
          SurfaceCard(
            child: Column(
              children: [
                const Icon(Icons.search_off_rounded, size: 36, color: MiqdarColors.muted),
                const SizedBox(height: 8),
                Text(
                  s.tr(
                    'No matching food found in catalog.',
                    'لم يتم العثور على طعام مطابق في الدليل.',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: () => setState(() {
                    customNameEnCtrl.text = searchCtrl.text;
                    modeIndex = 2;
                  }),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(s.tr('Create Custom Food', 'إضافة كطعام مخصص')),
                ),
              ],
            ),
          )
        else
          ...results.map(
            (food) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SurfaceCard(
                padding: const EdgeInsets.all(14),
                onTap: () => _showFoodPortionSheet(context, controller, food),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: food.verificationStatus == 'verified_official_record'
                            ? MiqdarColors.softGreen
                            : MiqdarColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        food.verificationStatus == 'verified_official_record'
                            ? Icons.verified_rounded
                            : Icons.restaurant_rounded,
                        color: MiqdarColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            food.displayName(s.isAr),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          Text(
                            '${food.secondaryName(s.isAr)} • ${food.preparation}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${food.per100g.calories.toStringAsFixed(0)} ${s.unitKcal}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: MiqdarColors.primary,
                          ),
                        ),
                        Text(
                          s.tr('per 100 g', 'لكل 100 غ'),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showFoodPortionSheet(
    BuildContext context,
    MiqdarController controller,
    FoodCatalogItem food,
  ) {
    final s = S.of(context);
    var grams = food.servings.isNotEmpty ? food.servings.first.grams : 150.0;
    var source = PortionSource.manual;
    final gramsCtrl = TextEditingController(text: grams.toStringAsFixed(0));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final preview = food.per100g.forPortionGrams(grams);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              22,
              22,
              MediaQuery.viewInsetsOf(ctx).bottom + 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              food.displayName(s.isAr),
                              style: Theme.of(ctx).textTheme.titleLarge,
                            ),
                            Text(
                              '${food.categoryLabel(s.isAr)} • ${food.preparation}',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(
                          food.verificationStatus == 'verified_official_record'
                              ? 'USDA FDC'
                              : s.tr('Reference', 'مرجعي'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (food.servings.isNotEmpty) ...[
                    Text(
                      s.tr('Standard Servings', 'الحصص المعيارية'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: food.servings.map((srv) {
                        final selected = (grams - srv.grams).abs() < 0.5;
                        return ChoiceChip(
                          label: Text(srv.label(s.isAr)),
                          selected: selected,
                          onSelected: (_) => setSheetState(() {
                            grams = srv.grams;
                            source = PortionSource.serving;
                            gramsCtrl.text = grams.toStringAsFixed(0);
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: gramsCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: s.tr('Portion Weight (g)', 'وزن الحصة (غ)'),
                            suffixText: s.unitG,
                          ),
                          onChanged: (val) {
                            final parsed = double.tryParse(normalizeDigits(val).trim());
                            if (parsed != null && parsed > 0) {
                              setSheetState(() {
                                grams = parsed.clamp(1.0, 5000.0);
                                source = PortionSource.manual;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          final scaleW = controller.scaleDevice.effectiveWeightG;
                          if (scaleW > 0) {
                            setSheetState(() {
                              grams = scaleW;
                              source = PortionSource.scale;
                              gramsCtrl.text = grams.toStringAsFixed(0);
                            });
                          }
                        },
                        icon: const Icon(Icons.scale_rounded, size: 18),
                        label: Text(
                          '${s.tr("Use Scale", "من الميزان")} (${controller.scaleDevice.effectiveWeightG.toStringAsFixed(0)}${s.unitG})',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: MiqdarColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _PreviewStat(
                          label: s.calories,
                          value: '${preview.calories.toStringAsFixed(0)} ${s.unitKcal}',
                        ),
                        _PreviewStat(
                          label: s.protein,
                          value: '${preview.protein.toStringAsFixed(1)} ${s.unitG}',
                        ),
                        _PreviewStat(
                          label: s.carbs,
                          value: '${preview.carbohydrates.toStringAsFixed(1)} ${s.unitG}',
                        ),
                        _PreviewStat(
                          label: s.fat,
                          value: '${preview.fat.toStringAsFixed(1)} ${s.unitG}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetCtx).pop();
                      final draft = await controller.prepareCatalogDraft(
                        food: food,
                        weightG: grams,
                        portionSource: source,
                      );
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RecognitionResultScreen(result: draft),
                        ),
                      );
                    },
                    icon: const Icon(Icons.fact_check_rounded),
                    label: Text(s.tr('Review & Log Portion', 'مراجعة الحصة قبل الحفظ')),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomFoodMode(
    BuildContext context,
    MiqdarController controller,
    S s,
  ) {
    double? optDouble(TextEditingController c) {
      final text = normalizeDigits(c.text).trim();
      if (text.isEmpty) return null;
      return double.tryParse(text);
    }

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.tr(
              'Custom Food & Nutrition Label',
              'إدخال طعام مخصص أو بطاقة غذائية',
            ),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            s.tr(
              'Leave any unknown nutrient field blank — Miqdar marks unreported nutrients as Unknown rather than assuming zero.',
              'اترك أي عنصر غذائي غير معروف فارغاً — يميز مقدار العناصر غير المتوفرة بدلاً من افتراض أنها صفر.',
            ),
            style: const TextStyle(fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: customNameEnCtrl,
                  decoration: InputDecoration(
                    labelText: s.tr('Food Name (English) *', 'اسم الطعام (إنجليزي) *'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: customNameArCtrl,
                  decoration: InputDecoration(
                    labelText: s.tr('Food Name (Arabic)', 'اسم الطعام (عربي)'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: customBasisCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: s.tr('Label Basis (g)', 'الوزن المرجعي (غ)'),
                    suffixText: s.unitG,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: customPortionCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: s.tr('Portion (g) *', 'وزن الحصة (غ) *'),
                    suffixText: s.unitG,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: customKcalCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${s.calories} (${s.unitKcal}) *',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: customProteinCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${s.protein} (${s.unitG})',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: customCarbsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${s.carbs} (${s.unitG})',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: customFatCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${s.fat} (${s.unitG})',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: customSugarCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${s.sugar} (${s.unitG})',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: customSodiumCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${s.sodium} (${s.unitMg})',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () async {
              final nameEn = customNameEnCtrl.text.trim().isEmpty
                  ? customNameArCtrl.text.trim()
                  : customNameEnCtrl.text.trim();
              final kcal = optDouble(customKcalCtrl);
              final basisG = optDouble(customBasisCtrl) ?? 100.0;
              final consumedG = optDouble(customPortionCtrl) ?? 100.0;

              if (nameEn.isEmpty || kcal == null || kcal < 0 || consumedG <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      s.tr(
                        'Please enter at least a food name, calories, and valid portion weight.',
                        'يرجى إدخال اسم الطعام والسعرات الحرارية ووزن الحصة على الأقل.',
                      ),
                    ),
                  ),
                );
                return;
              }

              final food = controller.createCustomFood(
                nameEn: nameEn,
                nameAr: customNameArCtrl.text.trim(),
                basisGrams: basisG,
                calories: kcal,
                protein: optDouble(customProteinCtrl),
                carbs: optDouble(customCarbsCtrl),
                fat: optDouble(customFatCtrl),
                sugar: optDouble(customSugarCtrl),
                fiber: optDouble(customFiberCtrl),
                sodium: optDouble(customSodiumCtrl),
                potassium: optDouble(customPotassiumCtrl),
              );
              final draft = await controller.prepareCatalogDraft(
                food: food,
                weightG: consumedG,
                portionSource: PortionSource.manual,
              );
              if (!context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RecognitionResultScreen(result: draft),
                ),
              );
            },
            icon: const Icon(Icons.add_task_rounded),
            label: Text(s.tr('Create & Review Custom Meal', 'إنشاء ومراجعة الوجبة المخصصة')),
          ),
        ],
      ),
    );
  }
}

class _ModeSegmentTab extends StatelessWidget {
  const _ModeSegmentTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? const Color(0xFF22332C) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected
                    ? (isDark ? const Color(0xFF34D399) : const Color(0xFF112A20))
                    : (isDark ? MiqdarColors.darkMuted : const Color(0xFF647069)),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? (isDark ? Colors.white : const Color(0xFF111815))
                        : (isDark ? MiqdarColors.darkMuted : const Color(0xFF647069)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundStepButton extends StatelessWidget {
  const _RoundStepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? MiqdarColors.darkBorder : const Color(0xFFE0E6E2),
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isDark ? Colors.white : const Color(0xFF111815),
          ),
        ),
      ),
    );
  }
}

class _PhotoSourceTile extends StatelessWidget {
  const _PhotoSourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.highlight,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlight;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: highlight
              ? (isDark
                  ? const Color(0xFF10B981).withValues(alpha: 0.14)
                  : const Color(0xFFECFDF5))
              : (isDark ? const Color(0xFF1A231F) : const Color(0xFFF9FAFB)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlight
                ? (isDark ? const Color(0xFF10B981) : const Color(0xFF059669))
                : (isDark ? MiqdarColors.darkBorder : const Color(0xFFE5E7EB)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: highlight
                    ? (isDark ? const Color(0xFF10B981) : const Color(0xFF059669))
                    : (isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: highlight
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF374151)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? MiqdarColors.darkMuted : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? MiqdarColors.darkMuted : const Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperIconButton extends StatelessWidget {
  const _StepperIconButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isDark ? MiqdarColors.darkSurface : MiqdarColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? MiqdarColors.darkBorder : MiqdarColors.border,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
        ),
      ),
    );
  }
}

class _PreviewStat extends StatelessWidget {
  const _PreviewStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 2),
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

class _RecognitionErrorCard extends StatelessWidget {
  const _RecognitionErrorCard({
    required this.error,
    required this.onUseOfflineDemo,
    required this.onOpenSearch,
    required this.onOpenCustom,
  });

  final RecognitionException error;
  final VoidCallback onUseOfflineDemo;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenCustom;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MiqdarColors.dangerBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MiqdarColors.danger.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: MiqdarColors.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  error.localizedTitle(s.isAr),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: MiqdarColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            error.recoveryAdvice(s.isAr),
            style: const TextStyle(color: MiqdarColors.dark, fontSize: 13),
          ),
          if (error.candidates.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${s.tr("Detected", "تم رصد")}: ${error.candidates.join(", ")}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: onOpenSearch,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: Text(s.searchFoodBtn),
              ),
              OutlinedButton.icon(
                onPressed: onOpenCustom,
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: Text(s.customFoodBtn),
              ),
              if (error.serverUnreachable)
                FilledButton.icon(
                  onPressed: onUseOfflineDemo,
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  label: Text(s.tr('Use Offline Demo', 'استخدام المعاينة المحلية')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Review & Recognition Result Screen — Natural Cal AI / Lifesum-style Meal Breakdown.
class RecognitionResultScreen extends StatefulWidget {
  const RecognitionResultScreen({
    super.key,
    required this.result,
    this.previewBytes,
    this.previewAsset,
  });

  final RecognitionResult result;
  final Uint8List? previewBytes;
  final String? previewAsset;

  @override
  State<RecognitionResultScreen> createState() => _RecognitionResultScreenState();
}

class _RecognitionResultScreenState extends State<RecognitionResultScreen> {
  late RecognitionResult currentResult = widget.result;
  String selectedMealType = 'Lunch';
  DateTime consumedAt = DateTime.now();
  final notesCtrl = TextEditingController();
  late final TextEditingController weightEditCtrl = TextEditingController(
    text: widget.result.weightG.toStringAsFixed(0),
  );

  @override
  void initState() {
    super.initState();
    final hour = DateTime.now().hour;
    if (hour < 11) {
      selectedMealType = 'Breakfast';
    } else if (hour < 16) {
      selectedMealType = 'Lunch';
    } else if (hour < 22) {
      selectedMealType = 'Dinner';
    } else {
      selectedMealType = 'Snack';
    }
  }

  @override
  void dispose() {
    notesCtrl.dispose();
    weightEditCtrl.dispose();
    super.dispose();
  }

  Future<void> _rescalePrimaryWeight(
    MiqdarController controller,
    double newGrams, {
    PortionSource? source,
  }) async {
    final clamped = newGrams.clamp(1.0, 5000.0).toDouble();
    final updated = await controller.updateDraftWeight(
      clamped,
      newSource: source ?? PortionSource.manual,
    );
    if (updated != null && mounted) {
      setState(() {
        currentResult = updated;
        weightEditCtrl.text = clamped.toStringAsFixed(clamped % 1 == 0 ? 0 : 1);
      });
    }
  }

  String _guessAssetForFood(String nameEn) {
    final lower = nameEn.toLowerCase();
    if (lower.contains('shawarma')) return 'assets/demo/shawarma.jpeg';
    if (lower.contains('jareesh')) return 'assets/demo/jareesh.jpeg';
    if (lower.contains('pizza')) return 'assets/demo/pizza.jpeg';
    if (lower.contains('burger')) return 'assets/demo/burger.jpg';
    return 'assets/demo/kabsa.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = controller.lastRecognition ?? currentResult;
    final totalNutrients = result.totalNutrients;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111815);
    final textSecondary = isDark ? const Color(0xFF9CA8A1) : const Color(0xFF5A655E);

    final ImageProvider previewImage = widget.previewBytes != null
        ? MemoryImage(widget.previewBytes!)
        : (result.imageBytes != null
            ? MemoryImage(result.imageBytes!)
            : (widget.previewAsset != null
                ? AssetImage(widget.previewAsset!)
                : AssetImage(_guessAssetForFood(result.nameEn)) as ImageProvider));

    return Scaffold(
      appBar: AppBar(
        title: Text(s.reviewBeforeSaving),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                // Natural Cal AI-Style Meal Identity & Photo Summary Card (Zero Overflow!)
                SurfaceCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top confirmation pill (Wrapped in Flexible so it can NEVER overflow)
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: MiqdarColors.primary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 14,
                                    color: MiqdarColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      s.tr(
                                        'AI match ready — confirm or adjust below',
                                        'تم التعرف على الوجبة — أكد أو عدّل بالأسفل',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: MiqdarColors.primary,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Large Captured Photo Display with Tap-to-Expand
                      GestureDetector(
                        onTap: () {
                          showDialog<void>(
                            context: context,
                            builder: (ctx) => Dialog(
                              backgroundColor: Colors.transparent,
                              insetPadding: const EdgeInsets.all(16),
                              child: Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: InteractiveViewer(
                                      child: Image(image: previewImage, fit: BoxFit.contain),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const CircleAvatar(
                                      backgroundColor: Colors.black54,
                                      child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
                                    ),
                                    onPressed: () => Navigator.of(ctx).pop(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          height: 190,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: isDark ? const Color(0xFF131D18) : const Color(0xFFE2E8F0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image(
                                  image: previewImage,
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.camera_alt_rounded, size: 13, color: Colors.white),
                                        const SizedBox(width: 5),
                                        Text(
                                          s.tr('Captured Scale Photo', 'صورة كاميرا الميزان'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.fullscreen_rounded, size: 14, color: Colors.white70),
                                        const SizedBox(width: 4),
                                        Text(
                                          s.tr('Tap to expand', 'اضغط للتكبير'),
                                          style: const TextStyle(color: Colors.white70, fontSize: 10.5),
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
                      const SizedBox(height: 14),

                      // Meal Photo Thumbnail + Title + Calorie Readout
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image(
                              image: previewImage,
                              width: 84,
                              height: 84,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.isAr && result.nameAr.isNotEmpty
                                      ? result.nameAr
                                      : result.nameEn,
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                    height: 1.2,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  s.isAr ? result.nameEn : result.nameAr,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF10B981).withValues(alpha: 0.18)
                                            : const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${totalNutrients.calories.toStringAsFixed(0)} ${s.unitKcal}',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: isDark
                                              ? const Color(0xFF34D399)
                                              : const Color(0xFF047857),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${result.totalWeightG.toStringAsFixed(0)} ${s.unitG} • ${result.portionSource.label(s.isAr)}',
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Quick Actions: Change Food / Add Side Item
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 38),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => _showReplaceFoodDialog(context, controller),
                            icon: const Icon(Icons.swap_horiz_rounded, size: 17),
                            label: Text(
                              s.tr('Change Food', 'تغيير الصنف'),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 38),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => _showAddPlateItemDialog(context, controller),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(
                              s.tr('Add Side / Sauce', 'إضافة صنف جانبي / صوص'),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Interactive Portion Weight Adjustment Card with Live Slider
                SurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              s.tr('Portion Weight', 'وزن الحصة'),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                            ),
                          ),
                          Text(
                            s.tr('Live nutrient scaling', 'تحديث فوري للقيم الغذائية'),
                            style: TextStyle(fontSize: 11.5, color: textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _StepperIconButton(
                            label: '-10g',
                            onTap: () => _rescalePrimaryWeight(
                              controller,
                              result.weightG - 10,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: weightEditCtrl,
                              textAlign: TextAlign.center,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                              decoration: InputDecoration(
                                suffixText: s.unitG,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              onSubmitted: (val) {
                                final parsed = double.tryParse(normalizeDigits(val).trim());
                                if (parsed != null && parsed > 0) {
                                  _rescalePrimaryWeight(controller, parsed);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StepperIconButton(
                            label: '+10g',
                            onTap: () => _rescalePrimaryWeight(
                              controller,
                              result.weightG + 10,
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4.5,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                        ),
                        child: Slider(
                          value: result.weightG.clamp(10.0, 800.0).toDouble(),
                          min: 10,
                          max: 800,
                          onChanged: (v) => _rescalePrimaryWeight(
                            controller,
                            (v / 5).round() * 5.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Additional Plate Items if added
                if (result.additionalItems.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.tr(
                            'Added Plate Components',
                            'المكونات الإضافية في الطبق',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        ...result.additionalItems.map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              s.isAr && item.nameAr.isNotEmpty ? item.nameAr : item.nameEn,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              '${item.weightG.toStringAsFixed(0)} ${s.unitG} • ${item.nutrients.calories.toStringAsFixed(0)} ${s.unitKcal}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: MiqdarColors.danger),
                              onPressed: () async {
                                final updated = await controller.removeDraftPlateItem(item.id);
                                if (updated != null && mounted) {
                                  setState(() => currentResult = updated);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Alternative Top-3 AI Candidates
                if (result.candidates
                    .where((c) => c.foodId != result.foodId && c.inDatabase)
                    .isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.alt_route_rounded, size: 19, color: MiqdarColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s.tr(
                                  'Other Closest Matches',
                                  'بدائل أخرى مقترحة',
                                ),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...result.candidates
                            .where((c) => c.foodId != result.foodId && c.inDatabase)
                            .map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final updated = await controller.chooseCandidate(c);
                                    if (!mounted) return;
                                    setState(() => currentResult = updated);
                                  },
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${s.isAr && (c.nameAr?.isNotEmpty ?? false) ? c.nameAr : (c.nameEn ?? c.label)}',
                                          style: const TextStyle(fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      Text(
                                        s.tr('Select', 'اختيار'),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: MiqdarColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                // 2x4 Nutrient Grid
                NutrientGrid2x4(
                  values: totalNutrients,
                  goals: controller.goals,
                ),
                const SizedBox(height: 14),

                // Provenance & Verification Banner
                AiVerificationBadge(
                  verificationStatus: result.verificationStatus,
                  provider: result.provider,
                  model: result.model,
                  isMock: result.isMock,
                  portionSource: result.portionSource,
                ),

                if (controller.projectedAlerts.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ...controller.projectedAlerts.map(
                    (alert) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: NutrientNoticeCard(alert: alert, isPreview: true),
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                // Meal Type, Consumed Time & Notes
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.tr('Meal Time & Notes', 'وقت الوجبة والملاحظات'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['Breakfast', 'Lunch', 'Dinner', 'Snack'].map((type) {
                          final selected = selectedMealType == type;
                          return ChoiceChip(
                            label: Text(s.mealTypeLabel(type)),
                            selected: selected,
                            onSelected: (_) => setState(() => selectedMealType = type),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded, size: 18, color: MiqdarColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormat('EEE, d MMM yyyy • h:mm a').format(consumedAt),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: consumedAt,
                                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                lastDate: DateTime.now(),
                              );
                              if (pickedDate != null && mounted) {
                                setState(() {
                                  consumedAt = DateTime(
                                    pickedDate.year,
                                    pickedDate.month,
                                    pickedDate.day,
                                    consumedAt.hour,
                                    consumedAt.minute,
                                  );
                                });
                              }
                            },
                            child: Text(s.tr('Change Date', 'تغيير التاريخ')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesCtrl,
                        maxLength: 200,
                        decoration: InputDecoration(
                          labelText: s.tr('Optional Meal Note', 'ملاحظة اختيارية على الوجبة'),
                          prefixIcon: const Icon(Icons.notes_rounded),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF10B981) : const Color(0xFF112A20),
                    foregroundColor: isDark ? const Color(0xFF062117) : Colors.white,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () async {
                    await controller.saveLastRecognition(
                      mealType: selectedMealType,
                      eatenAt: consumedAt,
                      notes: notesCtrl.text.trim(),
                    );
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const MainShell()),
                      (_) => false,
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    s.saveMealToDiary,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(s.tr('Keep Draft & Back', 'الاحتفاظ بالمسودة والرجوع')),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: MiqdarColors.danger),
                      onPressed: () {
                        controller.discardDraft();
                        Navigator.of(context).pop();
                      },
                      child: Text(s.tr('Discard Draft', 'إلغاء المسودة')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showReplaceFoodDialog(BuildContext context, MiqdarController controller) {
    final s = S.of(context);
    var query = '';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final matches = controller.searchCatalog(query);
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            builder: (_, scrollController) => Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.tr('Select Correct Food Record', 'اختر السجل الغذائي الصحيح'),
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setSheetState(() => query = v),
                    decoration: InputDecoration(
                      labelText: s.tr('Search food catalog…', 'ابحث في الدليل الغذائي…'),
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: matches.length,
                      itemBuilder: (_, idx) {
                        final item = matches[idx];
                        return ListTile(
                          title: Text(
                            item.displayName(s.isAr),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${item.secondaryName(s.isAr)} • ${item.per100g.calories.toStringAsFixed(0)} kcal/100g',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            Navigator.of(sheetCtx).pop();
                            final current = controller.lastRecognition ?? currentResult;
                            final updated = await controller.prepareCatalogDraft(
                              food: item,
                              weightG: current.weightG,
                              portionSource: current.portionSource,
                            );
                            if (mounted) {
                              setState(() => currentResult = updated);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddPlateItemDialog(BuildContext context, MiqdarController controller) {
    final s = S.of(context);
    var query = '';
    var itemGrams = 50.0;
    final gramsCtrl = TextEditingController(text: '50');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final matches = controller.searchCatalog(query);
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.78,
            builder: (_, scrollController) => Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.tr('Add Side / Oil / Sauce', 'إضافة مكون للطبق أو صنف جانبي'),
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          onChanged: (v) => setSheetState(() => query = v),
                          decoration: InputDecoration(
                            labelText: s.tr('Search item…', 'ابحث عن المكون…'),
                            prefixIcon: const Icon(Icons.search_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: gramsCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: s.tr('Weight (g)', 'الوزن (غ)'),
                            suffixText: s.unitG,
                          ),
                          onChanged: (v) {
                            final parsed = double.tryParse(normalizeDigits(v).trim());
                            if (parsed != null && parsed > 0) {
                              itemGrams = parsed;
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: matches.length,
                      itemBuilder: (_, idx) {
                        final food = matches[idx];
                        return ListTile(
                          title: Text(
                            food.displayName(s.isAr),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${(food.per100g.calories * itemGrams / 100).toStringAsFixed(0)} ${s.unitKcal} for ${itemGrams.toStringAsFixed(0)} ${s.unitG}',
                          ),
                          trailing: FilledButton.tonal(
                            onPressed: () async {
                              Navigator.of(sheetCtx).pop();
                              final updated = await controller.addDraftPlateItem(
                                food: food,
                                weightG: itemGrams,
                                portionSource: PortionSource.manual,
                              );
                              if (updated != null && mounted) {
                                setState(() => currentResult = updated);
                              }
                            },
                            child: Text(s.tr('Add', 'إضافة')),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
