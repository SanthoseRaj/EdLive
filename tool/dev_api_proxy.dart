import 'dart:io';

const String _defaultBackendOrigin =
    'https://schoolmanagement.canadacentral.cloudapp.azure.com';
const String _listenHost = String.fromEnvironment(
  'PROXY_HOST',
  defaultValue: '127.0.0.1',
);
const int _listenPort = int.fromEnvironment('PROXY_PORT', defaultValue: 8081);
const String _backendOriginValue = String.fromEnvironment(
  'BACKEND_ORIGIN',
  defaultValue: _defaultBackendOrigin,
);

final Set<String> _hopByHopHeaders = <String>{
  'connection',
  'content-length',
  'host',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
};

Future<void> main() async {
  final backendOrigin = Uri.parse(_backendOriginValue);
  final server = await HttpServer.bind(_listenHost, _listenPort);

  stdout.writeln(
    'Proxy listening on http://$_listenHost:$_listenPort -> $backendOrigin',
  );

  await for (final request in server) {
    _handleRequest(request, backendOrigin);
  }
}

Future<void> _handleRequest(HttpRequest request, Uri backendOrigin) async {
  try {
    if (request.method.toUpperCase() == 'OPTIONS') {
      _writeCorsHeaders(request.response.headers, request);
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    final client = HttpClient();
    final targetUri = backendOrigin.replace(
      path: request.uri.path,
      query: request.uri.hasQuery ? request.uri.query : null,
    );

    final upstreamRequest = await client.openUrl(request.method, targetUri);
    _copyRequestHeaders(request.headers, upstreamRequest.headers);

    final bodyBytes = await request.fold<List<int>>(<int>[], (allBytes, chunk) {
      allBytes.addAll(chunk);
      return allBytes;
    });
    if (bodyBytes.isNotEmpty) {
      upstreamRequest.add(bodyBytes);
    }

    final upstreamResponse = await upstreamRequest.close();

    request.response.statusCode = upstreamResponse.statusCode;
    _copyResponseHeaders(upstreamResponse.headers, request.response.headers);
    _writeCorsHeaders(request.response.headers, request);
    await upstreamResponse.pipe(request.response);
  } catch (error, stackTrace) {
    stderr.writeln('Proxy error for ${request.method} ${request.uri}: $error');
    stderr.writeln(stackTrace);

    try {
      _writeCorsHeaders(request.response.headers, request);
      request.response.statusCode = HttpStatus.badGateway;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        '{"message":"Proxy request failed","details":${_jsonString(error.toString())}}',
      );
      await request.response.close();
    } catch (_) {
      // Ignore secondary write failures if the response is already closed.
    }
  }
}

void _copyRequestHeaders(HttpHeaders source, HttpHeaders target) {
  source.forEach((name, values) {
    final normalizedName = name.toLowerCase();
    if (_hopByHopHeaders.contains(normalizedName) ||
        normalizedName == 'origin' ||
        normalizedName == 'referer') {
      return;
    }

    for (final value in values) {
      target.add(name, value);
    }
  });
}

void _copyResponseHeaders(HttpHeaders source, HttpHeaders target) {
  source.forEach((name, values) {
    final normalizedName = name.toLowerCase();
    if (_hopByHopHeaders.contains(normalizedName) ||
        normalizedName.startsWith('access-control-')) {
      return;
    }

    for (final value in values) {
      target.add(name, value);
    }
  });
}

void _writeCorsHeaders(HttpHeaders headers, HttpRequest request) {
  final origin = request.headers.value('origin');
  headers.set('Access-Control-Allow-Origin', origin ?? '*');
  headers.set('Vary', 'Origin');
  headers.set(
    'Access-Control-Allow-Methods',
    'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  );
  headers.set(
    'Access-Control-Allow-Headers',
    request.headers.value('access-control-request-headers') ??
        'Origin, Content-Type, Accept, Authorization',
  );
  headers.set('Access-Control-Expose-Headers', 'Content-Type, Content-Length');
}

String _jsonString(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\r', r'\r')
      .replaceAll('\n', r'\n');
  return '"$escaped"';
}
