import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle, rootBundle;
import 'package:image_picker/image_picker.dart';

import '../app.dart';
import '../app_controller.dart';
import '../data/food_catalog.dart';
import '../l10n/strings.dart';
import '../models/nutrition.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'screens.dart';
import 'widgets/brand.dart';
import 'widgets/charts_and_gauges.dart';
import 'widgets/miq_icons.dart';

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
  bool showPhotoOptions = false;

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
              'Scale is not connected. Start it, then enter the address shown on its screen.',
              'الميزان غير متصل. شغّله ثم أدخل العنوان الظاهر على شاشته.',
            ),
          ),
          backgroundColor: MiqdarColors.warning,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: s.tr('Connect', 'اتصال'),
            textColor: Colors.white,
            onPressed: () => showScaleAddressDialog(context, controller),
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
            label: s.tr('Scale address', 'عنوان الميزان'),
            textColor: Colors.white,
            onPressed: () => showScaleAddressDialog(context, controller),
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
          color: isDark ? MiqdarColors.darkCard : Colors.white,
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
                fontWeight: FontWeight.w600,
                color: isDark ? MiqdarColors.darkText : MiqdarColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              s.tr(
                'From your files, photos or camera',
                'من ملفاتك أو صورك أو الكاميرا',
              ),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? MiqdarColors.darkMuted : MiqdarColors.muted,
              ),
            ),
            const SizedBox(height: 18),
            _PhotoSourceTile(
              icon: MiqIcons.folderOpen,
              title: s.tr('Files', 'الملفات'),
              subtitle: s.tr('Choose an image file', 'اختر ملف صورة'),
              highlight: true,
              isDark: isDark,
              onTap: () {
                Navigator.of(ctx).pop();
                _pickFromFileSystem();
              },
            ),
            const SizedBox(height: 10),
            _PhotoSourceTile(
              icon: MiqIcons.images,
              title: s.tr('Photo Library', 'معرض الصور'),
              subtitle: s.tr('Choose from your albums', 'اختر من ألبوماتك'),
              highlight: false,
              isDark: isDark,
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 10),
            _PhotoSourceTile(
              icon: MiqIcons.camera,
              title: s.tr('Camera', 'الكاميرا'),
              subtitle: s.tr('Take a photo of your plate', 'التقط صورة لطبقك'),
              highlight: false,
              isDark: isDark,
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 10),
            _PhotoSourceTile(
              icon: MiqIcons.scales,
              title: s.tr('Scale Camera', 'كاميرا الميزان'),
              subtitle: s.tr('Photograph what is on the scale', 'صوّر ما على الميزان'),
              highlight: false,
              isDark: isDark,
              onTap: () {
                Navigator.of(ctx).pop();
                _captureFromScaleCamera();
              },
            ),
            const SizedBox(height: 10),
            _PhotoSourceTile(
              icon: MiqIcons.flask,
              title: s.tr('Sample Photos', 'صور نموذجية'),
              subtitle: s.tr('Try it with a ready-made photo', 'جرّب بصورة جاهزة'),
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
          color: isDark ? MiqdarColors.darkCard : Colors.white,
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
                        s.tr('Sample Photos', 'عينات أطباق تجريبية'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark ? MiqdarColors.darkText : MiqdarColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.tr(
                          'Try the app without a real meal.',
                          'صور مجهزة لاختبار وتقييم التعرف البصري بالذكاء الاصطناعي.',
                        ),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? MiqdarColors.darkMuted : MiqdarColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(MiqIcons.x),
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
                        color: isDark ? MiqdarColors.darkCard : MiqdarColors.cream,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? MiqdarColors.darkBorder : MiqdarColors.border,
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
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? MiqdarColors.darkText : MiqdarColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${s.tr("Portion", "الحصة")}: ${sample.defaultWeightG.toInt()} g',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? MiqdarColors.darkMuted : MiqdarColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: isDark ? MiqdarColors.darkMuted : MiqdarColors.slate400,
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

    // The note is used up by the capture it was typed for.
    if (controller.aiNote.isEmpty && hintTextCtrl.text.isNotEmpty) {
      hintTextCtrl.clear();
    }

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
        Text(s.navAdd, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        Row(
          children: [
            _ModeSegmentTab(
              label: s.tr('Scale', 'الميزان'),
              icon: MiqIcons.camera,
              selected: modeIndex == 0,
              onTap: () => setState(() => modeIndex = 0),
            ),
            _ModeSegmentTab(
              label: s.tr('Search', 'بحث'),
              icon: MiqIcons.magnifyingGlass,
              selected: modeIndex == 1,
              onTap: () => setState(() => modeIndex = 1),
            ),
            _ModeSegmentTab(
              label: s.tr('Manual', 'يدوي'),
              icon: MiqIcons.notePencil,
              selected: modeIndex == 2,
              onTap: () => setState(() => modeIndex = 2),
            ),
          ],
        ),
        const SizedBox(height: 18),

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
    final hasPhoto = imageBytes != null || selectedSampleAsset != null;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSmartScaleCard(context, controller, s, controller.scaleDevice, isDark),
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
            const SizedBox(height: 14),
            if (hasPhoto) ...[
              _buildSelectedPhotoView(context, s, isDark),
              const SizedBox(height: 12),
              _buildPortionInput(context, controller, s, isDark),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? MiqdarColors.saffron : MiqdarColors.saffron,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: controller.busy ? null : () => _runAiRecognition(controller),
                icon: controller.busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.3, color: Colors.white),
                      )
                    : const Icon(MiqIcons.sparkle, size: 20),
                label: Text(
                  controller.busy
                      ? s.recognizingFood
                      : s.tr('Analyze This Photo', 'حلّل هذه الصورة'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ] else if (showPhotoOptions)
              _buildEmptyPhotoZone(context, s, isDark)
            else
              TextButton.icon(
                onPressed: () => setState(() => showPhotoOptions = true),
                icon: const Icon(MiqIcons.images, size: 18),
                label: Text(
                  s.tr('Use a photo instead', 'استخدم صورة بدلاً من ذلك'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Weight for a photo that did not come from the scale.
  Widget _buildPortionInput(BuildContext context, MiqdarController controller, S s, bool isDark) {
    final scale = controller.scaleDevice;
    final textPrimary = isDark ? Colors.white : MiqdarColors.ink;
    final textSecondary = isDark ? MiqdarColors.darkMuted : MiqdarColors.muted;
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.tr('Weight of this food', 'وزن هذا الطعام'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              if (scale.online && portionSource != PortionSource.scale)
                TextButton(
                  onPressed: () => _setWeight(scale.effectiveWeightG, source: PortionSource.scale),
                  child: Text(
                    s.tr(
                      'Use scale (${scale.effectiveWeightG.toStringAsFixed(0)} g)',
                      'من الميزان (${scale.effectiveWeightG.toStringAsFixed(0)} غ)',
                    ),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _RoundStepButton(
                icon: MiqIcons.minus,
                onTap: () => _setWeight(weight - 10, source: PortionSource.manual),
              ),
              Expanded(
                child: TextField(
                  controller: weightTextCtrl,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: textPrimary),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    suffixText: ' ${s.unitG}',
                    suffixStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textSecondary),
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
                icon: MiqIcons.plus,
                onTap: () => _setWeight(weight + 10, source: PortionSource.manual),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [100.0, 150.0, 200.0, 300.0].map((preset) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _setWeight(preset, source: PortionSource.manual),
                    child: Text(
                      '${preset.toInt()}${s.unitG}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPhotoZone(BuildContext context, S s, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? MiqdarColors.darkCard : MiqdarColors.cream,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? MiqdarColors.darkBorder : MiqdarColors.border,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            s.tr('Choose a photo of your food', 'اختر صورة لطعامك'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? MiqdarColors.darkText : MiqdarColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          // Secondary dual actions: Photos / Files
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    side: BorderSide(
                      color: isDark ? MiqdarColors.darkBorder : MiqdarColors.border,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _pickFromFileSystem,
                  icon: const Icon(MiqIcons.folderOpen, size: 16),
                  label: Text(
                    s.tr('Choose File', 'ملف صورة'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    side: BorderSide(
                      color: isDark ? MiqdarColors.darkBorder : MiqdarColors.border,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(MiqIcons.images, size: 16),
                  label: Text(
                    s.tr('Photos', 'الصور'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
            icon: const Icon(MiqIcons.flask, size: 15),
            label: Text(
              s.tr('Try a sample photo', 'للاختبار السريع: اختر طبقاً تجريبياً'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? MiqdarColors.darkMuted : MiqdarColors.muted,
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
        color: MiqdarColors.ink,
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
                            MiqIcons.checkCircle,
                            size: 14,
                            color: MiqdarColors.accentGlow,
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
                                fontWeight: FontWeight.w600,
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
                    icon: const Icon(MiqIcons.x, size: 16),
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
                    child: OutlinedButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.65),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 38),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showImageSourceSheet(context, s, isDark),
                      icon: const Icon(MiqIcons.arrowsLeftRight, size: 17),
                      label: Text(
                        s.tr('Change Photo', 'تغيير الصورة'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
    final grams = scale.effectiveWeightG < 0 ? 0.0 : scale.effectiveWeightG;
    final working = controller.scaleWorking;
    final canCapture = scale.online && !working && (grams >= 5 || scale.simulated);

    final String guidance;
    if (!scale.online) {
      final issue = controller.scaleConnectionIssue;
      guidance = issue != null && !s.isAr
          ? issue
          : s.tr('Turn on the scale, then connect to it.', 'شغّل الميزان ثم اتصل به.');
    } else if (scale.sensorError != null) {
      guidance = s.tr('Load cell not responding: check the wiring.', 'حساس الوزن لا يستجيب: تحقق من التوصيلات.');
    } else if (working) {
      guidance = controller.analyzingScalePhoto
          ? s.tr('Gemini is analyzing your food…', 'Gemini يحلل طعامك…')
          : s.tr('Taking the photo. Keep your hands off the plate.', 'جارٍ التقاط الصورة. أبعد يدك عن الطبق.');
    } else if (grams < 5) {
      guidance = s.tr('Put your food on the plate', 'ضع طعامك على الطبق');
    } else if (!scale.isStable) {
      guidance = s.tr('Settling… keep your hands off the plate', 'جارٍ الثبات… أبعد يدك عن الطبق');
    } else {
      guidance = s.tr('Ready to capture', 'جاهز للالتقاط');
    }

    final miq = Miq.of(context);
    final statusColor = !scale.online
        ? miq.muted
        : (scale.simulated ? MiqdarColors.warning : MiqdarColors.fiberAccent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: () => showScaleAddressDialog(context, controller),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: statusColor),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      !scale.online
                          ? s.tr('Scale not connected', 'الميزان غير متصل')
                          : (scale.simulated
                              ? s.tr('Simulated scale, not real food', 'ميزان محاكاة، ليس طعاماً حقيقياً')
                              : s.tr('Scale connected', 'الميزان متصل')),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: miq.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.maxWidth.clamp(200.0, 300.0);
              return MeasureDial(
                size: size,
                // One turn of the dial is a kilogram, like a kitchen scale.
                progress: scale.online ? (grams % 1000) / 1000 + (grams >= 1000 && grams % 1000 == 0 ? 1 : 0) : 0,
                strokeWidth: 11,
                dashedTrack: !scale.online,
                color: scale.isStable ? MiqdarColors.saffron : MiqdarColors.accentGlow.withValues(alpha: 0.55),
                child: !scale.online
                    ? Icon(MiqIcons.linkBreak, size: 46, color: miq.muted)
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 34),
                          child: Row(
                            textDirection: TextDirection.ltr,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                grams.toStringAsFixed(0),
                                style: MiqType.display(92, color: miq.text, height: 1).copyWith(
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(s.unitG, style: MiqType.display(32, color: miq.muted)),
                            ],
                          ),
                        ),
                      ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Text(
          guidance,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: miq.text),
        ),
        const SizedBox(height: 16),
        if (scale.online)
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58)),
            onPressed: canCapture ? _captureFromScaleCamera : null,
            icon: working
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.3, color: MiqdarColors.ink),
                  )
                : const Icon(MiqIcons.camera, size: 22),
            label: Text(s.tr('Capture', 'التقاط'), style: const TextStyle(fontSize: 17)),
          )
        else
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58)),
            onPressed: () => showScaleAddressDialog(context, controller),
            icon: const Icon(MiqIcons.link),
            label: Text(s.tr('Connect to Scale', 'الاتصال بالميزان')),
          ),
        if (scale.online) ...[
          const SizedBox(height: 12),
          TextField(
            controller: hintTextCtrl,
            onChanged: (value) => controller.aiNote = value,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              hintText: s.tr(
                'Note for Gemini (optional): grilled, no sauce…',
                'ملاحظة لـ Gemini (اختياري): مشوي، بدون صوص…',
              ),
              prefixIcon: const Icon(MiqIcons.pencilSimple, size: 17),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton.icon(
              onPressed: controller.taringScale || working
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final tared = await controller.tareScale();
                      if (tared) _setWeight(0, source: PortionSource.scale);
                      messenger.showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                          content: Text(
                            tared
                                ? s.tr('Scale set to 0 g', 'تم تصفير الميزان إلى 0 غ')
                                : s.tr(
                                    'Could not zero: keep the plate still and try again.',
                                    'تعذر التصفير: أبقِ الطبق ثابتاً وحاول مرة أخرى.',
                                  ),
                          ),
                        ),
                      );
                    },
              icon: const Icon(MiqIcons.numberCircleZero, size: 17),
              label: Text(s.tr('Zero', 'تصفير')),
            ),
          ),
        ],
      ],
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
            prefixIcon: const Icon(MiqIcons.magnifyingGlass),
            suffixIcon: searchCtrl.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      searchCtrl.clear();
                      setState(() {});
                    },
                    icon: const Icon(MiqIcons.x),
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
                  : s.foodCategoryLabel(cat);
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
                const Icon(MiqIcons.magnifyingGlassMinus, size: 36, color: MiqdarColors.muted),
                const SizedBox(height: 8),
                Text(
                  s.tr(
                    'No matching food found in catalog.',
                    'لم يتم العثور على طعام مطابق في الدليل.',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    customNameEnCtrl.text = searchCtrl.text;
                    modeIndex = 2;
                  }),
                  icon: const Icon(MiqIcons.plus),
                  label: Text(s.tr('Enter It by Hand', 'أدخله يدوياً')),
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
                            ? MiqdarColors.accentWash
                            : MiqdarColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        food.verificationStatus == 'verified_official_record'
                            ? MiqIcons.sealCheck
                            : MiqIcons.forkKnife,
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
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
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
                            fontWeight: FontWeight.w600,
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
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
                        icon: const Icon(MiqIcons.scales, size: 18),
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
                    icon: const Icon(MiqIcons.clipboardText),
                    label: Text(s.tr('Review', 'مراجعة')),
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
              'Enter a food by hand',
              'أدخل طعاماً يدوياً',
            ),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            s.tr(
              'Copy the values from the label. Leave blank what you do not know; it shows as Unknown, not zero.',
              'انسخ القيم من البطاقة الغذائية. اترك ما لا تعرفه فارغاً وسيظهر كغير متوفر وليس صفراً.',
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
                    labelText: s.tr('Food name *', 'اسم الطعام بالإنجليزية *'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: customNameArCtrl,
                  decoration: InputDecoration(
                    labelText: s.tr('Arabic name (optional)', 'اسم الطعام بالعربية (اختياري)'),
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
            icon: const Icon(MiqIcons.listPlus),
            label: Text(s.tr('Review', 'مراجعة')),
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
    final miq = Miq.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: selected ? 2 : 1,
                color: selected ? MiqdarColors.saffron : miq.hairline,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? miq.text : miq.muted,
            ),
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
              color: isDark ? MiqdarColors.darkBorder : MiqdarColors.border,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isDark ? MiqdarColors.darkText : MiqdarColors.ink,
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
                  ? MiqdarColors.saffron.withValues(alpha: 0.14)
                  : MiqdarColors.accentWash)
              : (isDark ? MiqdarColors.darkCard : MiqdarColors.cream),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlight
                ? (isDark ? MiqdarColors.saffron : MiqdarColors.saffron)
                : (isDark ? MiqdarColors.darkBorder : MiqdarColors.border),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: highlight
                    ? (isDark ? MiqdarColors.saffron : MiqdarColors.saffron)
                    : (isDark ? Colors.white10 : MiqdarColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: highlight
                    ? Colors.white
                    : (isDark ? Colors.white70 : MiqdarColors.muted),
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
                      fontWeight: FontWeight.w600,
                      color: isDark ? MiqdarColors.darkText : MiqdarColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? MiqdarColors.darkMuted : MiqdarColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? MiqdarColors.darkMuted : MiqdarColors.slate400,
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
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isDark ? MiqdarColors.darkBorder : MiqdarColors.border,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
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
              fontWeight: FontWeight.w600,
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
              const Icon(MiqIcons.warning, color: MiqdarColors.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  error.localizedTitle(s.isAr),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
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
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onOpenSearch,
                icon: const Icon(MiqIcons.magnifyingGlass, size: 18),
                label: Text(s.searchFoodBtn),
              ),
              OutlinedButton.icon(
                onPressed: onOpenCustom,
                icon: const Icon(MiqIcons.notePencil, size: 18),
                label: Text(s.customFoodBtn),
              ),
              if (error.serverUnreachable && MiqdarScope.of(context).account.isDemo)
                FilledButton.icon(
                  onPressed: onUseOfflineDemo,
                  icon: const Icon(MiqIcons.lightning, size: 18),
                  label: Text(s.tr('Use Sample Result', 'استخدام نتيجة نموذجية')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

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
  bool correcting = false;
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

  Future<void> _askGeminiToCorrect(BuildContext context, MiqdarController controller) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final input = TextEditingController();
    final correction = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.tr('What is it really?', 'ما هو الطعام فعلاً؟')),
        content: TextField(
          controller: input,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(ctx).pop(value),
          decoration: InputDecoration(
            hintText: s.tr(
              'e.g. lamb kabsa, only the seeds, no oil',
              'مثال: كبسة لحم، الحبوب فقط، بدون زيت',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.tr('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(input.text),
            child: Text(s.tr('Ask Gemini', 'اسأل Gemini')),
          ),
        ],
      ),
    );
    if (correction == null || correction.trim().isEmpty || !mounted) return;
    setState(() => correcting = true);
    try {
      final updated = await controller.correctDraftWithGemini(correction);
      if (updated != null && mounted) setState(() => currentResult = updated);
    } on RecognitionException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.localizedTitle(s.isAr)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => correcting = false);
    }
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
    final textPrimary = isDark ? Colors.white : MiqdarColors.ink;
    final textSecondary = isDark ? MiqdarColors.darkMuted : MiqdarColors.muted;
    final confidencePct = (result.confidence * 100).round();

    final ImageProvider previewImage = widget.previewBytes != null
        ? MemoryImage(widget.previewBytes!)
        : (result.imageBytes != null
            ? MemoryImage(result.imageBytes!)
            : (widget.previewAsset != null
                ? AssetImage(widget.previewAsset!)
                : AssetImage(_guessAssetForFood(result.nameEn)) as ImageProvider));

    final alternatives = result.candidates.where((c) => c.foodId != result.foodId && c.inDatabase).toList();
    final kcalColor = Miq.of(context).accent;

    void openPhoto() {
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
                child: InteractiveViewer(child: Image(image: previewImage, fit: BoxFit.contain)),
              ),
              IconButton(
                tooltip: s.tr('Close', 'إغلاق'),
                icon: const CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: Icon(MiqIcons.x, color: Colors.white, size: 20),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      );
    }

    Widget smallAction({
      required IconData icon,
      required String label,
      required VoidCallback? onPressed,
      Widget? leading,
    }) =>
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          ),
          onPressed: onPressed,
          icon: leading ?? Icon(icon, size: 17),
          label: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        );

    return Scaffold(
      // Always in reach, however long the page gets.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              final meal = await controller.saveLastRecognition(
                mealType: selectedMealType,
                eatenAt: consumedAt,
                notes: notesCtrl.text.trim(),
                photo: widget.previewBytes,
              );
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainShell()),
                (_) => false,
              );
              if (meal == null) return;
              messenger.showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  persist: false,
                  duration: const Duration(seconds: 5),
                  content: Text(
                    s.tr(
                      'Saved: ${meal.nameEn}, ${meal.nutrients.calories.toStringAsFixed(0)} kcal',
                      'تم الحفظ: ${meal.nameAr.isEmpty ? meal.nameEn : meal.nameAr}، ${meal.nutrients.calories.toStringAsFixed(0)} سعرة',
                    ),
                  ),
                  action: SnackBarAction(
                    label: s.tr('Undo', 'تراجع'),
                    onPressed: () => controller.deleteMeal(meal.id),
                  ),
                ),
              );
            },
            icon: const Icon(MiqIcons.check),
            label: Text(
              s.saveMealToDiary,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: MediaQuery.sizeOf(context).width.clamp(0.0, 720.0) / 1.08,
                backgroundColor: MiqdarColors.ink,
                foregroundColor: MiqdarColors.paper,
                systemOverlayStyle: SystemUiOverlayStyle.light,
                actions: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 10),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: MiqdarColors.ink.withValues(alpha: 0.7),
                        foregroundColor: MiqdarColors.paper,
                      ),
                      onPressed: () {
                        controller.discardDraft();
                        Navigator.of(context).pop();
                      },
                      child: Text(s.tr('Discard', 'إلغاء')),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: GestureDetector(
                    onTap: openPhoto,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image(image: previewImage, fit: BoxFit.cover),
                        // Keeps the clock and back arrow readable on any photo
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.center,
                              colors: [MiqdarColors.ink.withValues(alpha: 0.7), Colors.transparent],
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          bottom: 14,
                          start: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: result.isUnsure ? MiqdarColors.saffron : MiqdarColors.ink.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              result.isUnsure
                                  ? s.tr(
                                      'Gemini is unsure ($confidencePct%), please check',
                                      'Gemini غير متأكد ($confidencePct%)، يرجى التحقق',
                                    )
                                  : s.tr('$confidencePct% sure', 'متأكد $confidencePct%'),
                              style: TextStyle(
                                color: result.isUnsure ? MiqdarColors.ink : MiqdarColors.paper,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child:
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                Text(
                  s.isAr && result.nameAr.isNotEmpty ? result.nameAr : result.nameEn,
                  style: MiqType.display(36, color: textPrimary, height: 1.15),
                ),
                if ((s.isAr ? result.nameEn : result.nameAr).isNotEmpty)
                  Text(
                    s.isAr ? result.nameEn : result.nameAr,
                    style: TextStyle(fontSize: 14, color: textSecondary),
                  ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      totalNutrients.calories.toStringAsFixed(0),
                      style: MiqType.display(76, color: kcalColor, height: 1),
                    ),
                    const SizedBox(width: 6),
                    Text(s.unitKcal, style: MiqType.display(26, color: kcalColor)),
                    const Spacer(),
                    Text(
                      '${result.totalWeightG.toStringAsFixed(0)} ${s.unitG}',
                      style: MiqType.display(26, color: textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: MacroColumn(
                        label: s.protein,
                        value: '${totalNutrients.protein.toStringAsFixed(totalNutrients.protein < 10 ? 1 : 0)} ${s.unitG}',
                        color: MiqdarColors.proteinAccent,
                        progress: controller.goals.protein > 0 ? totalNutrients.protein / controller.goals.protein : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: MacroColumn(
                        label: s.carbs,
                        value: '${totalNutrients.carbohydrates.toStringAsFixed(totalNutrients.carbohydrates < 10 ? 1 : 0)} ${s.unitG}',
                        color: MiqdarColors.carbsAccent,
                        progress: controller.goals.carbohydrates > 0 ? totalNutrients.carbohydrates / controller.goals.carbohydrates : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: MacroColumn(
                        label: s.fat,
                        value: '${totalNutrients.fat.toStringAsFixed(totalNutrients.fat < 10 ? 1 : 0)} ${s.unitG}',
                        color: MiqdarColors.fatAccent,
                        progress: controller.goals.fat > 0 ? totalNutrients.fat / controller.goals.fat : null,
                      ),
                    ),
                  ],
                ),
                if (result.aiNote.isNotEmpty || result.edibleFraction < 1) ...[
                  const SizedBox(height: 10),
                  Text(
                    [
                      if (result.edibleFraction < 1)
                        s.tr(
                          '${(result.edibleFraction * 100).round()}% of the weight counted as edible',
                          'احتُسب ${(result.edibleFraction * 100).round()}% من الوزن كجزء صالح للأكل',
                        ),
                      if (result.aiNote.isNotEmpty) result.aiNote,
                    ].join(' • '),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ],

                if (controller.projectedAlerts.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ...controller.projectedAlerts.map(
                    (alert) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: NutrientNoticeCard(alert: alert, isPreview: true),
                    ),
                  ),
                ],

                // Is it wrong?
                if (alternatives.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    s.tr('Could also be', 'قد يكون أيضاً'),
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: alternatives
                        .map(
                          (c) => ActionChip(
                            label: Text(
                              '${s.isAr && (c.nameAr?.isNotEmpty ?? false) ? c.nameAr : (c.nameEn ?? c.label)}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            onPressed: () async {
                              final updated = await controller.chooseCandidate(c);
                              if (!mounted) return;
                              setState(() => currentResult = updated);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (result.verificationStatus == aiEstimateStatus && result.imageBytes != null)
                      smallAction(
                        icon: MiqIcons.sparkle,
                        label: s.tr('Not right? Tell Gemini', 'غير صحيح؟ أخبر Gemini'),
                        onPressed: correcting ? null : () => _askGeminiToCorrect(context, controller),
                        leading: correcting
                            ? const SizedBox.square(
                                dimension: 15,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : null,
                      ),
                    smallAction(
                      icon: MiqIcons.arrowsLeftRight,
                      label: s.tr('Change Food', 'تغيير الصنف'),
                      onPressed: () => _showReplaceFoodDialog(context, controller),
                    ),
                    smallAction(
                      icon: MiqIcons.plus,
                      label: s.tr('Add Side', 'إضافة صنف'),
                      onPressed: () => _showAddPlateItemDialog(context, controller),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Portion
                SurfaceCard(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.tr('Portion', 'الحصة'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _StepperIconButton(
                            label: '-10g',
                            onTap: () => _rescalePrimaryWeight(controller, result.weightG - 10),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: weightEditCtrl,
                              textAlign: TextAlign.center,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                suffixText: s.unitG,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            onTap: () => _rescalePrimaryWeight(controller, result.weightG + 10),
                          ),
                        ],
                      ),
                      Slider(
                        value: result.weightG.clamp(10.0, 800.0).toDouble(),
                        min: 10,
                        max: 800,
                        onChanged: (v) => _rescalePrimaryWeight(controller, (v / 5).round() * 5.0),
                      ),
                    ],
                  ),
                ),

                if (result.additionalItems.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.tr('Also on the plate', 'أيضاً في الطبق'),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        ...result.additionalItems.map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              s.isAr && item.nameAr.isNotEmpty ? item.nameAr : item.nameEn,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${item.weightG.toStringAsFixed(0)} ${s.unitG} • ${item.nutrients.calories.toStringAsFixed(0)} ${s.unitKcal}',
                            ),
                            trailing: IconButton(
                              tooltip: s.tr('Remove', 'إزالة'),
                              icon: const Icon(MiqIcons.minusCircle, color: MiqdarColors.danger),
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
                const SizedBox(height: 14),

                // Everything else, out of the way until wanted
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ExpansionTile(
                        shape: const Border(),
                        collapsedShape: const Border(),
                        title: Text(
                          s.tr('All nutrients', 'كل العناصر الغذائية'),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        children: [
                          NutrientGrid2x4(values: totalNutrients, goals: controller.goals),
                          const SizedBox(height: 12),
                          AiVerificationBadge(
                            verificationStatus: result.verificationStatus,
                            provider: result.provider,
                            model: result.model,
                            isMock: result.isMock,
                            portionSource: result.portionSource,
                          ),
                        ],
                      ),
                      const Divider(height: 1),
                      ExpansionTile(
                        shape: const Border(),
                        collapsedShape: const Border(),
                        title: Text(
                          s.tr('Meal time & notes', 'وقت الوجبة والملاحظات'),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          '${s.mealTypeLabel(selectedMealType)} • ${s.date(consumedAt, 'EEE, h:mm a')}',
                          style: TextStyle(fontSize: 12.5, color: textSecondary),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ['Breakfast', 'Lunch', 'Dinner', 'Snack'].map((type) {
                              return ChoiceChip(
                                label: Text(s.mealTypeLabel(type)),
                                selected: selectedMealType == type,
                                onSelected: (_) => setState(() => selectedMealType = type),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(MiqIcons.clock, size: 18, color: MiqdarColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  s.date(consumedAt, 'EEE, d MMM yyyy • h:mm a'),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                          TextField(
                            controller: notesCtrl,
                            maxLength: 200,
                            decoration: InputDecoration(
                              labelText: s.tr('Note (optional)', 'ملاحظة (اختياري)'),
                              prefixIcon: const Icon(MiqIcons.note),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                      ],
                    ),
                  ),
              ),
            ],
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
                    s.tr('Choose the right food', 'اختر الطعام الصحيح'),
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setSheetState(() => query = v),
                    decoration: InputDecoration(
                      labelText: s.tr('Search food catalog…', 'ابحث في الدليل الغذائي…'),
                      prefixIcon: const Icon(MiqIcons.magnifyingGlass),
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
                            style: const TextStyle(fontWeight: FontWeight.w600),
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
                            prefixIcon: const Icon(MiqIcons.magnifyingGlass),
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
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${(food.per100g.calories * itemGrams / 100).toStringAsFixed(0)} ${s.unitKcal} for ${itemGrams.toStringAsFixed(0)} ${s.unitG}',
                          ),
                          trailing: OutlinedButton(
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
