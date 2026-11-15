import 'dart:async';
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
      // Short: a scale photo with no barcode must not hold up Gemini.
      final capture = await scanner.analyzeImage(file.path).timeout(const Duration(milliseconds: 1500));
      return capture?.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    } catch (_) {
      return null;
    } finally {
      // Cleaning up must never hold up the answer.
      unawaited(scanner?.dispose().catchError((Object _) {}));
      final used = file;
      if (used != null) unawaited(used.delete().then((_) {}, onError: (Object _) {}));
    }
  }
}

/// Never finds a barcode: for tests, and anywhere the camera's detector is not wanted.
class NoBarcodeReader implements BarcodeReader {
  const NoBarcodeReader();

  @override
  Future<String?> read(Uint8List jpeg) async => null;
}
