import 'dart:convert' show base64Url, jsonDecode, utf8;

import 'package:meta/meta.dart';

import '../util/json_read.dart';

/// Which app a token belongs to (claim `typ`).
enum TokenKind { biz, consumer, unknown }

/// Decoded JWT claims (decode only, no verification: the server checks the signature).
@immutable
final class JwtClaims {
  const JwtClaims({
    required this.sub,
    this.tenantId,
    this.role,
    required this.kind,
    required this.typ,
    this.issuedAt,
    this.expiresAt,
    this.issuer,
  });

  /// Base64url-decodes the payload (segment 2, padding restored). No signature check (the server
  /// does it). Returns null for anything that is not 3 dot-separated segments with a JSON object
  /// payload.
  static JwtClaims? tryParse(String? token) {
    if (token == null) return null;
    final parts = token.trim().split('.');
    if (parts.length != 3 || parts[1].isEmpty) return null;
    final Object? payload;
    try {
      payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    } on FormatException {
      return null;
    }
    final json = JsonRead.objectOrNull(payload);
    if (json == null) return null;
    final rawTyp = JsonRead.string(json['typ']).trim();
    final typ = rawTyp.isEmpty ? 'biz' : rawTyp;
    return JwtClaims(
      sub: JsonRead.integer(json['sub']),
      tenantId: JsonRead.integerOrNull(json['tid']),
      role: JsonRead.nonEmptyOrNull(json['role']),
      typ: typ,
      kind: switch (typ) {
        'biz' => TokenKind.biz,
        'consumer' => TokenKind.consumer,
        _ => TokenKind.unknown,
      },
      issuedAt: JsonRead.unix(json['iat']),
      expiresAt: JsonRead.unix(json['exp']),
      issuer: JsonRead.stringOrNull(json['iss']),
    );
  }

  /// Claim sub (users.id or consumer_users.id).
  final int sub;

  /// Claim tid.
  final int? tenantId;

  /// Claim role.
  final String? role;

  /// Claim typ; '' -> 'biz' (legacy tokens have no typ).
  final String typ;

  /// 'biz' -> biz, 'consumer' -> consumer, other -> unknown.
  final TokenKind kind;

  /// iat (unix, UTC).
  final DateTime? issuedAt;

  /// exp (unix, UTC).
  final DateTime? expiresAt;

  /// iss.
  final String? issuer;

  /// exp <= now + leeway. A token without exp is not considered expired.
  bool isExpired(DateTime now, {Duration leeway = const Duration(seconds: 30)}) {
    final exp = expiresAt;
    if (exp == null) return false;
    return !exp.isAfter(now.add(leeway));
  }
}
