import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart' as pc;
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
    // Use pointycastle for reliable EC P-256 key generation on all platforms
    final secureRandom = pc.FortunaRandom();
    final rng = math.Random.secure();
    secureRandom.seed(
      pc.KeyParameter(
        Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256))),
      ),
    );

    final keyGen = pc.ECKeyGenerator()
      ..init(
        pc.ParametersWithRandom(
          pc.ECKeyGeneratorParameters(pc.ECCurve_prime256v1()),
          secureRandom,
        ),
      );

    final keyPair = keyGen.generateKeyPair();
    final priv = keyPair.privateKey as pc.ECPrivateKey;
    final pub = keyPair.publicKey as pc.ECPublicKey;

    // Build DER manually for P-256 — avoids toDer() which is unimplemented
    final privateKeyDer = _buildPkcs8EcP256(priv.d!);
    final publicKeyDer = _buildSpkiEcP256(
      pub.Q!.x!.toBigInteger()!,
      pub.Q!.y!.toBigInteger()!,
    );

    final privateKeyPem = _encodePemBlock(
      label: 'PRIVATE KEY',
      derBytes: privateKeyDer,
    );
    final publicKeyPem = _encodePemBlock(
      label: 'PUBLIC KEY',
      derBytes: publicKeyDer,
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

  /// Signs [payload] with EC P-256 private key using SHA-256/ECDSA.
  /// Returns base64-encoded DER ECDSA signature compatible with Java's SHA256withECDSA.
  String signPayload({
    required String payload,
    required String privateKeyPem,
  }) {
    // Extract raw d bytes from our fixed PKCS#8 P-256 structure (d is at offset 35, 32 bytes)
    final base64Str = privateKeyPem
        .replaceAll('-----BEGIN PRIVATE KEY-----', '')
        .replaceAll('-----END PRIVATE KEY-----', '')
        .replaceAll('\n', '');
    final der = base64Decode(base64Str);
    final d = _bytesToBigInt(der.sublist(35, 67));

    final ecParams = pc.ECCurve_prime256v1();
    final privateKey = pc.ECPrivateKey(d, ecParams);

    final secureRandom = pc.FortunaRandom();
    final rng = math.Random.secure();
    secureRandom.seed(
      pc.KeyParameter(
        Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256))),
      ),
    );

    final signer = pc.Signer('SHA-256/ECDSA') as pc.ECDSASigner;
    signer.init(
      true,
      pc.ParametersWithRandom(
        pc.PrivateKeyParameter<pc.ECPrivateKey>(privateKey),
        secureRandom,
      ),
    );

    final sig = signer.generateSignature(
      Uint8List.fromList(utf8.encode(payload)),
    ) as pc.ECSignature;

    return base64Encode(_derEncodeEcdsaSig(sig.r, sig.s));
  }

  static BigInt _bytesToBigInt(List<int> bytes) =>
      bytes.fold(BigInt.zero, (acc, b) => (acc << 8) | BigInt.from(b));

  static List<int> _derEncodeEcdsaSig(BigInt r, BigInt s) {
    final rb = _derEncodeInt(r);
    final sb = _derEncodeInt(s);
    return <int>[0x30, rb.length + sb.length, ...rb, ...sb];
  }

  static List<int> _derEncodeInt(BigInt value) {
    final bytes = _bigIntFixed(value, 32);
    int start = 0;
    while (start < bytes.length - 1 && bytes[start] == 0) {
      start++;
    }
    final trimmed = bytes.sublist(start);
    if (trimmed[0] & 0x80 != 0) {
      return <int>[0x02, trimmed.length + 1, 0x00, ...trimmed];
    }
    return <int>[0x02, trimmed.length, ...trimmed];
  }

  static Map<String, dynamic> _publicJwkFromPrivateKey(ECPrivateKey key) {
    final jwk = Map<String, dynamic>.from(key.toJWK());
    jwk.remove('d');
    return jwk;
  }

  /// PKCS#8 DER encoding for EC P-256 private key.
  /// Structure: SEQUENCE { version, AlgorithmIdentifier, OCTET STRING { ECPrivateKey } }
  static List<int> _buildPkcs8EcP256(BigInt d) {
    final dBytes = _bigIntFixed(d, 32);
    return [
      0x30, 0x41, // SEQUENCE, 65 bytes total
      0x02, 0x01, 0x00, // INTEGER 0 (version)
      0x30, 0x13, // AlgorithmIdentifier SEQUENCE, 19 bytes
      0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, // OID id-ecPublicKey
      0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, // OID prime256v1
      0x04, 0x27, // OCTET STRING, 39 bytes
      0x30, 0x25, // ECPrivateKey SEQUENCE, 37 bytes
      0x02, 0x01, 0x01, // INTEGER 1 (version)
      0x04, 0x20, // OCTET STRING, 32 bytes (d)
      ...dBytes,
    ];
  }

  /// SubjectPublicKeyInfo DER encoding for EC P-256 public key.
  /// Structure: SEQUENCE { AlgorithmIdentifier, BIT STRING { 04 || x || y } }
  static List<int> _buildSpkiEcP256(BigInt x, BigInt y) {
    return [
      0x30, 0x59, // SEQUENCE, 89 bytes total
      0x30, 0x13, // AlgorithmIdentifier SEQUENCE, 19 bytes
      0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, // OID id-ecPublicKey
      0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, // OID prime256v1
      0x03, 0x42, 0x00, 0x04, // BIT STRING, 66 bytes, 0 unused bits, uncompressed point
      ..._bigIntFixed(x, 32),
      ..._bigIntFixed(y, 32),
    ];
  }

  /// Encodes a BigInt as a fixed-length big-endian byte array.
  static Uint8List _bigIntFixed(BigInt value, int length) {
    final result = Uint8List(length);
    var v = value;
    for (var i = length - 1; i >= 0; i--) {
      result[i] = (v & BigInt.from(0xff)).toInt();
      v = v >> 8;
    }
    return result;
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
