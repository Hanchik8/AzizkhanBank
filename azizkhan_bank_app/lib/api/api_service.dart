import 'dart:convert';

import 'package:azizkhan_bank_app/crypto/crypto_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokens {
  AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

class ApiService {
  ApiService._(this._dio, this._secureStorage, this._cryptoService) {
    _dio.options.baseUrl = baseUrl;
    _dio.interceptors.add(
      DpopAuthInterceptor(
        secureStorage: _secureStorage,
        cryptoService: _cryptoService,
      ),
    );
  }

  factory ApiService({
    Dio? dio,
    FlutterSecureStorage? secureStorage,
    CryptoService? cryptoService,
  }) {
    final storage = secureStorage ?? const FlutterSecureStorage();
    final crypto = cryptoService ?? CryptoService(secureStorage: storage);
    final client = dio ?? Dio(BaseOptions(baseUrl: baseUrl));

    return ApiService._(client, storage, crypto);
  }

  static const String baseUrl = 'http://192.168.1.31:8080';
  static const String accessTokenStorageKey = 'accessToken';
  static const String refreshTokenStorageKey = 'refreshToken';
  static const String deviceIdStorageKey = 'deviceId';

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  final CryptoService _cryptoService;

  Future<Response<Map<String, dynamic>>> sendOtp(String phone) {
    return _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/send-otp',
      data: <String, dynamic>{'phoneNumber': phone},
    );
  }

  Future<String> verifyOtp(String phone, String code) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/verify-otp',
      data: <String, dynamic>{'phoneNumber': phone, 'code': code},
    );

    final data = response.data ?? <String, dynamic>{};
    final registrationToken = _readFirstString(data, <String>[
      'registrationToken',
      'token',
      'jwt',
    ]);
    if (registrationToken == null || registrationToken.isEmpty) {
      throw StateError(
        'Registration token is missing in /api/v1/auth/verify-otp response',
      );
    }

    return registrationToken;
  }

  Future<AuthTokens> bindDevice({
    required String registrationToken,
    required String deviceId,
    required String publicKey,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/device/bind',
      data: <String, dynamic>{'deviceId': deviceId, 'publicKey': publicKey},
      options: Options(
        headers: <String, dynamic>{
          'Authorization': 'Bearer $registrationToken',
        },
      ),
    );

    final data = response.data ?? <String, dynamic>{};
    final accessToken = _readFirstString(data, <String>[
      'accessToken',
      'access_token',
    ]);
    final refreshToken = _readFirstString(data, <String>[
      'refreshToken',
      'refresh_token',
    ]);

    if (accessToken == null || accessToken.isEmpty) {
      throw StateError(
        'accessToken is missing in /api/v1/auth/device/bind response',
      );
    }
    if (refreshToken == null || refreshToken.isEmpty) {
      throw StateError(
        'refreshToken is missing in /api/v1/auth/device/bind response',
      );
    }

    return AuthTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<void> saveAuthTokens(AuthTokens tokens) async {
    await _secureStorage.write(
      key: accessTokenStorageKey,
      value: tokens.accessToken,
    );
    await _secureStorage.write(
      key: refreshTokenStorageKey,
      value: tokens.refreshToken,
    );
  }

  Future<Map<String, dynamic>> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required num amount,
    required String currency,
    required String idempotencyKey,
  }) async {
    final deviceId = await _secureStorage.read(key: ApiService.deviceIdStorageKey) ?? '';
    final privateKeyPem = await _secureStorage.read(key: CryptoService.privateKeyStorageKey) ?? '';
    final timestamp = DateTime.now().toUtc().toIso8601String();

    final bodyMap = <String, dynamic>{
      'fromAccountId': int.parse(fromAccountId),
      'toAccountId': int.parse(toAccountId),
      'amount': amount,
      'currency': currency,
    };
    final bodyJson = jsonEncode(bodyMap);
    final signature = _cryptoService.signPayload(
      payload: timestamp + bodyJson,
      privateKeyPem: privateKeyPem,
    );

    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/transfers',
      data: bodyJson,
      options: Options(
        contentType: 'application/json',
        headers: <String, dynamic>{
          'Idempotency-Key': idempotencyKey,
          'X-Device-Id': deviceId,
          'X-Timestamp': timestamp,
          'X-Signature': signature,
        },
      ),
    );

    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> getAccounts() async {
    final response = await _dio.get<dynamic>('/api/v1/accounts');
    final data = response.data;
    if (data is List<dynamic>) {
      return data;
    }
    return <dynamic>[];
  }

  Future<List<dynamic>> getAccountHistory(int accountId) async {
    final response = await _dio.get<dynamic>(
      '/api/v1/accounts/$accountId/history',
    );
    final data = response.data;
    if (data is List<dynamic>) {
      return data;
    }
    return <dynamic>[];
  }

  String? _readFirstString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
      if (value != null) {
        final asString = value.toString();
        if (asString.isNotEmpty) {
          return asString;
        }
      }
    }
    return null;
  }
}

class DpopAuthInterceptor extends Interceptor {
  DpopAuthInterceptor({
    required FlutterSecureStorage secureStorage,
    required CryptoService cryptoService,
  }) : _secureStorage = secureStorage,
       _cryptoService = cryptoService;

  final FlutterSecureStorage _secureStorage;
  final CryptoService _cryptoService;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isProtectedPath(options.uri.path)) {
      handler.next(options);
      return;
    }

    final accessToken = await _secureStorage.read(
      key: ApiService.accessTokenStorageKey,
    );
    if (accessToken == null || accessToken.isEmpty) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: StateError('Access token not found in flutter_secure_storage'),
          type: DioExceptionType.unknown,
        ),
      );
      return;
    }

    final privateKeyPem = await _secureStorage.read(
      key: CryptoService.privateKeyStorageKey,
    );
    if (privateKeyPem == null || privateKeyPem.isEmpty) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: StateError('Private key not found in flutter_secure_storage'),
          type: DioExceptionType.unknown,
        ),
      );
      return;
    }

    final proofToken = _cryptoService.generateDpopProofToken(
      httpMethod: options.method,
      requestUrl: options.uri.toString(),
      privateKeyPem: privateKeyPem,
    );

    options.headers['Authorization'] = 'Bearer $accessToken';
    options.headers['DPoP'] = proofToken;

    handler.next(options);
  }

  bool _isProtectedPath(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return normalized.startsWith('/api/v1/transfers') ||
        normalized.startsWith('/api/v1/accounts');
  }
}
