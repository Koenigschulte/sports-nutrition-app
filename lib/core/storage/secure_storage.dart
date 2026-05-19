import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _storage = FlutterSecureStorage();
const _keyToken = 'auth_token';

final authTokenProvider = FutureProvider<String?>((ref) async {
  return _storage.read(key: _keyToken);
});

Future<void> saveToken(String token) => _storage.write(key: _keyToken, value: token);
Future<void> deleteToken() => _storage.delete(key: _keyToken);
Future<String?> getToken() => _storage.read(key: _keyToken);
