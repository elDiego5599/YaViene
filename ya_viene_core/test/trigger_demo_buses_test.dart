import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

void main() {
  test('devuelve true cuando el backend confirma el arranque (200)', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/demo/buses');
      return http.Response('{"started": true}', 200);
    });
    expect(await triggerDemoBuses('C1', 'R1', client: client), isTrue);
  });

  test('devuelve false ante un 404 del backend', () async {
    final client = MockClient((_) async => http.Response('not found', 404));
    expect(await triggerDemoBuses('C1', 'R1', client: client), isFalse);
  });

  test('devuelve false ante un 5xx del backend', () async {
    final client = MockClient((_) async => http.Response('boom', 500));
    expect(await triggerDemoBuses('C1', 'R1', client: client), isFalse);
  });

  test('devuelve false ante un error de red', () async {
    final client =
        MockClient((_) async => throw http.ClientException('red caída'));
    expect(await triggerDemoBuses('C1', 'R1', client: client), isFalse);
  });
}