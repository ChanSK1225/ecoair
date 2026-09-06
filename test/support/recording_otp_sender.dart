import 'package:ecoair/services/otp_email_sender.dart';

// Test mailbox: tests read delivered codes without exposing them in app UI.
class RecordingOtpSender extends OtpEmailSender {
  final Map<String, String> deliveries = {};

  RecordingOtpSender() : super(baseUrl: 'https://mail.ecoair.test');

  @override
  Future<void> sendOtp({required String email, required String otp}) async {
    deliveries[email.trim().toLowerCase()] = otp;
  }
}
