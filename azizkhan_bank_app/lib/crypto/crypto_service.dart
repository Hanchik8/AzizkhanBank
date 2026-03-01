import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class GeneratedKeyPair {
  GeneratedKeyPair({required this.publicKeyPem, required this.privateKeyPem});

  final String publicKeyPem;
  final String privateKeyPem;
}

class CryptoService {
  CryptoService({FlutterSecureStorage? secureStorage, Uuid? uuid})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
      _uuid = uuid ?? const Uuid();

  static const String privateKeyStorageKey = 'device_private_key_pem';
  static const String publicKeyStorageKey = 'device_public_key_pem';

  final FlutterSecureStorage _secureStorage;
  final Uuid _uuid;

  Future<GeneratedKeyPair> generateKeyPair() async {
    final ecdsa = Ecdsa.p256(Sha256());
    final keyPair = await ecdsa.newKeyPair();
    final keyPairData = await keyPair.extract();
    final publicKey = await keyPair.extractPublicKey();

    final privateKeyPem = _encodePemBlock(
      label: 'PRIVATE KEY',
      derBytes: keyPairData.toDer(),
    );
    final publicKeyPem = _encodePemBlock(
      label: 'PUBLIC KEY',
      derBytes: publicKey.toDer(),
    );

    return GeneratedKeyPair(
      publicKeyPem: publicKeyPem,
      privateKeyPem: privateKeyPem,
    );
  }

  Future<String> exportPublicKeyPem() async {
    final pem = await _secureStorage.read(key: publicKeyStorageKey);
    if (pem == null || pem.isEmpty) {
      throw StateError('Public key is not found in secure storage');
    }
    return pem;
  }

  Future<void> savePrivateKey(String privateKeyPem) {
    return _secureStorage.write(
      key: privateKeyStorageKey,
      value: privateKeyPem,
    );
  }

  Future<void> savePublicKey(String publicKeyPem) {
    return _secureStorage.write(key: publicKeyStorageKey, value: publicKeyPem);
  }

  Future<String?> loadPrivateKey() {
    return _secureStorage.read(key: privateKeyStorageKey);
  }

  String generateDpopProofToken({
    required String httpMethod,
    required String requestUrl,
    required String privateKeyPem,
  }) {
    final key = ECPrivateKey(privateKeyPem);
    final nowInSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

    final jwt = JWT(
      <String, dynamic>{
        'htm': httpMethod.toUpperCase(),
        'htu': requestUrl,
        'jti': _uuid.v4(),
        'iat': nowInSeconds,
      },
      header: <String, dynamic>{
        'typ': 'dpop+jwt',
        'alg': 'ES256',
        'jwk': _publicJwkFromPrivateKey(key),
      },
    );

    return jwt.sign(key, algorithm: JWTAlgorithm.ES256, noIssueAt: true);
  }

  static Map<String, dynamic> _publicJwkFromPrivateKey(ECPrivateKey key) {
    final jwk = Map<String, dynamic>.from(key.toJWK());
    jwk.remove('d');
    return jwk;
  }

  static String _encodePemBlock({
    required String label,
    required List<int> derBytes,
  }) {
    final base64Body = base64Encode(derBytes);
    final chunks = <String>[];
    for (var i = 0; i < base64Body.length; i += 64) {
      final end = (i + 64 < base64Body.length) ? i + 64 : base64Body.length;
      chunks.add(base64Body.substring(i, end));
    }

    return '-----BEGIN $label-----\n'
        '${chunks.join('\n')}\n'
        '-----END $label-----';
  }
}
