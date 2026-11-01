import 'package:flutter_test/flutter_test.dart';
import 'package:miqdar_mobile/services/api_service.dart';

void main() {
  test('a typed scale address becomes a full URL', () {
    expect(normalizeScaleAddress('foodscale.local'), 'http://foodscale.local:8080');
    expect(normalizeScaleAddress(' foodscale.local:9000/ '), 'http://foodscale.local:9000');
    expect(normalizeScaleAddress('192.168.1.20'), 'http://192.168.1.20:8080');
    expect(normalizeScaleAddress('localhost'), 'http://localhost:8080');
    expect(normalizeScaleAddress('abc.trycloudflare.com'), 'https://abc.trycloudflare.com');
    expect(normalizeScaleAddress('http://10.0.0.5:8080/'), 'http://10.0.0.5:8080');
    expect(normalizeScaleAddress(''), '');
  });
}
