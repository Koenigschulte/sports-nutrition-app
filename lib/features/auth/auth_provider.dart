import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/storage/secure_storage.dart';

final authProvider = StateNotifierProvider<AuthNotifier, bool>((ref) {
  return AuthNotifier(ref.read(dioProvider));
});

class AuthNotifier extends StateNotifier<bool> {
  AuthNotifier(this._dio) : super(false);

  final Dio _dio;

  // Returns null on success, error message on failure
  Future<String?> login(String email, String password) async {
    try {
      final res = await _dio.post('/auth/login', data: {'email': email, 'password': password});
      await saveToken(res.data['token'] as String);
      state = true;
      return null;
    } on DioException catch (e) {
      return e.response?.data?['error'] as String? ?? 'Anmeldung fehlgeschlagen';
    }
  }

  Future<String?> register(String name, String email, String password) async {
    try {
      final res = await _dio.post('/auth/register', data: {'name': name, 'email': email, 'password': password});
      await saveToken(res.data['token'] as String);
      state = true;
      return null;
    } on DioException catch (e) {
      return e.response?.data?['error'] as String? ?? 'Registrierung fehlgeschlagen';
    }
  }

  Future<void> logout() async {
    await deleteToken();
    state = false;
  }
}
