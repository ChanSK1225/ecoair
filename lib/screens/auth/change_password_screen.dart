import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/ecoair_ui.dart';
import 'auth_ui.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _submitted = false;
  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _submitted = true);
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().changePassword(_old.text, _new.text);
      if (mounted) {
        showEcoAirSnackBar(context, 'Password updated.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showEcoAirSnackBar(context, friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Change Password')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Column(
            children: [
              AuthPasswordField(
                controller: _old,
                enabled: !_busy,
                label: 'Current password',
                hint: 'Enter current password',
                validator: validateAuthPassword,
              ),
              const SizedBox(height: 20),
              AuthPasswordField(
                controller: _new,
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
                    : v != _new.text
                    ? 'Passwords do not match.'
                    : null,
                action: TextInputAction.done,
                onSubmit: _save,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.lock_reset),
                label: Text(_busy ? 'Saving...' : 'Update password'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
