import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'auth_ui.dart';

class RegisterScreen extends StatefulWidget {
  final String initialEmail;
  const RegisterScreen({super.key, this.initialEmail = ''});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _working = false;
  bool _submitted = false;
  bool _complete = false;
  String? _emailError;
  bool get _dirty =>
      !_complete &&
      (_email.text != widget.initialEmail ||
          [_name, _password, _confirm].any((c) => c.text.isNotEmpty));
  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (_busy) return;
    setState(() => _submitted = true);
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _working = true;
    });
    try {
      await context.read<AuthProvider>().checkRegistrationEmail(_email.text);
      if (!mounted) return;
      setState(() => _working = false);
      final confirmed = await confirmAuthAction(
        context,
        title: 'Create local account?',
        message:
            'Create an account for ${_email.text.trim()} on this device? Your data is saved locally, not synced online.',
        action: 'Create account',
      );
      if (!mounted || !confirmed) return;
      setState(() => _working = true);
      await context.read<AuthProvider>().register(
        _email.text,
        _password.text,
        name: _name.text,
        startSession: false,
      );
      _complete = true;
      if (!mounted) return;
      setState(() => _working = false);
      await showAuthNotice(
        context,
        title: 'Account created',
        message:
            'Your EcoAir account is ready.\nLog in with your email and password to continue.',
        action: 'Back to log in',
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, _email.text.trim());
    } on EmailAlreadyRegisteredException catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _emailError = 'Email already registered. Log in instead.';
      });
      _form.currentState?.validate();
      final logIn = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AuthDialog(
          icon: Icons.person_outline,
          title: 'Email already registered',
          message:
              '${e.email} already has an account on this device. Log in with your existing password, or use Forgot password.',
          action: 'Back to log in',
          onAction: () => Navigator.pop(dialogContext, true),
          onCancel: () => Navigator.pop(dialogContext, false),
        ),
      );
      if (!mounted || logIn != true) return;
      setState(() {
        _complete = true;
        _busy = false;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, e.email);
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
      title: 'Create your account',
      subtitle: 'Your EcoAir account stays on this device.',
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
                controller: _name,
                enabled: !_busy,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Enter your name.'
                    : v!.trim().length > 50
                    ? 'Use up to 50 characters.'
                    : null,
                decoration: authInput(
                  'Name',
                  'Your name',
                  Icons.person_outline,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _email,
                enabled: !_busy,
                validator: (value) => validateAuthEmail(value) ?? _emailError,
                onChanged: (_) {
                  if (_emailError != null) setState(() => _emailError = null);
                },
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                decoration: authInput(
                  'Email',
                  'name@example.com',
                  Icons.email_outlined,
                ),
              ),
              const SizedBox(height: 20),
              AuthPasswordField(
                controller: _password,
                enabled: !_busy,
                hint: 'Create a password',
                helper: '8-12 chars, upper/lower, number & symbol',
                validator: (v) => validateAuthPassword(v, newPassword: true),
              ),
              const SizedBox(height: 20),
              AuthPasswordField(
                controller: _confirm,
                enabled: !_busy,
                label: 'Confirm password',
                hint: 'Repeat your password',
                validator: (v) => (v ?? '').isEmpty
                    ? 'Confirm your password.'
                    : v != _password.text
                    ? 'Passwords do not match.'
                    : null,
                action: TextInputAction.done,
                onSubmit: _register,
              ),
              const SizedBox(height: 28),
              AuthSubmitButton(
                label: 'Create account',
                busy: _busy,
                working: _working,
                onPressed: _register,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _busy ? null : () => Navigator.maybePop(context),
          child: const Text('Back to log in'),
        ),
      ],
    ),
  );
}
