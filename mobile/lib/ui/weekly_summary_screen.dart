import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:printing/printing.dart';

import '../app.dart';
import '../l10n/strings.dart';
import '../models/nutrition.dart';
import '../services/report_html.dart';
import '../theme.dart';

/// The last 7 days on one page, made on this phone and shared only when the user taps Share.
class WeeklySummaryScreen extends StatefulWidget {
  const WeeklySummaryScreen({super.key});

  @override
  State<WeeklySummaryScreen> createState() => _WeeklySummaryScreenState();
}

class _WeeklySummaryScreenState extends State<WeeklySummaryScreen> {
  Future<Uint8List?>? _pdf;

  Future<String?> _font(String path) async {
    try {
      final data = await rootBundle.load(path);
      return base64Encode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    } catch (_) {
      return null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pdf ??= _make();
  }

  Future<Uint8List?> _make() async {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    final week = controller.weeklySummary();
    if (week.isEmpty) return null;
    final name = controller.account.displayName == UserAccount.defaultName
        ? ''
        : (s.isAr && controller.account.displayNameAr.isNotEmpty ? controller.account.displayNameAr : controller.account.displayName);
    final html = weeklySummaryHtml(
      week,
      s,
      name: name,
      fontRegular: await _font('assets/fonts/thmanyah/thmanyah-sans-Regular.otf'),
      fontBold: await _font('assets/fonts/thmanyah/thmanyah-sans-Bold.otf'),
    );
    // See DoctorReportScreen: the only way here to keep Thmanyah in a PDF.
    // ignore: deprecated_member_use
    return Printing.convertHtml(html: html, format: PdfPageFormat.a4);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.tr('Weekly Summary', 'ملخص الأسبوع'))),
      body: SafeArea(
        child: FutureBuilder<Uint8List?>(
          future: _pdf,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final bytes = snapshot.data;
            if (snapshot.hasError || bytes == null) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  snapshot.hasError
                      ? s.tr('The summary could not be made. Try again.', 'تعذر إعداد الملخص. حاول مرة أخرى.')
                      : s.tr('No meals were logged in the last 7 days.', 'لم تُسجل وجبات في آخر 7 أيام.'),
                  textAlign: TextAlign.center,
                  style: MiqdarType.body.copyWith(color: context.mq.ink),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: PdfPreview(
                    build: (_) async => bytes,
                    useActions: false,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    pdfFileName: 'miqdar-week.pdf',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: FilledButton(
                    onPressed: () => Printing.sharePdf(bytes: bytes, filename: 'miqdar-week.pdf'),
                    child: Text(s.tr('Share', 'مشاركة')),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
