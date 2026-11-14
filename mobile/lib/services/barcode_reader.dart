import 'dart:io';
import 'dart:typed_data';

import 'package:mobile_scanner/mobile_scanner.dart';

/// Finds a product barcode in a photo, such as the one the scale takes.
abstract class BarcodeReader {
  /// The first EAN or UPC code in [jpeg], or null when there is none.
  Future<String?> read(Uint8List jpeg);
}

/// Reads barcodes on the phone with the platform's own detector (Apple Vision on iOS). Nothing is sent anywhere.
class PhotoBarcodeReader implements BarcodeReader {
  @override
  Future<String?> read(Uint8List jpeg) async {
    if (jpeg.isEmpty) return null;
    File? file;
    MobileScannerController? scanner;
    try {
      scanner = MobileScannerController(
        autoStart: false,
        formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE],
      );
      file = File('${Directory.systemTemp.path}/miqdar-barcode-${DateTime.now().microsecondsSinceEpoch}.jpg');
      await file.writeAsBytes(jpeg, flush: true);
      final capture = await scanner.analyzeImage(file.path).timeout(const Duration(seconds: 4));
      return capture?.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    } catch (_) {
      return null;
    } finally {
      await scanner?.dispose().catchError((Object _) {});
      if (file != null && await file.exists()) await file.delete().catchError((Object _) => file!);
    }
  }
}
