import 'dart:convert';

import 'package:ecoair/services/otp_email_sender.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'Sends OTP to the requested email and requires provider confirmation',
    () async {
      final sender = OtpEmailSender(
        baseUrl: 'https://mail.ecoair.test/',
        client: MockClient((request) async {
          expect(request.url.toString(), 'https://mail.ecoair.test/send-otp');
          expect(jsonDecode(request.body), {
            'email': 'member@example.com',
            'otp': '135790',
          });
          return http.Response('{"ok":true,"id":"email-id"}', 200);
        }),
      );
      await sender.sendOtp(email: ' member@example.com ', otp: '135790');
    },
  );

  test(
    'Missing configuration fails instead of pretending an email was sent',
    () async {
      await expectLater(
        const OtpEmailSender(
          baseUrl: '',
        ).sendOtp(email: 'member@example.com', otp: '135790'),
        throwsA(isA<OtpEmailException>()),
      );
    },
  );

  for (final body in ['not-json', '{"ok":false}', '{"ok":true,"id":null}']) {
    test('Rejects unconfirmed delivery: $body', () async {
      final sender = OtpEmailSender(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        sender.sendOtp(email: 'member@example.com', otp: '135790'),
        throwsA(isA<OtpEmailException>()),
      );
    });
  }

  test(
    'Displays provider rejection and connection failure as errors',
    () async {
      final rejected = OtpEmailSender(
        client: MockClient(
          (_) async => http.Response(
            '{"ok":false,"message":"Sender domain is not verified."}',
            502,
          ),
        ),
      );
      await expectLater(
        rejected.sendOtp(email: 'member@example.com', otp: '135790'),
        throwsA(
          isA<OtpEmailException>().having(
            (e) => e.message,
            'message',
            contains('not verified'),
          ),
        ),
      );
      final offline = OtpEmailSender(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      await expectLater(
        offline.sendOtp(email: 'member@example.com', otp: '135790'),
        throwsA(
          isA<OtpEmailException>().having(
            (e) => e.message,
            'message',
            contains('Cannot reach'),
          ),
        ),
      );
    },
  );
}
