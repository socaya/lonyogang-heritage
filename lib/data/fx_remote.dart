import 'dart:convert';
import 'dart:io';

import '../domain/models.dart';

/// Thin HTTP client for the backend's public `/fx/rates` endpoint. The
/// endpoint does not require authentication — rates are market data, not
/// personal data — so this client can run before an account is created.
class FxRemoteClient {
  FxRemoteClient({required Uri baseUri, HttpClient? httpClient})
      : _baseUri = baseUri,
        _http = httpClient ?? HttpClient();

  final Uri _baseUri;
  final HttpClient _http;

  /// Fetches the freshest set of FX rates. Optionally scope to a subset of
  /// three-letter codes; omit to let the server decide the default basket.
  Future<List<FxRate>> fetchRates({List<String>? currencies, DateTime? asOf}) async {
    final query = <String, String>{};
    if (currencies != null && currencies.isNotEmpty) {
      query['currencies'] = currencies.map((c) => c.toUpperCase()).join(',');
    }
    if (asOf != null) {
      query['asOf'] = '${asOf.year.toString().padLeft(4, '0')}-${asOf.month.toString().padLeft(2, '0')}-${asOf.day.toString().padLeft(2, '0')}';
    }
    final uri = _baseUri
        .resolve('/fx/rates')
        .replace(queryParameters: query.isEmpty ? null : query);
    final req = await _http.getUrl(uri);
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('fx rates HTTP ${res.statusCode}: $body', uri: uri);
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    final rates = (json['rates'] as List<dynamic>? ?? const []).map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      return FxRate(
        currency: (m['currency'] as String).toUpperCase(),
        ugxPerUnit: (m['ugxPerUnit'] as num).toInt(),
        asOf: DateTime.parse(m['asOf'] as String),
        source: 'server:${m['source'] ?? 'unknown'}',
      );
    }).toList();
    return rates;
  }

  void close() => _http.close(force: true);
}
