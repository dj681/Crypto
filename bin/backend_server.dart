import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

final Uri _binanceTickerUri = Uri.parse('https://api.binance.com/api/v3/ticker/24hr');
final Uri _binanceExchangeInfoUri =
    Uri.parse('https://api.binance.com/api/v3/exchangeInfo');

Future<void> main() async {
  final portEnv = Platform.environment['PORT']?.trim();
  final port = int.tryParse(portEnv ?? '') ?? 8080;

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  final httpClient = http.Client();

  stdout.writeln('Backend running on http://0.0.0.0:$port');

  await for (final request in server) {
    _setCorsHeaders(request.response);

    if (request.method == 'OPTIONS') {
      request.response
        ..statusCode = HttpStatus.noContent
        ..close();
      continue;
    }

    try {
      if (request.method != 'GET') {
        _json(
          request.response,
          HttpStatus.methodNotAllowed,
          {'error': 'Method not allowed'},
        );
        continue;
      }

      if (request.uri.path == '/health') {
        _json(
          request.response,
          HttpStatus.ok,
          {'status': 'ok', 'service': 'crypto-backend'},
        );
        continue;
      }

      if (request.uri.path == '/api/binance/ticker24h') {
        final uri = _withQuery(_binanceTickerUri, request.uri.queryParameters);
        await _proxyGet(httpClient, uri, request.response);
        continue;
      }

      if (request.uri.path == '/api/binance/exchangeInfo') {
        final uri = _withQuery(_binanceExchangeInfoUri, request.uri.queryParameters);
        await _proxyGet(httpClient, uri, request.response);
        continue;
      }

      _json(
        request.response,
        HttpStatus.notFound,
        {'error': 'Not found'},
      );
    } catch (_) {
      _json(
        request.response,
        HttpStatus.badGateway,
        {'error': 'Upstream request failed'},
      );
    }
  }
}

Uri _withQuery(Uri uri, Map<String, String> query) {
  if (query.isEmpty) return uri;
  return uri.replace(queryParameters: query);
}

Future<void> _proxyGet(http.Client client, Uri uri, HttpResponse response) async {
  final upstream = await client.get(uri).timeout(const Duration(seconds: 20));
  response.statusCode = upstream.statusCode;
  final contentType = upstream.headers['content-type'];
  if (contentType != null && contentType.isNotEmpty) {
    response.headers.set(HttpHeaders.contentTypeHeader, contentType);
  } else {
    response.headers.contentType = ContentType.json;
  }
  response.write(upstream.body);
  await response.close();
}

void _setCorsHeaders(HttpResponse response) {
  response.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
  response.headers.set(HttpHeaders.accessControlAllowMethodsHeader, 'GET, OPTIONS');
  response.headers.set(HttpHeaders.accessControlAllowHeadersHeader, 'Content-Type');
}

void _json(HttpResponse response, int statusCode, Map<String, Object> body) {
  response.statusCode = statusCode;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  response.close();
}
