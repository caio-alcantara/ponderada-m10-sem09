import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ─── Backend origin (configurável) ─────────────────────────────────────────

  static const String _originPrefKey = 'backend_origin';

  /// Origin padrão por plataforma (sem o sufixo `/api/v1`).
  static String get defaultOrigin =>
      kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';

  /// Cache em memória do origin salvo, para manter [baseUrl] síncrono.
  static String? _cachedOrigin;

  /// Carrega o origin salvo a partir do disco. Chame uma vez no startup.
  static Future<void> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedOrigin = prefs.getString(_originPrefKey);
  }

  /// Origin atualmente em uso (customizado ou o padrão da plataforma).
  static String get currentOrigin =>
      (_cachedOrigin != null && _cachedOrigin!.isNotEmpty)
          ? _cachedOrigin!
          : defaultOrigin;

  /// `true` quando há um origin customizado salvo.
  static bool get isUsingCustomOrigin =>
      _cachedOrigin != null && _cachedOrigin!.isNotEmpty;

  /// Define um origin customizado (ex.: `http://192.168.0.10:8000`).
  /// Normaliza o valor e persiste em disco.
  static Future<void> setBackendOrigin(String origin) async {
    var normalized = origin.trim();
    // Remove barras finais e um eventual sufixo `/api/v1` digitado a mais.
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (normalized.endsWith('/api/v1')) {
      normalized = normalized.substring(0, normalized.length - '/api/v1'.length);
    }
    // Adiciona esquema http:// caso o usuário não tenha informado.
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'http://$normalized';
    }
    _cachedOrigin = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_originPrefKey, normalized);
  }

  /// Remove o origin customizado, voltando ao padrão da plataforma.
  static Future<void> clearBackendOrigin() async {
    _cachedOrigin = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_originPrefKey);
  }

  static String get baseUrl => '$currentOrigin/api/v1';

  // ─── Token storage ────────────────────────────────────────────────────────

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user['id'] ?? '');
    await prefs.setString('user_name', user['name'] ?? '');
    await prefs.setString('user_email', user['email'] ?? '');
  }

  static Future<Map<String, String>> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'id': prefs.getString('user_id') ?? '',
      'name': prefs.getString('user_name') ?? '',
      'email': prefs.getString('user_email') ?? '',
    };
  }

  // ─── Headers ──────────────────────────────────────────────────────────────

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) {
      await saveTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
      );
      await saveUser(data['user']);
      return data;
    }
    throw ApiException(res.statusCode, data['detail'] ?? 'Erro ao cadastrar.');
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      await saveTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
      );
      await saveUser(data['user']);
      return data;
    }
    throw ApiException(res.statusCode, data['detail'] ?? 'Erro ao fazer login.');
  }

  static Future<void> logout() async {
    final headers = await _authHeaders();
    await http.post(Uri.parse('$baseUrl/auth/logout'), headers: headers);
    await clearTokens();
  }

  static Future<Map<String, dynamic>> getMe() async {
    final headers = await _authHeaders();
    final res = await http.get(Uri.parse('$baseUrl/auth/me'), headers: headers);
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw ApiException(res.statusCode, data['detail'] ?? 'Erro ao buscar usuário.');
  }

  static Future<bool> tryRefresh() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return false;
    final res = await http.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      await saveTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
      );
      await saveUser(data['user']);
      return true;
    }
    return false;
  }

  // ─── Records ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getLatestRecord() async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('$baseUrl/records/latest'),
      headers: headers,
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    if (res.statusCode == 404) return {};
    final data = jsonDecode(res.body);
    throw ApiException(res.statusCode, data['detail'] ?? 'Erro.');
  }

  static Future<Map<String, dynamic>> getStreak() async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('$baseUrl/records/streak'),
      headers: headers,
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    final data = jsonDecode(res.body);
    throw ApiException(res.statusCode, data['detail'] ?? 'Erro.');
  }

  static Future<Map<String, dynamic>> listRecords({
    int limit = 20,
    String? cursor,
  }) async {
    final headers = await _authHeaders();
    var url = '$baseUrl/records?limit=$limit';
    if (cursor != null) url += '&cursor=$cursor';
    final res = await http.get(Uri.parse(url), headers: headers);
    if (res.statusCode == 200) return jsonDecode(res.body);
    final data = jsonDecode(res.body);
    throw ApiException(res.statusCode, data['detail'] ?? 'Erro.');
  }

  static Future<Map<String, dynamic>> getRecord(String id) async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('$baseUrl/records/$id'),
      headers: headers,
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    final data = jsonDecode(res.body);
    throw ApiException(res.statusCode, data['detail'] ?? 'Erro.');
  }

  /// Envia a foto como bytes (cross-platform: web, Android, iOS, desktop).
  static Future<Map<String, dynamic>> createRecord({
    required Uint8List bytes,
    required String filename,
    required String contentType,
    String? notes,
  }) async {
    final token = await getAccessToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/records'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes(
      'photo',
      bytes,
      filename: filename,
      contentType: MediaType.parse(contentType),
    ));
    if (notes != null && notes.isNotEmpty) {
      request.fields['notes'] = notes;
    }
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) return data;
    throw ApiException(res.statusCode, data['detail'] ?? 'Erro ao criar registro.');
  }

  static Future<void> deleteRecord(String id) async {
    final headers = await _authHeaders();
    final res = await http.delete(
      Uri.parse('$baseUrl/records/$id'),
      headers: headers,
    );
    if (res.statusCode != 204) {
      final data = jsonDecode(res.body);
      throw ApiException(res.statusCode, data['detail'] ?? 'Erro ao deletar.');
    }
  }

  static Future<Map<String, dynamic>> compareRecords({
    required String recordIdA,
    required String recordIdB,
  }) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/records/compare'),
      headers: headers,
      body: jsonEncode({'record_id_a': recordIdA, 'record_id_b': recordIdB}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw ApiException(res.statusCode, data['detail'] ?? 'Erro ao comparar.');
  }
}

// ─── Exception ──────────────────────────────────────────────────────────────

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}