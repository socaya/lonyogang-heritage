import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lonyogang_heritage/data/fx_remote.dart';

Future<HttpServer> _startFakeFx(
    void Function(HttpRequest) onRequest) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  unawaited(server.forEach(onRequest));
  return server;
}

void main() {
  test('maps the /fx/rates response into FxRate objects', () async {
    final server = await _startFakeFx((req) async {
      expect(req.uri.path, '/fx/rates');
      req.response.statusCode = 200;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({
        'rates': [
          {
            'currency': 'usd',
            'ugxPerUnit': 3850,
            'asOf': '2026-11-01',
            'source': 'exchangerate.host',
          },
          {
            'currency': 'KES',
            'ugxPerUnit': 29,
            'asOf': '2026-11-01',
            'source': 'exchangerate.host',
          },
        ]
      }));
      await req.response.close();
    });
    try {
      final client = FxRemoteClient(
          baseUri: Uri.parse('http://${server.address.host}:${server.port}'));
      final rates = await client.fetchRates();
      expect(rates, hasLength(2));
      expect(rates.first.currency, 'USD');
      expect(rates.first.ugxPerUnit, 3850);
      expect(rates.first.source, startsWith('server:'));
      client.close();
    } finally {
      await server.close(force: true);
    }
  });

  test('throws when the server returns a non-2xx status', () async {
    final server = await _startFakeFx((req) async {
      req.response.statusCode = 500;
      req.response.write('oops');
      await req.response.close();
    });
    try {
      final client = FxRemoteClient(
          baseUri: Uri.parse('http://${server.address.host}:${server.port}'));
      await expectLater(client.fetchRates(), throwsA(isA<HttpException>()));
      client.close();
    } finally {
      await server.close(force: true);
    }
  });
}
