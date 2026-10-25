import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../constants/api_constants.dart';
import 'network_interceptor.dart';
import 'outbox_interceptor.dart';


class AuthService {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  static const String _tokenKey     = 'jwt_token';
  static const String _refreshKey   = 'refresh_token';
  static const String _usernameKey  = 'username';
  static const String _roleKey      = 'role';
  static const String _firstNameKey = 'first_name';
  static const String _lastNameKey  = 'last_name';

  AuthService()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeoutMs),
          receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeoutMs),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        )),
      _storage = const FlutterSecureStorage(),
      _localAuth = LocalAuthentication();

  // Helper pour décoder un token JWT en pur Dart sans dépendance tierce
  Map<String, dynamic> _parseJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        throw Exception('Invalid token structure');
      }
      final payload = parts[1];
      var normalized = base64Url.normalize(payload);
      var resp = utf8.decode(base64Url.decode(normalized));
      return json.decode(resp);
    } catch (e) {
      print('AUTH: Error parsing JWT: $e');
      return {};
    }
  }

  // ── Login classique ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String username, String password) async {
    print('AUTH: Attempting Keycloak login for $username');
    try {
      final response = await _dio.post(
        ApiConstants.keycloakToken,
        data: {
          'client_id': 'lms-web',
          'grant_type': 'password',
          'username': username,
          'password': password,
          'scope': 'openid offline_access',
        },
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
        ),
      );
      print('AUTH: Login success for $username');

      final data = response.data;
      final token = data['access_token'] as String? ?? '';
      final refreshToken = data['refresh_token'] as String? ?? '';
      
      // Décoder le token d'accès Keycloak pour extraire les informations utilisateur
      final payload = _parseJwt(token);
      
      // Extraction et mapping des rôles realm
      final realmRoles = payload['realm_access']?['roles'] as List? ?? [];
      String role = 'STUDENT';
      if (realmRoles.contains('admin')) {
        role = 'ADMIN';
      } else if (realmRoles.contains('lecturer')) {
        role = 'LECTURER';
      } else if (realmRoles.contains('student')) {
        role = 'STUDENT';
      }

      final realUsername = payload['preferred_username'] as String? ?? username;
      
      // Extraire prénom et nom de famille
      final givenName = payload['given_name'] as String? ?? '';
      final familyName = payload['family_name'] as String? ?? '';

      // Stocker de façon sécurisée
      await _storage.write(key: _tokenKey,     value: token);
      await _storage.write(key: _refreshKey,   value: refreshToken);
      await _storage.write(key: _usernameKey,  value: realUsername);
      await _storage.write(key: _roleKey,      value: role);
      await _storage.write(key: _firstNameKey, value: givenName);
      await _storage.write(key: _lastNameKey,  value: familyName);

      return {
        'token': token, 
        'role': role, 
        'firstName': givenName, 
        'lastName': familyName, 
        'username': realUsername
      };
    } catch (e) {
      if (e is DioException) {
        print('AUTH: Login error status=${e.response?.statusCode}, data=${e.response?.data}');
      } else {
        print('AUTH: Unexpected login error: $e');
      }
      rethrow;
    }
  }

  // ── Auth biométrique ───────────────────────────────────────────────────────
  Future<bool> isBiometricAvailable() async {
    final canCheck   = await _localAuth.canCheckBiometrics;
    final isSupported = await _localAuth.isDeviceSupported();
    return canCheck && isSupported;
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Identifiez-vous pour accéder au LMS EPT',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Vérifie si un token existe déjà (pour auto-login biométrique)
  Future<bool> hasStoredCredentials() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<void> saveTokens(String token, String refreshToken) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  // ── Récupérer les infos stockées ──────────────────────────────────────────
  Future<String?> getToken()        => _storage.read(key: _tokenKey);
  Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);
  Future<String?> getUsername()     => _storage.read(key: _usernameKey);
  Future<String?> getRole()         => _storage.read(key: _roleKey);
  Future<String?> getFirstName()    => _storage.read(key: _firstNameKey);
  Future<String?> getLastName()     => _storage.read(key: _lastNameKey);

  Future<Map<String, String?>> getStoredUser() async {
    return {
      'token':     await getToken(),
      'username':  await getUsername(),
      'role':      await getRole(),
      'firstName': await getFirstName(),
      'lastName':  await getLastName(),
    };
  }

  Future<Map<String, String?>> getUserProfile() => getStoredUser();

  Future<Map<String, dynamic>> getStudentProfile(String username) async {
    final dio = await getAuthenticatedDio();
    final response = await dio.get('${ApiConstants.studentDetails}/$username/username');
    return response.data;
  }

  // ── Déconnexion ────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _storage.deleteAll();
  }

  // ── Dio avec Authorization header ─────────────────────────────────────────
  Future<Dio> getAuthenticatedDio() async {
    final token = await getToken();
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeoutMs),
      receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeoutMs),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ));
    dio.interceptors.add(OutboxInterceptor());
    dio.interceptors.add(NetworkInterceptor());
    return dio;
  }
}

