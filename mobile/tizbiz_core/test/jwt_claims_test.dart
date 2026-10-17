import 'dart:convert';

import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import 'support/fake_adapter.dart';

void main() {
  test('live business token without typ is biz', () {
    final token = makeToken(
        {'iss': 'tizbiz.uz', 'iat': 1792187436, 'exp': 1792792236, 'sub': 4, 'tid': 2, 'role': 'business_owner'});
    final c = JwtClaims.tryParse(token)!;
    expect(c.kind, TokenKind.biz);
    expect(c.typ, 'biz');
    expect(c.sub, 4);
    expect(c.tenantId, 2);
    expect(c.role, 'business_owner');
    expect(c.issuer, 'tizbiz.uz');
    expect(c.issuedAt, DateTime.fromMillisecondsSinceEpoch(1792187436000, isUtc: true));
    expect(c.expiresAt, DateTime.fromMillisecondsSinceEpoch(1792792236000, isUtc: true));
  });

  test('typ consumer / other', () {
    expect(JwtClaims.tryParse(makeToken({'sub': 17, 'typ': 'consumer'}))!.kind, TokenKind.consumer);
    expect(JwtClaims.tryParse(makeToken({'sub': 1, 'typ': 'x'}))!.kind, TokenKind.unknown);
  });

  test('malformed tokens -> null', () {
    expect(JwtClaims.tryParse('abc'), isNull);
    expect(JwtClaims.tryParse('a.b'), isNull);
    expect(JwtClaims.tryParse('a.!!!.c'), isNull);
    expect(JwtClaims.tryParse(null), isNull);
    final notObject = '${base64Url.encode(utf8.encode('{}'))}.${base64Url.encode(utf8.encode('[1]'))}.s';
    expect(JwtClaims.tryParse(notObject), isNull);
  });

  test('payload without base64 padding parses', () {
    // {"sub":5} encodes to 'eyJzdWIiOjV9' (no padding needed); {"sub":55} needs '='.
    final payload = base64Url.encode(utf8.encode('{"sub":55}'));
    expect(payload.endsWith('='), isTrue);
    final token = 'x.${payload.replaceAll('=', '')}.y';
    expect(JwtClaims.tryParse(token)!.sub, 55);
  });

  test('isExpired with leeway', () {
    final c = JwtClaims.tryParse(makeToken({'sub': 1, 'exp': 1792792236}))!;
    final exp = c.expiresAt!;
    expect(c.isExpired(exp.subtract(const Duration(seconds: 10))), isTrue);
    expect(c.isExpired(exp.subtract(const Duration(seconds: 60))), isFalse);
    expect(JwtClaims.tryParse(makeToken({'sub': 1}))!.isExpired(DateTime.utc(2100)), isFalse);
  });
}
