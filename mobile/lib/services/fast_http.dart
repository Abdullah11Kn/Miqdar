import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// An HTTP client for Google's servers that connects quickly from a phone that is itself a hotspot.
///
/// Measured on 2026-11-15 on his iPhone: opening a connection to Gemini took about 24 s, while the
/// answer itself took 2 s. The client connects over IPv4 when it can (falling back to the normal
/// connection if that fails), keeps connections open for 3 minutes instead of 15 s, and can open one
/// ahead of time with [warmUp], which sends no key and asks nothing.
class FastHttp {
  FastHttp._();

  static http.Client client() {
    final io = HttpClient()..idleTimeout = const Duration(minutes: 3);
    io.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
      final clock = Stopwatch()..start();
      final secure = uri.scheme == 'https';
      try {
        final v4 = await InternetAddress.lookup(uri.host, type: InternetAddressType.IPv4)
            .timeout(const Duration(seconds: 3));
        if (v4.isNotEmpty) {
          debugPrint('[Miqdar timing] ${uri.host}: IPv4 ${v4.first.address} after ${clock.elapsedMilliseconds} ms');
          return await (secure ? SecureSocket.startConnect(v4.first, uri.port) : Socket.startConnect(v4.first, uri.port));
        }
      } catch (error) {
        debugPrint('[Miqdar timing] ${uri.host}: no IPv4 address ($error), connecting as usual');
      }
      return secure ? SecureSocket.startConnect(uri.host, uri.port) : Socket.startConnect(uri.host, uri.port);
    };
    return IOClient(io);
  }

  /// Opens a connection to [host] now, so the next real request does not wait for one. No key is sent.
  static Future<void> warmUp(http.Client client, String host) async {
    final clock = Stopwatch()..start();
    try {
      await client.get(Uri.https(host, '/')).timeout(const Duration(seconds: 30));
      debugPrint('[Miqdar timing] warm-up to $host took ${clock.elapsedMilliseconds} ms');
    } catch (error) {
      debugPrint('[Miqdar timing] warm-up to $host failed after ${clock.elapsedMilliseconds} ms: $error');
    }
  }
}
