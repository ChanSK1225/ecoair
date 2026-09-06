import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'backend_config.dart';

class OtpEmailSender {
  static const defaultBaseUrl = BackendConfig.baseUrl;

  final String baseUrl;
  final http.Client? client;

  const OtpEmailSender({this.baseUrl = defaultBaseUrl, this.client});

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  Future<void> sendOtp({required String email, required String otp}) async {
    if (!isConfigured) {
      throw const OtpEmailException(
        'Email delivery is not configured. Please contact the app administrator.',
      );
    }
    final uri = Uri.parse(_join(baseUrl, '/send-otp'));
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim(), 'otp': otp}),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map &&
            decoded['ok'] == true &&
            decoded['id'] is String &&
            (decoded['id'] as String).isNotEmpty) {
          return;
        }
        throw const OtpEmailException(
          'The email service did not confirm sending your OTP. Please try again.',
        );
      }
      throw OtpEmailException(_messageFromResponse(response));
    } on TimeoutException {
      throw const OtpEmailException(
        'The email service took too long to respond. Please try again shortly.',
      );
    } on http.ClientException {
      throw const OtpEmailException(
        'Cannot reach the email service. Check your connection and try again. Your password has not changed.',
      );
    } on FormatException {
      throw const OtpEmailException(
        'The email service returned an invalid response. Please try again.',
      );
    } finally {
      if (client == null) httpClient.close();
    }
  }

  String _join(String root, String path) {
    final trimmed = root.trim().replaceFirst(RegExp(r'/+$'), '');
    return '$trimmed$path';
  }

  String _messageFromResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      final message = decoded is Map ? decoded['message'] : null;
      if (message is String && message.trim().isNotEmpty) return message;
    } catch (_) {
      // Fall through to a status-based error.
    }
    return 'OTP email could not be sent. Server returned ${response.statusCode}.';
  }
}

class OtpEmailException implements Exception {
  final String message;
  const OtpEmailException(this.message);

  @override
  String toString() => message;
}
