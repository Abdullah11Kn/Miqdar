import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app.dart';
import '../l10n/strings.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'scan_and_add_screen.dart' show RecognitionResultScreen;

/// The phone camera, looking for a barcode. Pops with the first code it reads.
class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final _scanner = MobileScannerController(
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE],
  );
  bool _done = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(s.tr('Scan a Barcode', 'امسح الباركود'))),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _scanner,
            onDetect: (capture) {
              final code = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
              if (code == null || _done) return;
              _done = true;
              Navigator.of(context).pop(code);
            },
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  s.tr('The camera is not available. Allow Miqdar to use the camera in Settings.',
                      'الكاميرا غير متاحة. اسمح لمقدار باستخدام الكاميرا من الإعدادات.'),
                  textAlign: TextAlign.center,
                  style: MiqdarType.body.copyWith(color: Colors.white),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Container(
              width: 260,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Text(
              s.tr('Point the camera at the barcode on the pack.', 'وجّه الكاميرا إلى الباركود على العبوة.'),
              textAlign: TextAlign.center,
              style: MiqdarType.bodyStrong.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scans a barcode and opens the result with the pack's values. Grams come from the scale when
/// something is on it, otherwise from the pack's serving. An unknown product offers label mode.
Future<void> scanBarcodeAndLog(BuildContext context) async {
  final s = S.of(context);
  final controller = MiqdarScope.of(context);
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final code = await navigator.push<String>(MaterialPageRoute(builder: (_) => const BarcodeScanScreen()));
  if (code == null || !context.mounted) return;
  messenger.showSnackBar(SnackBar(content: Text(s.tr('Looking up the product…', 'جارٍ البحث عن المنتج…'))));
  final draft = await controller.prepareBarcodeDraft(code);
  messenger.hideCurrentSnackBar();
  if (!context.mounted) return;
  if (draft != null) {
    await navigator.push(MaterialPageRoute(builder: (_) => RecognitionResultScreen(result: draft)));
    return;
  }
  final readLabel = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(MiqdarIcons.barcodeScanner),
      title: Text(s.tr('Product not found', 'المنتج غير موجود')),
      content: Text(s.tr(
        'Open Food Facts does not know this barcode. You can photograph the nutrition label instead.',
        'لا تعرف قاعدة Open Food Facts هذا الباركود. يمكنك تصوير ملصق القيم الغذائية بدلًا من ذلك.',
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(s.tr('Cancel', 'إلغاء'))),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(s.tr('Read the Label', 'قراءة الملصق'))),
      ],
    ),
  );
  if (readLabel == true && context.mounted) await readLabelAndLog(context);
}

/// Label mode: the phone photographs the nutrition label and Gemini reads it.
Future<void> readLabelAndLog(BuildContext context) async {
  final s = S.of(context);
  final controller = MiqdarScope.of(context);
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90, maxWidth: 2000);
  if (picked == null || !context.mounted) return;
  final bytes = await picked.readAsBytes();
  messenger.showSnackBar(SnackBar(
    duration: const Duration(seconds: 30),
    content: Text(s.tr('Reading the label…', 'جارٍ قراءة الملصق…')),
  ));
  try {
    final draft = await controller.readNutritionLabel(bytes);
    messenger.hideCurrentSnackBar();
    await navigator.push(MaterialPageRoute(builder: (_) => RecognitionResultScreen(result: draft)));
  } on RecognitionException catch (error) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(error.code == 'LABEL_UNREADABLE'
          ? s.tr('The label could not be read. Try a closer, sharper photo.', 'تعذّرت قراءة الملصق. جرّب صورة أقرب وأوضح.')
          : s.tr('Gemini is not available right now. Try again soon.', 'Gemini غير متاح الآن. حاول بعد قليل.')),
    ));
  }
}
