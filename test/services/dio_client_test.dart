import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/services/dio_client.dart';
import 'package:hai_schedule/services/invalid_credentials_exception.dart';
import 'package:hai_schedule/services/login_expired_exception.dart';

void main() {
  group('DioClient', () {
    test(
      'retries the original request after silent relogin succeeds',
      () async {
        final adapter = _FakeAdapter((options) async {
          final cookie = options.headers['Cookie']?.toString();
          if (cookie == 'fresh-cookie') {
            return ResponseBody.fromString(
              '{"code":"0","message":"ok"}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json; charset=utf-8'],
              },
            );
          }

          return ResponseBody.fromString(
            '<html><body>Not login!</body></html>',
            401,
            headers: {
              Headers.contentTypeHeader: ['text/html; charset=utf-8'],
            },
          );
        });

        var reloginCount = 0;
        final client = DioClient(
          options: BaseOptions(baseUrl: 'https://example.com'),
          reLogin: () async {
            reloginCount++;
            return 'fresh-cookie';
          },
        );
        client.dio.httpClientAdapter = adapter;

        final response = await client.dio.get('/schedule');

        expect(reloginCount, 1);
        expect(response.statusCode, 200);
        expect(response.data, isA<Map>());
        expect((response.data as Map)['message'], 'ok');
        expect(client.currentCookie, 'fresh-cookie');
        expect(adapter.requestLog, hasLength(2));
        expect(adapter.requestLog.first.headers['Cookie'], isNull);
        expect(adapter.requestLog.last.headers['Cookie'], 'fresh-cookie');
        expect(adapter.requestLog.last.extra['retry_after_relogin'], isTrue);
      },
    );

    test('surfaces LoginExpiredException when silent relogin fails', () async {
      final adapter = _FakeAdapter(
        (_) async => ResponseBody.fromString(
          '<html><body>Not login!</body></html>',
          401,
          headers: {
            Headers.contentTypeHeader: ['text/html; charset=utf-8'],
          },
        ),
      );

      final client = DioClient(
        options: BaseOptions(baseUrl: 'https://example.com'),
        reLogin: () async => throw const LoginExpiredException(),
      );
      client.dio.httpClientAdapter = adapter;

      await expectLater(
        client.dio.get('/schedule'),
        throwsA(
          isA<DioException>()
              .having(
                (error) => error.error,
                'error',
                isA<LoginExpiredException>(),
              )
              .having(
                (error) => (error.error as LoginExpiredException).message,
                'message',
                LoginExpiredException.defaultMessage,
              ),
        ),
      );
      expect(adapter.requestLog, hasLength(1));
    });

    test(
      'surfaces InvalidCredentialsException without retrying the request again',
      () async {
        final adapter = _FakeAdapter(
          (_) async => ResponseBody.fromString(
            '<html><body>Not login!</body></html>',
            401,
            headers: {
              Headers.contentTypeHeader: ['text/html; charset=utf-8'],
            },
          ),
        );

        final client = DioClient(
          options: BaseOptions(baseUrl: 'https://example.com'),
          reLogin: () async => throw const InvalidCredentialsException(),
        );
        client.dio.httpClientAdapter = adapter;

        await expectLater(
          client.dio.get('/schedule'),
          throwsA(
            isA<DioException>()
                .having(
                  (error) => error.error,
                  'error',
                  isA<InvalidCredentialsException>(),
                )
                .having(
                  (error) =>
                      (error.error as InvalidCredentialsException).message,
                  'message',
                  InvalidCredentialsException.defaultMessage,
                ),
          ),
        );
        expect(adapter.requestLog, hasLength(1));
      },
    );
  });
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;
  final List<RequestOptions> requestLog = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestLog.add(options);
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
