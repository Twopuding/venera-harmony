import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/network/proxy.dart';

class OhosHttpClientAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.headers['User-Agent'] == null &&
        options.headers['user-agent'] == null) {
      options.headers['User-Agent'] = 'venera/ohos';
    }

    var uri = options.uri;
    var proxy = await _getProxy(uri);

    var client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    client.idleTimeout = const Duration(seconds: 60);

    if (appdata.settings['ignoreBadCertificate'] == true) {
      client.badCertificateCallback = (_, __, ___) => true;
    }

    if (proxy != null) {
      client.findProxy = (_) => 'PROXY $proxy';
    }

    var request = await _buildRequest(client, options, requestStream);
    try {
      var response = await request.close();
      var headers = <String, List<String>>{};
      response.headers.forEach((name, values) {
        headers[name.toLowerCase()] = values;
      });
      var bodyStream = response
          .transform<List<Uint8List>>(
            StreamTransformer.fromHandlers(
              handleData: (List<int> data, EventSink<List<Uint8List>> sink) {
                sink.add([Uint8List.fromList(data)]);
              },
            ),
          )
          .expand((list) => list);
      return ResponseBody(
        bodyStream,
        response.statusCode,
        statusMessage: response.reasonPhrase,
        isRedirect: response.isRedirect,
        headers: headers,
      );
    } catch (e) {
      client.close(force: true);
      rethrow;
    }
  }

  Future<HttpClientRequest> _buildRequest(
    HttpClient client,
    RequestOptions options,
    Stream<Uint8List>? requestStream,
  ) async {
    var method = options.method.toUpperCase();
    var uri = options.uri;
    HttpClientRequest request;

    switch (method) {
      case 'GET':
        request = await client.getUrl(uri);
        break;
      case 'POST':
        request = await client.postUrl(uri);
        break;
      case 'PUT':
        request = await client.putUrl(uri);
        break;
      case 'DELETE':
        request = await client.deleteUrl(uri);
        break;
      case 'PATCH':
        request = await client.patchUrl(uri);
        break;
      case 'HEAD':
        request = await client.headUrl(uri);
        break;
      default:
        request = await client.openUrl(method, uri);
    }

    options.headers.forEach((key, value) {
      if (value != null) {
        request.headers.set(key, value.toString());
      }
    });

    if (requestStream != null) {
      await request.addStream(requestStream);
    } else if (options.data != null) {
      var data = options.data;
      if (data is String) {
        request.write(data);
      } else if (data is List<int>) {
        request.add(data);
      } else if (data is Map) {
        request.headers
            .set('Content-Type', 'application/x-www-form-urlencoded');
        var encoded = _encodeFormData(data);
        request.write(encoded);
      }
    }

    return request;
  }

  String _encodeFormData(Map data) {
    var parts = <String>[];
    data.forEach((key, value) {
      parts.add('${Uri.encodeQueryComponent(key.toString())}='
          '${Uri.encodeQueryComponent(value.toString())}');
    });
    return parts.join('&');
  }

  Future<String?> _getProxy(Uri uri) async {
    if ((appdata.settings['proxy'] as String).trim() == 'system') {
      const channel = MethodChannel('venera/method_channel');
      try {
        var res = await channel.invokeMethod<String>('getProxy');
        if (res == null || res == 'No Proxy') return null;
        if (res.contains(';')) {
          final prefix = uri.scheme == 'https' ? 'https=' : 'http=';
          for (var proxy in res.split(';')) {
            proxy = proxy.trim();
            if (proxy.startsWith(prefix)) {
              return proxy.substring(prefix.length);
            }
          }
          for (var proxy in res.split(';')) {
            proxy = proxy.trim();
            if (proxy.startsWith('https=')) {
              return proxy.substring(6);
            }
            if (proxy.startsWith('http=')) {
              return proxy.substring(5);
            }
          }
        }
        var regex = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d+$');
        if (!regex.hasMatch(res.trim())) return null;
        return res.trim();
      } catch (_) {
        return null;
      }
    }
    return getProxy();
  }
}
