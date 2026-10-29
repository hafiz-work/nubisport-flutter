import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Answers by "METHOD path" (query string included): (status, JSON body). Records request bodies.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.routes);
  final Map<String, (int, Object)> routes;

  /// Request bodies by "METHOD path".
  final Map<String, Object?> bodies = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    bodies[key] = options.data;
    final (status, body) = routes[key] ?? (404, {'success': false, 'error': 'Not found'});
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
