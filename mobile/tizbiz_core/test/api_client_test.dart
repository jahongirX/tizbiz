import 'dart:async';

import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import 'support/fake_adapter.dart';
import 'support/fixtures.dart';
import 'support/helpers.dart';

void main() {
  late FakeAdapter adapter;

  setUp(() => adapter = FakeAdapter());

  test('1. GET unwraps data; URL trims trailing slash; Accept header', () async {
    adapter.reply(200, '{"data":{"x":1}}');
    final api = testClient(adapter);
    final data = await api.get<Map<String, dynamic>>(Endpoints.authMe);
    expect(data, {'x': 1});
    final r = adapter.requests.single;
    expect(r.uri.toString(), 'https://api.test/v1/auth/me');
    expect(r.method, 'GET');
    expect(r.headers['accept'], 'application/json');
    expect(r.headers.containsKey('content-type'), isFalse);
  });

  test('2. getPage reads meta; reviews meta extras feed RatingSummary', () async {
    adapter.reply(200, '{"data":[{"id":1}],"meta":{"page":1,"per_page":20,"total":5,"pages":1}}');
    adapter.reply(200, directoryReviewsJson);
    final api = testClient(adapter);
    final page = await api.getPage(Endpoints.reviews, (m) => JsonRead.integer(m['id']));
    expect(page.items, [1]);
    expect(page.meta.total, 5);
    expect(page.hasMore, isFalse);
    expect(page.meta.nextPage, isNull);

    final reviews = await api.getPage(Endpoints.directoryReviews('shox-barber'), Review.fromJson);
    expect(reviews.items.single.id, 88);
    expect(reviews.meta.extra['avg'], 4.73);
    final summary = RatingSummary.fromMeta(reviews.meta);
    expect(summary.count, 15);
    expect(summary.distribution[5], 12);
    expect(summary.avg, 4.73);
  });

  test('3. getPage without meta; getList with [] and {}', () async {
    adapter.reply(200, '{"data":[{"id":1},{"id":2}]}');
    adapter.reply(200, '{"data":[]}');
    adapter.reply(200, '{"data":{}}');
    adapter.reply(200, '{"data":null}');
    final api = testClient(adapter);
    final page = await api.getPage('/v1/x', (m) => JsonRead.integer(m['id']));
    expect(page.meta, PageMeta.single(2));
    expect(page.meta.pages, 1);
    expect(await api.getList('/v1/x', (m) => m), isEmpty);
    expect(await api.getList('/v1/x', (m) => m), isEmpty);
    expect(await api.getList('/v1/x', (m) => m), isEmpty);
  });

  test('4. 204 empty body on delete completes with null', () async {
    adapter.reply(204, '');
    final api = testClient(adapter);
    final res = await api.delete<Object?>(Endpoints.consumerFavorite(2));
    expect(res, isNull);
    expect(adapter.requests.single.method, 'DELETE');
  });

  test('5. token attach / RequestAuth.none', () async {
    final token = bizToken();
    adapter.reply(200, '{"data":1}');
    adapter.reply(200, '{"data":2}');
    final api = testClient(adapter, store: InMemoryTokenStore(token));
    await api.get<int>(Endpoints.authMe);
    await api.post<int>(Endpoints.login, body: {'phone': 'x'}, auth: RequestAuth.none);
    expect(adapter.requests[0].headers['authorization'], 'Bearer $token');
    expect(adapter.requests[1].headers.containsKey('authorization'), isFalse);
    expect(await api.currentToken(), token);
    expect((await api.currentClaims())!.sub, 4);
  });

  test('6. kind mismatch: not attached, store cleared; setToken throws', () async {
    final store = InMemoryTokenStore(bizToken());
    adapter.reply(200, '{"data":1}');
    final api = testClient(adapter, kind: TokenKind.consumer, store: store);
    await api.get<int>(Endpoints.consumerMe);
    expect(adapter.requests.single.headers.containsKey('authorization'), isFalse);
    expect(store.value, isNull);
    expect(() => api.setToken(bizToken()), throwsArgumentError);
    expect(() => api.setToken('garbage'), throwsArgumentError);
    await api.setToken(consumerToken());
    expect(store.value, consumerToken());
  });

  test('7. expired token: not attached, store cleared, hook not called', () async {
    var calls = 0;
    final store = InMemoryTokenStore(bizToken(exp: Dates.toUnix(testNow) - 3600));
    adapter.reply(200, '{"data":1}');
    final api = testClient(adapter, store: store, onUnauthorized: (_) => calls++);
    await api.get<int>(Endpoints.authMe);
    expect(adapter.requests.single.headers.containsKey('authorization'), isFalse);
    expect(store.value, isNull);
    expect(calls, 0);
  });

  test('8. 401 with token: cleared, hook once (also for concurrent 401s)', () async {
    final token = bizToken();
    final store = InMemoryTokenStore(token);
    final errors = <ApiException>[];
    adapter.reply(401, error401Json);
    final api = testClient(adapter, store: store, onUnauthorized: errors.add);
    final changes = <String?>[];
    final sub = api.tokenChanges.listen(changes.add);

    await expectLater(
      api.get<Object?>(Endpoints.authMe),
      throwsA(isA<ApiException>()
          .having((e) => e.isUnauthorized, 'isUnauthorized', isTrue)
          .having((e) => e.message, 'message', 'Sessiya tugadi. Qaytadan kiring.')),
    );
    expect(store.value, isNull);
    expect(errors, hasLength(1));
    expect(await api.currentToken(), isNull);

    // Concurrent: two requests carrying the same new token, both answered 401.
    final token2 = bizToken(sub: 5);
    await api.setToken(token2);
    adapter
      ..delay = const Duration(milliseconds: 5)
      ..reply(401, error401Json)
      ..reply(401, error401Json);
    final results = await Future.wait([
      api.get<Object?>(Endpoints.authMe).then<Object?>((v) => v, onError: (Object e) => e),
      api.get<Object?>(Endpoints.meStats).then<Object?>((v) => v, onError: (Object e) => e),
    ]);
    expect(results, everyElement(isA<ApiException>()));
    expect(adapter.requests[1].headers['authorization'], 'Bearer $token2');
    expect(adapter.requests[2].headers['authorization'], 'Bearer $token2');
    expect(errors, hasLength(2));
    expect(store.value, isNull);
    await Future<void>.delayed(Duration.zero);
    expect(changes, [null, token2, null]);
    await sub.cancel();
  });

  test('9. 401 on login with RequestAuth.none: hook not called, store untouched', () async {
    final token = bizToken();
    final store = InMemoryTokenStore(token);
    var calls = 0;
    adapter.reply(401, loginFailedJson);
    final api = testClient(adapter, store: store, onUnauthorized: (_) => calls++);
    try {
      await api.post<Object?>(Endpoints.login, body: {'phone': '+998901111111', 'password': 'x'}, auth: RequestAuth.none);
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.detail, "Telefon yoki parol noto'g'ri.");
      expect(e.message, "Telefon yoki parol noto'g'ri.");
      expect(e.isUnauthorized, isTrue);
    }
    expect(calls, 0);
    expect(store.value, token);
  });

  test('10. 422 with pointers', () async {
    adapter.reply(422, error422PointersJson);
    final api = testClient(adapter);
    final e = await _error(api.post<Object?>(Endpoints.team, body: {}));
    expect(e.isValidation, isTrue);
    expect(e.fieldErrors, {'phone': "Telefon raqam noto'g'ri.", 'items[2].end_time': "Tugash vaqti noto'g'ri."});
    expect(e.fieldError('phone'), "Telefon raqam noto'g'ri.");
    expect(e.hasFieldErrors, isTrue);
    expect(e.errors, hasLength(2));
    expect(e.errors.last.pointer, 'items[2].end_time');
    expect(e.message, "Telefon raqam noto'g'ri.");
  });

  test('11. 422 generic without pointer', () async {
    adapter.reply(422, error422GenericJson);
    final api = testClient(adapter);
    final e = await _error(api.post<Object?>(Endpoints.paymentsDeposit, body: {}, auth: RequestAuth.none));
    expect(e.fieldErrors, isEmpty);
    expect(e.isValidation, isTrue);
    expect(e.message, "Bu bron uchun oldindan to'lov talab qilinmaydi.");
  });

  test('12. 409 conflict', () async {
    adapter.reply(409, error409Json);
    final api = testClient(adapter);
    final e = await _error(api.post<Object?>(Endpoints.consumerAppointments, body: {}));
    expect(e.isConflict, isTrue);
    expect(e.detail, 'Tanlangan vaqt band.');
    expect(e.title, 'Conflict');
    expect(e.toString(), contains('409'));
    expect(e.toString(), 'ApiException(409 Conflict: Tanlangan vaqt band.)');
  });

  test('13. 403 English server strings are translated', () async {
    adapter.reply(403, error403NoBusinessJson);
    adapter.reply(403, error403RoleJson);
    final api = testClient(adapter);
    final a = await _error(api.get<Object?>(Endpoints.meStats));
    expect(a.isForbidden, isTrue);
    expect(a.message, 'Faol biznes tanlanmagan.');
    final b = await _error(api.get<Object?>(Endpoints.team));
    expect(b.message, "Bu amal uchun ruxsatingiz yo'q.");
  });

  test('14. 429 Retry-After', () async {
    adapter.reply(429, error429Json, {
      'retry-after': ['42'],
    });
    final api = testClient(adapter);
    final e = await _error(api.post<Object?>(Endpoints.consumerOtp, body: {'phone': '900000001'}, auth: RequestAuth.none));
    expect(e.retryAfter, const Duration(seconds: 42));
    expect(e.isRateLimited, isTrue);
  });

  test('15. empty detail falls back to status text', () async {
    adapter.reply(409, error409EmptyJson);
    final api = testClient(adapter);
    final e = await _error(api.post<Object?>(Endpoints.orders, body: {}));
    expect(e.message, "Amalni bajarib bo'lmadi: ma'lumot o'zgargan.");
  });

  test('16. non-JSON 500', () async {
    adapter.reply(500, '<html><body>Internal Server Error</body></html>');
    final api = testClient(adapter);
    final e = await _error(api.get<Object?>(Endpoints.services));
    expect(e.kind, ApiErrorKind.http);
    expect(e.status, 500);
    expect(e.isServer, isTrue);
    expect(e.title, '');
    expect(e.detail, '');
    expect(e.message, "Serverda xatolik. Keyinroq urinib ko'ring.");
  });

  test('17. transport errors', () async {
    adapter
      ..fail(DioExceptionType.connectionTimeout)
      ..fail(DioExceptionType.connectionError)
      ..fail(DioExceptionType.cancel)
      ..fail(DioExceptionType.receiveTimeout);
    final api = testClient(adapter);
    final t = await _error(api.get<Object?>(Endpoints.services));
    expect(t.kind, ApiErrorKind.timeout);
    expect(t.status, 0);
    expect(t.isNetwork, isTrue);
    expect(t.cause, isA<DioException>());
    final n = await _error(api.get<Object?>(Endpoints.services));
    expect(n.kind, ApiErrorKind.network);
    expect(n.message, "Internet aloqasi yo'q. Qayta urinib ko'ring.");
    final c = await _error(api.get<Object?>(Endpoints.services));
    expect(c.isCancelled, isTrue);
    expect(c.message, "So'rov bekor qilindi.");
    final r = await _error(api.get<Object?>(Endpoints.services));
    expect(r.kind, ApiErrorKind.timeout);
    expect(r.message, "Server javob bermadi. Qayta urinib ko'ring.");
  });

  test('18. idempotency header and JSON body', () async {
    adapter.reply(201, '{"data":{"id":1}}');
    final api = testClient(adapter);
    final body = {
      'staff_id': 2,
      'service_id': 11,
      'starts_at': '2026-10-18 05:00:00',
      'notes': "Soqolni qisqa qiling",
    };
    await api.post<Object?>(Endpoints.consumerAppointments, body: body, idempotencyKey: 'k1');
    final r = adapter.requests.single;
    expect(r.headers['idempotency-key'], 'k1');
    expect(r.headers['content-type'], startsWith('application/json'));
    expect(r.json, body);
  });

  test('19. replay vs created', () async {
    adapter.reply(200, '{"data":{"id":1}}');
    adapter.reply(201, '{"data":{"id":1}}');
    final api = testClient(adapter);
    final replay = await api.request<Object?>('POST', Endpoints.consumerOrders, body: {}, idempotencyKey: 'k');
    expect(replay.isReplay, isTrue);
    expect(replay.isCreated, isFalse);
    final created = await api.request<Appointment>(
      'POST',
      Endpoints.consumerAppointments,
      body: {},
      idempotencyKey: 'k',
      decode: (d) => Appointment.fromJson(JsonRead.object(d)),
    );
    expect(created.isCreated, isTrue);
    expect(created.data.id, 1);
  });

  test('20. query encoding', () async {
    adapter.reply(200, '{"data":[]}');
    final api = testClient(adapter);
    await api.get<Object?>('/v1/q', query: {
      'a': null,
      'b': true,
      'c': const LocalDate(2026, 10, 17),
      'd': DateTime.utc(2026, 10, 17, 5),
      'e': AppointmentStatus.noShow,
      'f': 3,
    });
    final uri = adapter.requests.single.uri;
    expect(uri.query, 'b=1&c=2026-10-17&d=2026-10-17+05%3A00%3A00&e=no_show&f=3');
    expect(uri.queryParameters['d'], '2026-10-17 05:00:00');
    expect(uri.queryParameters.containsKey('a'), isFalse);
  });

  test('21. only CORS-safe headers are sent', () async {
    // content-length is set by dio itself (a browser-controlled header that never triggers a
    // CORS preflight); everything else must be in the allowed set.
    const allowed = {'accept', 'content-type', 'authorization', 'idempotency-key', 'content-length'};
    for (var i = 0; i < 4; i++) {
      adapter.reply(200, '{"data":{"url":"https://x/y.jpg"}}');
    }
    final api = testClient(adapter, store: InMemoryTokenStore(bizToken()));
    await api.get<Object?>(Endpoints.authMe, query: {'a': 1});
    await api.post<Object?>(Endpoints.appointments, body: {'a': 1}, idempotencyKey: Idempotency.newKey());
    await api.patch<Object?>(Endpoints.appointment(1), body: {'status': 'arrived'});
    await api.uploadImage([1, 2, 3], filename: 'a.png', contentType: 'image/png');
    for (final r in adapter.requests) {
      expect(allowed.containsAll(r.headers.keys), isTrue, reason: '${r.method} ${r.headers.keys}');
      expect(r.headers.containsKey('user-agent'), isFalse);
    }
  });

  test('22. uploadImage multipart', () async {
    adapter.reply(201, '{"data":{"url":"https://api.tizbiz.uz/uploads/202610/x.jpg"}}');
    final api = testClient(adapter, store: InMemoryTokenStore(bizToken()));
    final url = await api.uploadImage([0xFF, 0xD8, 0xFF], filename: 'a.jpg', contentType: 'image/jpeg');
    expect(url, 'https://api.tizbiz.uz/uploads/202610/x.jpg');
    final r = adapter.requests.single;
    expect(r.uri.path, '/v1/uploads');
    expect(r.headers['content-type'], startsWith('multipart/form-data'));
    expect(r.headers['authorization'], startsWith('Bearer '));
    expect(r.body, contains('name="file"'));
    expect(r.body, contains('filename="a.jpg"'));
    expect(r.body.toLowerCase(), contains('content-type: image/jpeg'));
    expect(() => api.uploadImage([1], filename: 'a.bin', contentType: 'application/octet-stream'), throwsArgumentError);
  });

  test('23. log sink gets one line without token or body', () async {
    final lines = <String>[];
    final token = bizToken();
    adapter.reply(200, '{"data":{"secret":"s3cr3t"}}');
    adapter.reply(422, error422PointersJson);
    final api = testClient(adapter, store: InMemoryTokenStore(token), log: lines.add);
    await api.get<Object?>(Endpoints.meStats, query: {'from': '2026-10-01'});
    await _error(api.post<Object?>(Endpoints.login, body: {'password': 'hunter2'}, auth: RequestAuth.none));
    expect(lines, hasLength(2));
    expect(lines[0], matches(RegExp(r'^GET /v1/me/stats -> 200 \(\d+ ms\)$')));
    expect(lines[1], matches(RegExp(r'^POST /v1/auth/login -> 422 \(\d+ ms\)$')));
    for (final l in lines) {
      expect(l, isNot(contains(token)));
      expect(l, isNot(contains('s3cr3t')));
      expect(l, isNot(contains('hunter2')));
      expect(l, isNot(contains('2026-10-01')));
    }
  });

  test('decode failure on 2xx -> ApiErrorKind.decode', () async {
    adapter.reply(200, 'not json');
    adapter.reply(200, '{"data":"x"}');
    final api = testClient(adapter);
    final a = await _error(api.get<Object?>(Endpoints.services));
    expect(a.kind, ApiErrorKind.decode);
    expect(a.message, "Serverdan noto'g'ri javob keldi.");
    final b = await _error(api.get<Service>(Endpoints.service(1), decode: (d) => Service.fromJson(JsonRead.object(d))));
    expect(b.kind, ApiErrorKind.decode);
  });

  test('envelope-less 2xx body is passed whole', () async {
    adapter.reply(200, '{"ok":true}');
    final api = testClient(adapter);
    expect(await api.get<Map<String, dynamic>>('/v1/x'), {'ok': true});
  });

  test('injected Dio options are overwritten', () async {
    final dio = Dio(BaseOptions(responseType: ResponseType.json, validateStatus: (s) => s == 200))
      ..httpClientAdapter = adapter;
    final api = ApiClient(
      config: const ApiConfig(baseUrl: 'https://api.test', receiveTimeout: Duration(seconds: 3)),
      tokenKind: TokenKind.biz,
      dio: dio,
    );
    expect(dio.options.responseType, ResponseType.plain);
    expect(dio.options.validateStatus(500), isTrue);
    expect(dio.options.receiveTimeout, const Duration(seconds: 3));
    adapter.reply(404, '{"errors":[{"status":"404","title":"Not Found","detail":"Biznes topilmadi."}]}');
    final e = await _error(api.get<Object?>(Endpoints.site('nope')));
    expect(e.isNotFound, isTrue);
    expect(e.message, 'Biznes topilmadi.');
  });

  test('clearToken emits and Paged helpers', () async {
    final api = testClient(adapter);
    final events = <String?>[];
    final sub = api.tokenChanges.listen(events.add);
    final t = bizToken();
    await api.setToken(t);
    await api.setToken(null);
    await Future<void>.delayed(Duration.zero);
    expect(events, [t, null]);
    await sub.cancel();

    const a = Paged<int>(items: [1, 2], meta: PageMeta(page: 1, perPage: 2, total: 3, pages: 2));
    const b = Paged<int>(items: [3], meta: PageMeta(page: 2, perPage: 2, total: 3, pages: 2));
    expect(a.hasMore, isTrue);
    expect(a.meta.nextPage, 2);
    final all = a.append(b);
    expect(all.items, [1, 2, 3]);
    expect(all.hasMore, isFalse);
    expect(all.map((i) => '$i').items, ['1', '2', '3']);
    expect(PageMeta.fromJson(metaMap(directoryReviewsJson)).toJson()['avg'], 4.73);
    api.close();
  });
}

Future<ApiException> _error(Future<Object?> f) async {
  try {
    await f;
  } on ApiException catch (e) {
    return e;
  }
  throw StateError('expected an ApiException');
}
