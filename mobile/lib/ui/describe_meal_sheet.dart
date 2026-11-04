import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../app.dart';
import '../l10n/strings.dart';
import '../models/nutrition.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'scan_and_add_screen.dart' show RecognitionResultScreen;

/// Logs a meal away from the scale, for someone in a hurry or with a half-eaten plate.
/// Opens the Review screen when Gemini answers. Nothing is saved without review.
Future<void> openDescribeMeal(BuildContext context, {bool startWithCamera = false}) async {
  final picked = await showModalBottomSheet<_Estimate>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _DescribeMealSheet(startWithCamera: startWithCamera),
  );
  if (picked == null || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => RecognitionResultScreen(result: picked.result, previewBytes: picked.photo),
    ),
  );
}

class _Estimate {
  const _Estimate(this.result, this.photo);

  final RecognitionResult result;
  final Uint8List? photo;
}

class _DescribeMealSheet extends StatefulWidget {
  const _DescribeMealSheet({required this.startWithCamera});

  final bool startWithCamera;

  @override
  State<_DescribeMealSheet> createState() => _DescribeMealSheetState();
}

class _DescribeMealSheetState extends State<_DescribeMealSheet> {
  final _text = TextEditingController();
  final _picker = ImagePicker();
  final _speech = SpeechToText();

  Uint8List? _photo;
  bool _working = false;
  bool _listening = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (widget.startWithCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickPhoto(ImageSource.camera));
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final selected = await _picker.pickImage(source: source, imageQuality: 88, maxWidth: 1600);
      if (selected == null) return;
      final bytes = await selected.readAsBytes();
      if (mounted) setState(() => _photo = bytes);
    } catch (_) {
      if (!mounted) return;
      // A simulator has no camera.
      if (source == ImageSource.camera) return _pickPhoto(ImageSource.gallery);
      final s = S.of(context);
      setState(() => _message = s.tr('Could not open your photos.', 'تعذر فتح صورك.'));
    }
  }

  Future<void> _toggleListening() async {
    final s = S.of(context);
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    bool ready;
    try {
      ready = await _speech.initialize(
        onStatus: (status) {
          if (mounted && status != 'listening') setState(() => _listening = false);
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
    } catch (_) {
      ready = false;
    }
    if (!mounted) return;
    if (!ready) {
      setState(() {
        _message = s.tr(
          'Voice is not available. Check microphone permission in Settings, or type instead.',
          'الصوت غير متاح. تحقق من إذن الميكروفون في الإعدادات، أو اكتب بدلاً من ذلك.',
        );
      });
      return;
    }
    setState(() {
      _listening = true;
      _message = null;
    });
    // Speech only fills the field, so it can be read and corrected before it is sent.
    await _speech.listen(
      listenOptions: SpeechListenOptions(localeId: s.isAr ? 'ar_SA' : 'en_US'),
      onResult: (result) {
        if (mounted) setState(() => _text.text = result.recognizedWords);
      },
    );
  }

  Future<void> _estimate() async {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    final words = _text.text.trim();
    if (words.isEmpty && _photo == null) {
      setState(() => _message = s.tr('Type what you ate, or add a photo.', 'اكتب ما أكلته، أو أضف صورة.'));
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    if (_listening) await _speech.stop();
    setState(() {
      _working = true;
      _listening = false;
      _message = null;
    });
    try {
      final result = await controller.logEstimatedMeal(description: words, photo: _photo);
      if (mounted) Navigator.of(context).pop(_Estimate(result, _photo));
    } on RecognitionException catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _message = error.code == 'NOT_FOOD'
            ? s.tr('That does not look like food. Try describing it differently.', 'لا يبدو هذا طعاماً. جرّب وصفه بطريقة أخرى.')
            : s.tr(
                'Gemini could not answer. You can still use Search or Manual in Add Meal.',
                'تعذر على Gemini الإجابة. يمكنك استخدام البحث أو الإدخال اليدوي في إضافة وجبة.',
              );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.mq;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.tr('No Time to Weigh?', 'لا وقت للوزن؟'), style: MiqdarType.titleSection.copyWith(color: c.ink)),
            const SizedBox(height: 4),
            Text(
              s.tr(
                'Say what you ate. Gemini estimates the food and the amount, so this meal is marked as estimated, not weighed.',
                'اذكر ما أكلته. يقدّر Gemini الطعام والكمية، لذا تُسجل هذه الوجبة كتقدير وليست موزونة.',
              ),
              style: MiqdarType.body.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _text,
              minLines: 2,
              maxLines: 4,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: s.tr('Half a plate of chicken kabsa', 'نصف طبق كبسة دجاج'),
                suffixIcon: IconButton(
                  tooltip: s.tr('Say it', 'انطقه'),
                  onPressed: _working ? null : _toggleListening,
                  icon: Icon(
                    _listening ? MiqdarIcons.close : MiqdarIcons.mic,
                    color: _listening ? c.accentInk : null,
                  ),
                ),
              ),
            ),
            if (_listening) ...[
              const SizedBox(height: 6),
              Text(s.tr('Listening…', 'جارٍ الاستماع…'), style: MiqdarType.caption.copyWith(color: c.accentInk)),
            ],
            const SizedBox(height: 12),
            if (_photo != null)
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(_photo!, width: 64, height: 64, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s.tr('Photo added', 'أُضيفت الصورة'), style: MiqdarType.body.copyWith(color: c.ink))),
                  IconButton(
                    tooltip: s.tr('Remove', 'إزالة'),
                    onPressed: () => setState(() => _photo = null),
                    icon: Icon(MiqdarIcons.close, color: c.inkMuted),
                  ),
                ],
              )
            else
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(MiqdarIcons.photoCamera, size: 18),
                    label: Text(s.tr('Camera', 'الكاميرا')),
                  ),
                  TextButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(MiqdarIcons.photoLibrary, size: 18),
                    label: Text(s.tr('Photos', 'الصور')),
                  ),
                ],
              ),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(_message!, style: MiqdarType.body.copyWith(color: c.accentInk)),
            ],
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58)),
              onPressed: _working ? null : _estimate,
              child: _working
                  ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                  : Text(s.tr('Get an Estimate', 'احصل على تقدير')),
            ),
          ],
        ),
      ),
    );
  }
}
