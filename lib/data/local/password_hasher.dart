import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

class PasswordHasher {
  static Future<String> hash(String password) => compute(_hash, password);
  static Future<bool> verify(String password, String encoded) =>
      compute(_verify, [password, encoded]);
  static Argon2id _algorithm() =>
      Argon2id(parallelism: 1, memory: 19456, iterations: 2, hashLength: 32);

  static Future<String> _hash(String password) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final key = await _algorithm().deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    return jsonEncode({
      'algorithm': 'argon2id',
      'version': 19,
      'memory': 19456,
      'iterations': 2,
      'parallelism': 1,
      'salt': base64Encode(salt),
      'hash': base64Encode(await key.extractBytes()),
    });
  }

  static Future<bool> _verify(List<String> args) async {
    try {
      final data = jsonDecode(args[1]) as Map<String, dynamic>;
      if (data['algorithm'] != 'argon2id' ||
          data['version'] != 19 ||
          data['memory'] != 19456 ||
          data['iterations'] != 2 ||
          data['parallelism'] != 1) {
        return false;
      }
      final expected = base64Decode(data['hash'] as String);
      final salt = base64Decode(data['salt'] as String);
      if (expected.length != 32 || salt.length != 16) return false;
      final key = await _algorithm().deriveKeyFromPassword(
        password: args[0],
        nonce: salt,
      );
      final actual = await key.extractBytes();
      return SecretKeyData(actual) == SecretKeyData(expected);
    } catch (_) {
      return false;
    }
  }
}
