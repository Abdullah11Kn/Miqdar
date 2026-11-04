import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';

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
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: s.tr('Connect', 'اتصال'),
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
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: s.tr('Scale address', 'عنوان الميزان'),
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

  void _showImageSourceSheet(BuildContext context, S s) {
    final c = context.mq;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.tr('Choose Meal Photo', 'اختر صورة الوجبة'),
              style: MiqdarType.titleSection.copyWith(color: c.ink),
            ),
            const SizedBox(height: 4),
            Text(
              s.tr(
                'From your files, photos or camera',
                'من ملفاتك أو صورك أو الكاميرا',
              ),
              style: MiqdarType.body.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: 16),
            _PhotoSourceTile(
              icon: MiqdarIcons.folderOpen,
              title: s.tr('Files', 'الملفات'),
              subtitle: s.tr('Choose an image file', 'اختر ملف صورة'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickFromFileSystem();
              },
            ),
            const SizedBox(height: 8),
            _PhotoSourceTile(
              icon: MiqdarIcons.photoLibrary,
              title: s.tr('Photo Library', 'معرض الصور'),
              subtitle: s.tr('Choose from your albums', 'اختر من ألبوماتك'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
            _PhotoSourceTile(
              icon: MiqdarIcons.photoCamera,
              title: s.tr('Camera', 'الكاميرا'),
              subtitle: s.tr('Take a photo of your plate', 'التقط صورة لطبقك'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
            _PhotoSourceTile(
              icon: MiqdarIcons.scale,
              title: s.tr('Scale Camera', 'كاميرا الميزان'),
              subtitle: s.tr('Photograph what is on the scale', 'صوّر ما على الميزان'),
              onTap: () {
                Navigator.of(ctx).pop();
                _captureFromScaleCamera();
              },
            ),
            const SizedBox(height: 8),
            _PhotoSourceTile(
              icon: MiqdarIcons.science,
              title: s.tr('Sample Photos', 'صور نموذجية'),
              subtitle: s.tr('Try it with a ready-made photo', 'جرّب بصورة جاهزة'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showSampleDishesSheet(context, s);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSampleDishesSheet(BuildContext context, S s) {
    final c = context.mq;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.tr('Sample Photos', 'عينات أطباق تجريبية'),
                        style: MiqdarType.titleSection.copyWith(color: c.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.tr(
                          'Try the app without a real meal.',
                          'صور مجهزة لاختبار وتقييم التعرف البصري بالذكاء الاصطناعي.',
                        ),
                        style: MiqdarType.body.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: s.tr('Close', 'إغلاق'),
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(MiqdarIcons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _samplePhotos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final sample = _samplePhotos[idx];
                  return SurfaceCard(
                    padding: const EdgeInsets.all(12),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _selectSamplePhoto(sample);
                    },
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(sample.asset, width: 52, height: 52, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.tr(sample.labelEn, sample.labelAr),
                                style: MiqdarType.titleCard.copyWith(fontSize: 16, color: c.ink),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${s.tr("Portion", "الحصة")}: ${sample.defaultWeightG.toInt()} ${s.unitG}',
                                style: MiqdarType.caption.copyWith(color: c.inkMuted),
                              ),
                            ],
                          ),
                        ),
                        Icon(MiqdarIcons.chevronRight, color: c.inkMuted),
                      ],
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
        Text(
          s.tr('Add Meal', 'إضافة وجبة'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        MiqdarSegmented<int>(
          options: [
            (value: 0, label: s.tr('Scale', 'الميزان'), icon: MiqdarIcons.photoCamera),
            (value: 1, label: s.tr('Search', 'بحث'), icon: MiqdarIcons.search),
            (value: 2, label: s.tr('Manual', 'يدوي'), icon: MiqdarIcons.editNote),
          ],
          value: modeIndex,
          onChanged: (mode) => setState(() => modeIndex = mode),
        ),
        const SizedBox(height: 16),

        if (modeIndex == 0)
          _buildCameraAndScaleMode(context, controller, s)
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
  ) {
    final hasPhoto = imageBytes != null || selectedSampleAsset != null;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSmartScaleCard(context, controller, s, controller.scaleDevice),
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
              _buildSelectedPhotoView(context, s),
              const SizedBox(height: 12),
              _buildPortionInput(context, controller, s),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58)),
                onPressed: controller.busy ? null : () => _runAiRecognition(controller),
                icon: controller.busy
                    ? SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.3, color: context.mq.onPrimary),
                      )
                    : const Icon(MiqdarIcons.autoAwesome, size: 20),
                label: Text(
                  controller.busy
                      ? s.recognizingFood
                      : s.tr('Analyze This Photo', 'حلّل هذه الصورة'),
                  style: MiqdarType.button.copyWith(fontSize: 17),
                ),
              ),
            ] else if (showPhotoOptions)
              _buildEmptyPhotoZone(context, s)
            else ...[
              Text(
                s.tr('Away from the scale?', 'بعيد عن الميزان؟'),
                textAlign: TextAlign.center,
                style: MiqdarType.label.copyWith(color: context.mq.inkMuted),
              ),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => openDescribeMeal(context, startWithCamera: true),
                    icon: const Icon(MiqdarIcons.photoCamera, size: 18),
                    label: Text(s.tr('Take a Photo', 'التقط صورة')),
                  ),
                  TextButton.icon(
                    onPressed: () => openDescribeMeal(context),
                    icon: const Icon(MiqdarIcons.editNote, size: 18),
                    label: Text(s.tr('No Time to Weigh?', 'لا وقت للوزن؟')),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => showPhotoOptions = true),
                    icon: const Icon(MiqdarIcons.photoLibrary, size: 18),
                    label: Text(s.tr('Use a Photo', 'استخدم صورة')),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Weight for a photo that did not come from the scale.
  Widget _buildPortionInput(BuildContext context, MiqdarController controller, S s) {
    final scale = controller.scaleDevice;
    final textPrimary = context.mq.ink;
    final textSecondary = context.mq.inkMuted;
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
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: context.mq.ink),
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
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              StepSquareButton(
                icon: MiqdarIcons.remove,
                onTap: () => _setWeight(weight - 10, source: PortionSource.manual),
              ),
              Expanded(
                child: TextField(
                  controller: weightTextCtrl,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    suffixText: ' ${s.unitG}',
                    suffixStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textSecondary),
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
              StepSquareButton(
                icon: MiqdarIcons.add,
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
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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

  Widget _buildEmptyPhotoZone(BuildContext context, S s) {
    final c = context.mq;
    return SurfaceCard(
      child: Column(
        children: [
          Text(
            s.tr('Choose a photo of your food', 'اختر صورة لطعامك'),
            style: MiqdarType.titleCard.copyWith(color: c.ink),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  onPressed: _pickFromFileSystem,
                  icon: const Icon(MiqdarIcons.folderOpen, size: 20),
                  label: Text(s.tr('Choose File', 'ملف صورة')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(MiqdarIcons.photoLibrary, size: 20),
                  label: Text(s.tr('Photos', 'الصور')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _showSampleDishesSheet(context, s),
            icon: const Icon(MiqdarIcons.science, size: 18),
            label: Text(s.tr('Try a sample photo', 'للاختبار السريع: اختر طبقاً تجريبياً')),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPhotoView(BuildContext context, S s) {
    return Container(
      height: 236,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(22),
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
                            MiqdarIcons.checkCircle,
                            size: 14,
                            color: Colors.white,
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
                    icon: const Icon(MiqdarIcons.close, size: 16),
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
                      onPressed: () => _showImageSourceSheet(context, s),
                      icon: const Icon(MiqdarIcons.swapHoriz, size: 17),
                      label: Text(
                        s.tr('Change Photo', 'تغيير الصورة'),
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
  ) {
    final c = context.mq;
    final grams = scale.effectiveWeightG < 0 ? 0.0 : scale.effectiveWeightG;
    final working = controller.scaleWorking;
    final canCapture = scale.online && !working && (grams >= 5 || scale.simulated);
    final isReady = scale.online && scale.sensorError == null && !working && grams >= 5 && scale.isStable;
    // One main action per screen: once a photo is chosen, that is Analyze This Photo.
    final hasPhoto = imageBytes != null || selectedSampleAsset != null;
    final plate = controller.scalePlate;
    final plateOpen = plate != null && plate.isOpen;
    final plateActive = !working && !controller.plateBusy && scale.online;

    final String guidance;
    if (plateOpen && !working && scale.online) {
      guidance = s.tr('Add the next food, or Finish.', 'أضف الطعام التالي، أو اضغط إنهاء.');
    } else if (!scale.online) {
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

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => showScaleAddressDialog(context, controller),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ScaleStatusLabel(state: scale.visualState),
                  ),
                ),
              ),
              if (scale.online && !plateOpen)
                TextButton(
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
                  child: Text(s.tr('Zero', 'تصفير')),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!scale.online)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Icon(MiqdarIcons.linkOff, size: 64, color: c.inkMuted),
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                textDirection: TextDirection.ltr,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(grams.toStringAsFixed(0), style: MiqdarType.weightLive.copyWith(color: c.ink)),
                  const SizedBox(width: 4),
                  Text(
                    s.unitG,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600).copyWith(color: c.inkMuted),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            guidance,
            textAlign: TextAlign.center,
            style: isReady
                ? MiqdarType.bodyStrong.copyWith(color: c.primary)
                : MiqdarType.body.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: 16),
          if (plateOpen && scale.online) ...[
            _plateSteps(controller, s, plate),
            const SizedBox(height: 12),
            _ScaleActionButton(
              primary: true,
              onPressed: plateActive ? () => _plateAction(controller, s, 'finish') : null,
              icon: controller.plateBusy || working
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.3))
                  : const Icon(MiqdarIcons.check, size: 22),
              label: s.tr('Finish', 'إنهاء'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: plateActive ? () => _plateAction(controller, s, 'add') : null,
              icon: const Icon(MiqdarIcons.add),
              label: Text(s.tr('Add Next Food', 'إضافة الطعام التالي')),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: plateActive ? () => _plateAction(controller, s, 'undo') : null,
                  child: Text(s.tr('Undo Last Food', 'تراجع عن آخر طعام')),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: c.danger),
                  onPressed: plateActive ? () => _plateAction(controller, s, 'cancel') : null,
                  child: Text(s.tr('Cancel Plate', 'إلغاء الطبق')),
                ),
              ],
            ),
          ] else if (scale.online) ...[
            _ScaleActionButton(
              primary: !hasPhoto,
              onPressed: canCapture ? _captureFromScaleCamera : null,
              icon: working
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.3),
                    )
                  : const Icon(MiqdarIcons.photoCamera, fill: 1, size: 22),
              label: s.tr('Capture', 'التقاط'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: canCapture && !controller.plateBusy ? () => _plateAction(controller, s, 'add') : null,
              icon: const Icon(MiqdarIcons.add),
              label: Text(s.tr('Add Next Food', 'إضافة الطعام التالي')),
            ),
          ] else
            _ScaleActionButton(
              primary: !hasPhoto,
              onPressed: () => showScaleAddressDialog(context, controller),
              icon: const Icon(MiqdarIcons.link),
              label: s.tr('Connect to Scale', 'الاتصال بالميزان'),
            ),
          if (scale.online) ...[
            const SizedBox(height: 12),
            TextField(
              controller: hintTextCtrl,
              onChanged: (value) => controller.aiNote = value,
              decoration: InputDecoration(
                isDense: true,
                hintText: s.tr(
                  'Note for AI (optional): grilled, no sauce…',
                  'ملاحظة للذكاء الاصطناعي (اختياري): مشوي، بدون صوص…',
                ),
                prefixIcon: const Icon(MiqdarIcons.edit, size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _plateAction(MiqdarController controller, S s, String action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.plateAction(action);
    } on RecognitionException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'PLATE_STEP_TOO_SMALL' => s.tr(
            'Too little was added to weigh. For small amounts, use Add Side on the review screen.',
            'الكمية المضافة قليلة جداً للوزن. للكميات الصغيرة استخدم إضافة صنف في شاشة المراجعة.',
          ),
        'PLATE_WEIGHT_DROPPED' => s.tr(
            'The plate got lighter. Undo the last food, or put the food back and try again.',
            'أصبح الطبق أخف. تراجع عن آخر طعام، أو أعد الطعام وحاول مجدداً.',
          ),
        'WEIGHT_NOT_STEADY' => s.tr(
            'The weight is still moving. Take your hand off the plate, then try again.',
            'الوزن ما زال يتحرك. أبعد يدك عن الطبق ثم حاول مجدداً.',
          ),
        'EMPTY_SCALE' => s.tr('Put the food on the plate first.', 'ضع الطعام على الطبق أولاً.'),
        'PLATE_OPEN' => s.tr('Finish or cancel the current plate first.', 'أنهِ الطبق الحالي أو ألغِه أولاً.'),
        'CAPTURE_IN_PROGRESS' => s.tr('The scale is busy. Try again in a moment.', 'الميزان مشغول. حاول بعد لحظة.'),
        _ => s.tr('The scale did not respond. Try again.', 'لم يستجب الميزان. حاول مجدداً.'),
      };
      messenger.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)));
    }
  }

  Widget _plateSteps(MiqdarController controller, S s, ScalePlate plate) {
    final c = context.mq;
    return Column(
      children: [
        for (final step in plate.steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox.square(
                    dimension: 44,
                    child: switch (controller.platePhoto(step)) {
                      final photo? => Image.memory(photo, fit: BoxFit.cover),
                      null => ColoredBox(color: c.surfaceSunken, child: Icon(MiqdarIcons.restaurant, color: c.inkMuted)),
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.tr('Food ${step.index + 1}', 'الطعام ${step.index + 1}'),
                    style: MiqdarType.body.copyWith(color: c.ink),
                  ),
                ),
                Text('${step.grams.toStringAsFixed(0)} ${s.unitG}', style: MiqdarType.bodyStrong.copyWith(color: c.ink)),
              ],
            ),
          ),
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
            prefixIcon: const Icon(MiqdarIcons.search),
            suffixIcon: searchCtrl.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      searchCtrl.clear();
                      setState(() {});
                    },
                    icon: const Icon(MiqdarIcons.close),
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
        if (searchCtrl.text.isEmpty && selectedCategory == 'All' && controller.recentFoods.isNotEmpty) ...[
          Text(s.tr('Recent', 'الأخيرة'), style: MiqdarType.bodyStrong.copyWith(color: context.mq.ink)),
          const SizedBox(height: 8),
          for (final meal in controller.recentFoods)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SurfaceCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                onTap: () async {
                  final navigator = Navigator.of(context);
                  final draft = await controller.prepareRelog(meal);
                  navigator.push(MaterialPageRoute(builder: (_) => RecognitionResultScreen(result: draft)));
                },
                child: Row(
                  children: [
                    Icon(MiqdarIcons.replay, size: 20, color: context.mq.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        meal.displayName(s.isAr),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MiqdarType.bodyStrong.copyWith(color: context.mq.ink),
                      ),
                    ),
                    Text(
                      '${meal.weightG.toStringAsFixed(0)} ${s.unitG} • ${meal.nutrients.calories.toStringAsFixed(0)} ${s.unitKcal}',
                      style: MiqdarType.caption.copyWith(color: context.mq.inkMuted),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 6),
        ],
        if (results.isEmpty)
          SurfaceCard(
            child: Column(
              children: [
                Icon(MiqdarIcons.searchOff, size: 36, color: context.mq.inkMuted),
                const SizedBox(height: 8),
                Text(
                  s.tr(
                    'No matching food found in catalog.',
                    'لم يتم العثور على طعام مطابق في الدليل.',
                  ),
                  style: TextStyle(fontWeight: FontWeight.w600, color: context.mq.ink),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: () => setState(() {
                    customNameEnCtrl.text = searchCtrl.text;
                    modeIndex = 2;
                  }),
                  icon: const Icon(MiqdarIcons.add),
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
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: context.mq.surfaceSunken,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        food.verificationStatus == 'verified_official_record'
                            ? MiqdarIcons.verified
                            : MiqdarIcons.restaurant,
                        size: 26,
                        color: food.verificationStatus == 'verified_official_record'
                            ? context.mq.primary
                            : context.mq.ink,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            food.displayName(s.isAr),
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: context.mq.ink),
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
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: context.mq.primary,
                          ),
                        ),
                        Text(
                          s.tr('per 100 g', 'لكل 100 غ'),
                          style: const TextStyle(fontSize: 12),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      MiqdarPill(
                        text: food.verificationStatus == 'verified_official_record'
                            ? 'USDA FDC'
                            : s.tr('Reference', 'مرجعي'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (food.servings.isNotEmpty) ...[
                    Text(
                      s.tr('Standard Servings', 'الحصص المعيارية'),
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.mq.ink),
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
                        icon: const Icon(MiqdarIcons.scale, size: 18),
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
                      color: context.mq.surfaceSunken,
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
                    icon: const Icon(MiqdarIcons.factCheck),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.tr(
              'Enter a food by hand',
              'أدخل طعاماً يدوياً',
            ),
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: context.mq.ink),
          ),
          const SizedBox(height: 6),
          Text(
            s.tr(
              'Copy the values from the label. Leave blank what you do not know; it shows as Unknown, not zero.',
              'انسخ القيم من البطاقة الغذائية. اترك ما لا تعرفه فارغاً وسيظهر كغير متوفر وليس صفراً.',
            ),
            style: const TextStyle(fontSize: 13),
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
            icon: const Icon(MiqdarIcons.addTask),
            label: Text(s.tr('Review', 'مراجعة')),
          ),
        ],
      ),
    );
  }
}


class _ScaleActionButton extends StatelessWidget {
  const _ScaleActionButton({
    required this.primary,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final bool primary;
  final VoidCallback? onPressed;
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(58),
      textStyle: MiqdarType.button.copyWith(fontSize: 17),
    );
    final text = Text(label);
    return primary
        ? FilledButton.icon(style: style, onPressed: onPressed, icon: icon, label: text)
        : FilledButton.tonalIcon(style: style, onPressed: onPressed, icon: icon, label: text);
  }
}

class _PhotoSourceTile extends StatelessWidget {
  const _PhotoSourceTile({
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
  Widget build(BuildContext context) {
    final c = context.mq;
    return SurfaceCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: c.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: MiqdarType.bodyStrong.copyWith(color: c.ink)),
                Text(subtitle, style: MiqdarType.caption.copyWith(color: c.inkMuted)),
              ],
            ),
          ),
          Icon(MiqdarIcons.chevronRight, color: c.inkMuted),
        ],
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
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: context.mq.primary,
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
        color: context.mq.dangerSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(MiqdarIcons.warning, color: context.mq.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  error.localizedTitle(s.isAr),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: context.mq.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            error.recoveryAdvice(s.isAr),
            style: TextStyle(color: context.mq.ink, fontSize: 13),
          ),
          if (error.candidates.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${s.tr("Detected", "تم رصد")}: ${error.candidates.join(", ")}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.mq.ink),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: onOpenSearch,
                icon: const Icon(MiqdarIcons.search, size: 18),
                label: Text(s.searchFoodBtn),
              ),
              OutlinedButton.icon(
                onPressed: onOpenCustom,
                icon: const Icon(MiqdarIcons.editNote, size: 18),
                label: Text(s.customFoodBtn),
              ),
              if (error.serverUnreachable && MiqdarScope.of(context).account.isDemo)
                FilledButton.icon(
                  onPressed: onUseOfflineDemo,
                  icon: const Icon(MiqdarIcons.bolt, size: 18),
                  label: Text(s.tr('Use Sample Result', 'استخدام نتيجة نموذجية')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Review & Recognition Result Screen — Natural Cal AI / Lifesum-style Meal Breakdown.
class _MacroTile extends StatelessWidget {
  const _MacroTile({required this.label, required this.grams, required this.color, this.missing = false});

  final String label;
  final double grams;
  final Color color;
  final bool missing;

  @override
  Widget build(BuildContext context) => Expanded(
        child: NutrientTile(
          label: label,
          color: color,
          value: missing ? null : grams.toStringAsFixed(grams < 10 ? 1 : 0),
          unit: S.of(context).unitG,
        ),
      );
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
    final result = controller.lastRecognition ?? currentResult;
    final totalNutrients = result.totalNutrients;
    final textPrimary = context.mq.ink;
    final textSecondary = context.mq.inkMuted;
    final confidencePct = (result.confidence * 100).round();

    final ImageProvider previewImage = widget.previewBytes != null
        ? MemoryImage(widget.previewBytes!)
        : (result.imageBytes != null
            ? MemoryImage(result.imageBytes!)
            : (widget.previewAsset != null
                ? AssetImage(widget.previewAsset!)
                : AssetImage(_guessAssetForFood(result.nameEn)) as ImageProvider));

    final alternatives = result.candidates.where((c) => c.foodId != result.foodId && c.inDatabase).toList();
    final kcalColor = context.mq.nCalories;

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
                  child: Icon(MiqdarIcons.close, color: Colors.white, size: 20),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onPressed,
          icon: leading ?? Icon(icon, size: 17),
          label: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(s.tr('Review Meal', 'مراجعة الوجبة')),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: context.mq.danger),
            onPressed: () {
              controller.discardDraft();
              Navigator.of(context).pop();
            },
            child: Text(s.tr('Discard', 'إلغاء')),
          ),
        ],
      ),
      // Always in reach, however long the page gets.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58)),
            onPressed: result.plateNeedsNames ? null : () async {
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
            icon: const Icon(MiqdarIcons.check),
            label: Text(
              s.saveMealToDiary,
              style: MiqdarType.button.copyWith(fontSize: 17),
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                // Photo
                GestureDetector(
                  onTap: openPhoto,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image(image: previewImage, fit: BoxFit.cover),
                          PositionedDirectional(
                            top: 10,
                            start: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: result.isUnsure
                                    ? context.mq.accent
                                    : Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    result.isUnsure
                                        ? MiqdarIcons.help
                                        : MiqdarIcons.autoAwesome,
                                    size: 13,
                                    color: result.isUnsure ? context.mq.onAccent : Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    result.isUnsure
                                        ? s.tr(
                                            'Gemini is unsure ($confidencePct%), please check',
                                            'Gemini غير متأكد ($confidencePct%)، يرجى التحقق',
                                          )
                                        : s.tr('$confidencePct% sure', 'متأكد $confidencePct%'),
                                    style: MiqdarType.label.copyWith(
                                      color: result.isUnsure ? context.mq.onAccent : Colors.white,
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
                ),
                const SizedBox(height: 16),

                // The answer
                Text(
                  result.isPlate
                      ? (_plateTitle(result, s))
                      : s.isAr && result.nameAr.isNotEmpty
                          ? result.nameAr
                          : result.nameEn,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: textPrimary,
                  ),
                ),
                if (!result.isPlate && (s.isAr ? result.nameEn : result.nameAr).isNotEmpty)
                  Text(
                    s.isAr ? result.nameEn : result.nameAr,
                    style: TextStyle(fontSize: 14, color: textSecondary, fontWeight: FontWeight.w600),
                  ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (totalNutrients.isMissing('calories_kcal'))
                      Text(
                        s.tr('Unknown', 'غير متوفر'),
                        style: MiqdarType.titleSection.copyWith(color: context.mq.accentInk),
                      )
                    else ...[
                      Text(
                        totalNutrients.calories.toStringAsFixed(0),
                        style: MiqdarType.numberXl.copyWith(color: kcalColor),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        s.unitKcal,
                        style: MiqdarType.titleCard.copyWith(color: kcalColor),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      '${result.totalWeightG.toStringAsFixed(0)} ${s.unitG}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MacroTile(label: s.tr('Protein', 'بروتين'), grams: totalNutrients.protein, color: context.mq.nProtein, missing: totalNutrients.isMissing('protein_g')),
                    const SizedBox(width: 8),
                    _MacroTile(label: s.tr('Carbs', 'كربوهيدرات'), grams: totalNutrients.carbohydrates, color: context.mq.nCarbs, missing: totalNutrients.isMissing('carbohydrate_g')),
                    const SizedBox(width: 8),
                    _MacroTile(label: s.tr('Fat', 'دهون'), grams: totalNutrients.fat, color: context.mq.nFat, missing: totalNutrients.isMissing('fat_g')),
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
                    style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
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

                if (result.isPlate) ...[
                  const SizedBox(height: 14),
                  _plateFoodsCard(context, controller, result, s),
                ],

                // Is it wrong?
                if (!result.isPlate && alternatives.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    s.tr('Could also be', 'قد يكون أيضاً'),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary),
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
                              style: TextStyle(fontWeight: FontWeight.w700, color: context.mq.ink),
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
                    if (!result.isPlate && result.verificationStatus == aiEstimateStatus && result.imageBytes != null)
                      smallAction(
                        icon: MiqdarIcons.autoAwesome,
                        label: s.tr('Not right? Tell Gemini', 'غير صحيح؟ أخبر Gemini'),
                        onPressed: correcting ? null : () => _askGeminiToCorrect(context, controller),
                        leading: correcting
                            ? const SizedBox.square(
                                dimension: 15,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : null,
                      ),
                    if (!result.isPlate)
                    smallAction(
                      icon: MiqdarIcons.swapHoriz,
                      label: s.tr('Change Food', 'تغيير الصنف'),
                      onPressed: () => _showReplaceFoodDialog(context, controller),
                    ),
                    smallAction(
                      icon: MiqdarIcons.add,
                      label: s.tr('Add Side', 'إضافة صنف'),
                      onPressed: () => _showAddPlateItemDialog(context, controller),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Portion
                if (!result.isPlate)
                SurfaceCard(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.tr('Portion', 'الحصة'),
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: context.mq.ink),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          StepSquareButton(
                            label: '-10 ${s.unitG}',
                            onTap: () => _rescalePrimaryWeight(controller, result.weightG - 10),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: weightEditCtrl,
                              textAlign: TextAlign.center,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: MiqdarType.titleSection.copyWith(color: context.mq.ink),
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
                          StepSquareButton(
                            label: '+10 ${s.unitG}',
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

                if (!result.isPlate && result.additionalItems.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.tr('Also on the plate', 'أيضاً في الطبق'),
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: context.mq.ink),
                        ),
                        const SizedBox(height: 8),
                        ...result.additionalItems.map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              s.isAr && item.nameAr.isNotEmpty ? item.nameAr : item.nameEn,
                              style: TextStyle(fontWeight: FontWeight.w600, color: context.mq.ink),
                            ),
                            subtitle: Text(
                              '${item.weightG.toStringAsFixed(0)} ${s.unitG} • ${item.nutrients.calories.toStringAsFixed(0)} ${s.unitKcal}',
                            ),
                            trailing: IconButton(
                              tooltip: s.tr('Remove', 'إزالة'),
                              icon: Icon(MiqdarIcons.removeCircle, color: context.mq.danger),
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
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: context.mq.ink),
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
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: context.mq.ink),
                        ),
                        subtitle: Text(
                          '${s.mealTypeLabel(selectedMealType)} • ${s.date(consumedAt, 'EEE, h:mm a')}',
                          style: TextStyle(fontSize: 13, color: textSecondary),
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
                              Icon(MiqdarIcons.schedule, size: 18, color: context.mq.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  s.date(consumedAt, 'EEE, d MMM yyyy • h:mm a'),
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.mq.ink),
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
                              prefixIcon: const Icon(MiqdarIcons.notes),
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
      ),
    );
  }

  String _plateTitle(RecognitionResult result, S s) {
    final name = s.isAr && result.plateNameAr.isNotEmpty ? result.plateNameAr : result.plateNameEn;
    return name.isEmpty ? s.tr('Mixed plate', 'طبق مختلط') : name;
  }

  Widget _plateFoodsCard(BuildContext context, MiqdarController controller, RecognitionResult result, S s) {
    final c = context.mq;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.tr('On this plate', 'في هذا الطبق'), style: MiqdarType.bodyStrong.copyWith(color: c.ink)),
          if (result.plateNeedsNames) ...[
            const SizedBox(height: 4),
            Text(
              s.tr('Name every food to save this meal.', 'سمِّ كل طعام لحفظ هذه الوجبة.'),
              style: MiqdarType.caption.copyWith(color: c.accentInk),
            ),
          ],
          const SizedBox(height: 6),
          for (final item in result.plateItems)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showPlateItemSheet(context, controller, result, item),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox.square(
                        dimension: 44,
                        child: switch (controller.plateItemPhotos[item.id]) {
                          final photo? => Image.memory(photo, fit: BoxFit.cover),
                          null => ColoredBox(color: c.surfaceSunken, child: Icon(MiqdarIcons.restaurant, color: c.inkMuted)),
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.isAr && item.nameAr.isNotEmpty ? item.nameAr : item.nameEn,
                            style: MiqdarType.bodyStrong.copyWith(color: item.isUnidentified ? c.accentInk : c.ink),
                          ),
                          Text(
                            [
                              '${item.weightG.toStringAsFixed(0)} ${s.unitG}',
                              if (item.portionSource == PortionSource.manual) item.portionSource.label(s.isAr),
                            ].join(' • '),
                            style: MiqdarType.caption.copyWith(color: c.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      item.isUnidentified
                          ? s.tr('Unknown', 'غير متوفر')
                          : '${item.nutrients.calories.toStringAsFixed(0)} ${s.unitKcal}',
                      style: MiqdarType.label.copyWith(color: item.isUnidentified ? c.accentInk : c.ink),
                    ),
                    Icon(MiqdarIcons.chevronRight, size: 18, color: c.inkMuted),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPlateItemSheet(BuildContext context, MiqdarController controller, RecognitionResult result, MealItemEntry item) {
    final s = S.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(MiqdarIcons.edit),
              title: Text(s.tr('Type the Name', 'اكتب الاسم')),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _typePlateItemName(context, controller, item);
              },
            ),
            ListTile(
              leading: const Icon(MiqdarIcons.search),
              title: Text(s.tr('Search Food', 'ابحث عن طعام')),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _showReplaceFoodDialog(context, controller, onPick: (food) async {
                  final updated = await controller.replacePlateItemFood(item.id, food);
                  if (updated != null && mounted) setState(() => currentResult = updated);
                });
              },
            ),
            ListTile(
              leading: const Icon(MiqdarIcons.scale),
              title: Text(s.tr('Change Weight', 'تغيير الوزن')),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _changePlateItemWeight(context, controller, item);
              },
            ),
            if (result.plateItems.length > 1)
              ListTile(
                leading: Icon(MiqdarIcons.removeCircle, color: context.mq.danger),
                title: Text(s.tr('Remove', 'إزالة'), style: TextStyle(color: context.mq.danger)),
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  final updated = await controller.removePlateItem(item.id);
                  if (updated != null && mounted) setState(() => currentResult = updated);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askText(
    BuildContext context, {
    required String title,
    required String label,
    required String action,
    String initial = '',
    TextInputType? keyboard,
  }) {
    final s = S.of(context);
    final field = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: field,
          autofocus: true,
          keyboardType: keyboard,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: Text(s.tr('Cancel', 'إلغاء'))),
          FilledButton(onPressed: () => Navigator.of(dialogCtx).pop(field.text.trim()), child: Text(action)),
        ],
      ),
    );
  }

  Future<void> _typePlateItemName(BuildContext context, MiqdarController controller, MealItemEntry item) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = await _askText(
      context,
      title: s.tr('What is this food?', 'ما هذا الطعام؟'),
      label: s.tr('Food name', 'اسم الطعام'),
      action: s.tr('Ask Gemini', 'اسأل Gemini'),
    );
    if (name == null || name.isEmpty) return;
    try {
      final updated = await controller.namePlateItem(item.id, name);
      if (updated != null && mounted) setState(() => currentResult = updated);
    } on RecognitionException catch (error) {
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(error.recoveryAdvice(s.isAr)),
      ));
    }
  }

  Future<void> _changePlateItemWeight(BuildContext context, MiqdarController controller, MealItemEntry item) async {
    final s = S.of(context);
    final value = await _askText(
      context,
      title: s.tr('Change Weight', 'تغيير الوزن'),
      label: s.tr('Weight (g)', 'الوزن (غ)'),
      action: s.tr('Save', 'حفظ'),
      initial: item.weightG.toStringAsFixed(0),
      keyboard: const TextInputType.numberWithOptions(decimal: true),
    );
    final grams = value == null ? null : double.tryParse(normalizeDigits(value));
    if (grams == null || grams <= 0) return;
    final updated = await controller.setPlateItemWeight(item.id, grams);
    if (updated != null && mounted) setState(() => currentResult = updated);
  }

  void _showReplaceFoodDialog(
    BuildContext context,
    MiqdarController controller, {
    Future<void> Function(FoodCatalogItem food)? onPick,
  }) {
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
                      prefixIcon: const Icon(MiqdarIcons.search),
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
                            style: TextStyle(fontWeight: FontWeight.w600, color: context.mq.ink),
                          ),
                          subtitle: Text(
                            '${item.secondaryName(s.isAr)} • ${item.per100g.calories.toStringAsFixed(0)} ${s.unitKcal} • ${s.tr('per 100 g', 'لكل 100 غ')}',
                          ),
                          trailing: const Icon(MiqdarIcons.chevronRight),
                          onTap: () async {
                            Navigator.of(sheetCtx).pop();
                            if (onPick != null) {
                              await onPick(item);
                              return;
                            }
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
                            prefixIcon: const Icon(MiqdarIcons.search),
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
                            style: TextStyle(fontWeight: FontWeight.w600, color: context.mq.ink),
                          ),
                          subtitle: Text(
                            '${(food.per100g.calories * itemGrams / 100).toStringAsFixed(0)} ${s.unitKcal} ${s.tr('for', 'لـ')} ${itemGrams.toStringAsFixed(0)} ${s.unitG}',
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
