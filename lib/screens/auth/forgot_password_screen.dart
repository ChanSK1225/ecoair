import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'auth_ui.dart';
import 'register_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _emailField = GlobalKey<FormFieldState<String>>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _working = false;
  bool _submitted = false;
  bool _otpRequested = false;
  bool _complete = false;
  bool get _dirty =>
      !_complete &&
      (_email.text != widget.initialEmail ||
          [_otp, _password, _confirm].any((c) => c.text.isNotEmpty));

  @override
  void dispose() {
    for (final c in [_email, _otp, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_busy) return;
    if (!(_emailField.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _working = true;
    });
    try {
      await context.read<AuthProvider>().requestPasswordResetOtp(_email.text);
      if (!mounted) return;
      setState(() {
        _working = false;
        _otpRequested = true;
        _otp.clear();
      });
      await showOtpSentDialog(context, email: _email.text.trim());
    } on AccountNotFoundException catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _otpRequested = false;
        _otp.clear();
      });
      final createAccount = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AuthDialog(
          icon: Icons.person_add_alt_1_outlined,
          title: 'No account found',
          message:
              'No account is registered with ${e.email} on this device. Create an account to get started.',
          action: 'Create account',
          onAction: () => Navigator.pop(dialogContext, true),
          onCancel: () => Navigator.pop(dialogContext, false),
        ),
      );
      if (!mounted || createAccount != true) return;
      final registeredEmail = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => RegisterScreen(initialEmail: e.email),
        ),
      );
      if (!mounted || registeredEmail == null) return;
      setState(() {
        _complete = true;
        _busy = false;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, registeredEmail);
    } catch (e) {
      if (mounted) {
        setState(() => _working = false);
        await showAuthError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_busy) return;
    setState(() => _submitted = true);
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final confirmed = await confirmAuthAction(
        context,
        title: 'Reset password?',
        message:
            'Reset the password for ${_email.text.trim()}? Your saved cities, reports and orders will be kept.',
        action: 'Reset password',
      );
      if (!mounted || !confirmed) return;
      setState(() => _working = true);
      await context.read<AuthProvider>().resetPassword(
        _email.text,
        _otp.text,
        _password.text,
      );
      _complete = true;
      if (!mounted) return;
      setState(() => _working = false);
      await showAuthNotice(
        context,
        icon: Icons.lock_open_outlined,
        title: 'Password reset',
        message:
            'Your password has been updated.\nUse your new password to log in.',
        action: 'Back to log in',
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, _email.text.trim());
    } catch (e) {
      if (mounted) {
        setState(() => _working = false);
        await showAuthError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthLeaveGuard(
    dirty: _dirty,
    busy: _busy,
    child: AuthPage(
      title: 'Forgot password?',
      subtitle: 'Send a one-time OTP to reset your local EcoAir account.',
      busy: _busy,
      children: [
        Form(
          key: _form,
          onChanged: () => setState(() {}),
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: _emailField,
                controller: _email,
                enabled: !_busy,
                onChanged: (_) {
                  if (_otpRequested) {
                    setState(() {
                      _otpRequested = false;
                      _otp.clear();
                    });
                  }
                },
                validator: validateAuthEmail,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: authInput(
                  'Email',
                  'name@example.com',
                  Icons.email_outlined,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _sendOtp,
                icon: _busy && _working
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.mark_email_read_outlined),
                label: Text(_otpRequested ? 'Resend OTP' : 'Send OTP'),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _otp,
                enabled: !_busy,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                textInputAction: TextInputAction.next,
                validator: validateAuthOtp,
                decoration: authInput(
                  'Email OTP',
                  '6-digit OTP',
                  Icons.password_outlined,
                ),
              ),
              const SizedBox(height: 20),
              AuthPasswordField(
                controller: _password,
                enabled: !_busy,
                label: 'New password',
                hint: 'Create a new password',
                helper: '8-12 chars, upper/lower, number & symbol',
                validator: (v) => validateAuthPassword(v, newPassword: true),
              ),
              const SizedBox(height: 20),
              AuthPasswordField(
                controller: _confirm,
                enabled: !_busy,
                label: 'Confirm new password',
                hint: 'Repeat your new password',
                validator: (v) => (v ?? '').isEmpty
                    ? 'Confirm your new password.'
                    : v != _password.text
                    ? 'Passwords do not match.'
                    : null,
                action: TextInputAction.done,
                onSubmit: _reset,
              ),
              const SizedBox(height: 28),
              AuthSubmitButton(
                label: 'Reset password',
                busy: _busy,
                working: _working,
                onPressed: _reset,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _busy
              ? null
              : () => showAuthNotice(
                  context,
                  icon: Icons.mail_outline,
                  title: 'No OTP?',
                  message:
                      'Check your inbox and spam folder.\n\nUse the email registered in EcoAir on this device. Wait a minute before requesting another OTP. Only the newest code will work.',
                ),
          child: const Text('I did not receive an OTP'),
        ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.maybePop(context),
          child: const Text('Back to log in'),
        ),
      ],
    ),
  );
}
