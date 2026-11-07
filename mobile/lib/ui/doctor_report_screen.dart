import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:printing/printing.dart';

import '../app.dart';
import '../l10n/strings.dart';
import '../services/report_html.dart';
import '../theme.dart';
import 'widgets/charts_and_gauges.dart';

/// The doctor's report: made on this phone from the user's own meals, previewed, then shared.
class DoctorReportScreen extends StatefulWidget {
  const DoctorReportScreen({super.key});

  @override
  State<DoctorReportScreen> createState() => _DoctorReportScreenState();
}

class _DoctorReportScreenState extends State<DoctorReportScreen> {
  int days = 14;
  Future<Uint8List?>? pdf;
  int? madeFor;

  Future<String?> _font(String path) async {
    try {
      final data = await rootBundle.load(path);
      return base64Encode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    } catch (_) {
      return null; // A fresh clone without the fonts still makes a report, in the system font.
    }
  }

  Future<Uint8List?> _make() async {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    final report = controller.doctorReport(days, isAr: s.isAr);
    if (report.isEmpty) return null;
    final html = doctorReportHtml(
      report,
      s,
      fontRegular: await _font('assets/fonts/thmanyah/thmanyah-sans-Regular.otf'),
      fontBold: await _font('assets/fonts/thmanyah/thmanyah-sans-Bold.otf'),
    );
    // Deprecated in the package but still built in on iOS and Android, and the only way here to keep
    // Thmanyah: its CFF outlines cannot go through the pdf package, and the licence forbids converting it.
    // ignore: deprecated_member_use
    return Printing.convertHtml(html: html, format: PdfPageFormat.a4);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.tr("Doctor's Report", 'تقرير للطبيب'))),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.tr(
                      'A PDF of your meals for your doctor or dietitian: averages, carbs by meal, days within your goals, patterns, weight and daily totals. It is made on this phone and nothing is sent anywhere until you share it.',
                      'ملف PDF لوجباتك لطبيبك أو أخصائي التغذية: المتوسطات، والكربوهيدرات حسب الوجبة، والأيام ضمن أهدافك، والأنماط، والوزن، والمجاميع اليومية. يُعدّ على هذا الهاتف ولا يُرسل إلى أي مكان حتى تشاركه.',
                    ),
                    style: MiqdarType.body.copyWith(color: context.mq.inkMuted),
                  ),
                  const SizedBox(height: 12),
                  MiqdarSegmented<int>(
                    options: [
                      (value: 7, label: s.tr('7 Days', '7 أيام'), icon: null),
                      (value: 14, label: s.tr('14 Days', '14 يوماً'), icon: null),
                      (value: 30, label: s.tr('30 Days', '30 يوماً'), icon: null),
                      (value: 90, label: s.tr('90 Days', '90 يوماً'), icon: null),
                    ],
                    value: days,
                    onChanged: (value) => setState(() => days = value),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => setState(() {
                      madeFor = days;
                      pdf = _make();
                    }),
                    child: Text(madeFor == null ? s.tr('Make Report', 'إعداد التقرير') : s.tr('Make Again', 'إعداد مرة أخرى')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: pdf == null
                  ? const SizedBox.shrink()
                  : FutureBuilder<Uint8List?>(
                      future: pdf,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return _message(context, s.tr('The report could not be made. Try again.', 'تعذر إعداد التقرير. حاول مرة أخرى.'));
                        }
                        final bytes = snapshot.data;
                        if (bytes == null) {
                          return _message(
                            context,
                            s.tr('No meals were logged in the last $madeFor days.', 'لم تُسجل وجبات في آخر $madeFor يوماً.'),
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
                                pdfFileName: 'miqdar-report.pdf',
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                              child: FilledButton(
                                onPressed: () => Printing.sharePdf(bytes: bytes, filename: 'miqdar-report.pdf'),
                                child: Text(s.tr('Share', 'مشاركة')),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text(text, textAlign: TextAlign.center, style: MiqdarType.body.copyWith(color: context.mq.ink)),
      );
}
