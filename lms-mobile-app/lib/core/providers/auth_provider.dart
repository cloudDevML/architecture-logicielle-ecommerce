import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../services/auth_service.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.initial;
  String? _token;
  String? _username;
  String? _role;
  String? _firstName;
  String? _lastName;
  String? _errorMessage;

  AuthStatus get status      => _status;
  String?    get token       => _token;
  String?    get username    => _username;
  String?    get role        => _role;
  String?    get firstName   => _firstName;
  String?    get lastName    => _lastName;
  String?    get errorMessage => _errorMessage;

  String? get fullName {
    if (_firstName == null && _lastName == null) {
      return _username;
    }
    final name = '${_firstName ?? ""} ${_lastName ?? ""}'.trim();
    return name.isNotEmpty ? name : _username;
  }

  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isStudent       => _role == 'STUDENT';
  bool get isLecturer      => _role == 'LECTURER' || _role == 'TEACHER';
  bool get isAdmin         => _role == 'ADMIN';

  // ── Initialisation (vérifier token stocké) ────────────────────────────────
  Future<void> checkAuth() async {
    _status = AuthStatus.loading;
    notifyListeners();

    final hasCredentials = await _authService.hasStoredCredentials();
    if (hasCredentials) {
      final user = await _authService.getStoredUser();
      _token     = user['token'];
      _username  = user['username'];
      _role      = user['role'];
      _firstName = user['firstName'];
      _lastName  = user['lastName'];
      _status    = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // ── Login classique ────────────────────────────────────────────────────────
  Future<bool> login(String username, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.login(username, password);
      _token     = result['token'];
      _username  = result['username'] ?? username;
      _role      = result['role'];
      _firstName = result['firstName'];
      _lastName  = result['lastName'];
      _status    = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  // ── Login biométrique ──────────────────────────────────────────────────────
  Future<bool> loginWithBiometrics() async {
    final hasCredentials = await _authService.hasStoredCredentials();
    if (!hasCredentials) {
      _errorMessage = 'Aucune session sauvegardée. Connectez-vous d\'abord.';
      notifyListeners();
      return false;
    }

    final authenticated = await _authService.authenticateWithBiometrics();
    if (authenticated) {
      final user = await _authService.getStoredUser();
      _token     = user['token'];
      _username  = user['username'];
      _role      = user['role'];
      _firstName = user['firstName'];
      _lastName  = user['lastName'];
      _status    = AuthStatus.authenticated;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> isBiometricAvailable() => _authService.isBiometricAvailable();

  // ── Déconnexion ────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _authService.logout();
    _token = _username = _role = _firstName = _lastName = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  String _parseError(dynamic e) {
    String msg = e.toString();
    
    // Extract JSON error payload if this is a DioException
    if (e is DioException) {
      final responseData = e.response?.data;
      if (responseData != null) {
        msg += " " + responseData.toString();
      }
    }

    if (msg.contains('not fully set up') || msg.contains('fully set up')) {
      return "Première connexion : Veuillez d'abord vous connecter sur le site web (lms-ept.duckdns.org) pour personnaliser votre mot de passe temporaire avant d'utiliser le mobile.";
    }
    if (msg.contains('401')) return 'Identifiants incorrects.';
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Impossible de joindre le serveur. Vérifiez votre connexion.';
    }
    return 'Une erreur est survenue. Réessayez.';
  }
}
