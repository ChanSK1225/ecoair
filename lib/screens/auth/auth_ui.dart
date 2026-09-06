import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/password_policy.dart';
import '../../theme/ecoair_theme.dart';

String? validateAuthEmail(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return 'Enter your email address.';
  if (text.length > 254 ||
      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
    return 'Enter a valid email, such as name@example.com.';
  }
  return null;
}

String? validateAuthPassword(String? value, {bool newPassword = false}) {
  return newPassword
      ? PasswordPolicy.validateNew(value)
      : PasswordPolicy.validateExisting(value);
}

String? validateAuthOtp(String? value) {
  final text = (value ?? '').replaceAll(RegExp(r'\s+'), '').trim();
  if (text.isEmpty) return 'Enter the OTP from your email.';
  if (!RegExp(r'^\d{6}$').hasMatch(text)) {
    return 'OTP must be 6 digits.';
  }
  return null;
}

InputDecoration authInput(String label, String hint, IconData icon) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      prefixIcon: Icon(icon, size: 20),
      errorMaxLines: 3,
    );

Future<bool> confirmAuthAction(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AuthDialog(
        title: title,
        message: message,
        icon: Icons.help_outline,
        action: action,
        onAction: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    ) ??
    false;

String authErrorMessage(Object error) {
  if (error is FormatException) return error.message;
  if (error is StateError) return error.message;
  if (error is DatabaseException) {
    return 'Local storage is unavailable. Check free space on your device and try again. Do not uninstall EcoAir, as that can remove your saved data.';
  }
  return 'Something went wrong on this device. Please try again. If it continues, restart EcoAir.';
}

Future<void> showAuthError(BuildContext context, Object error) =>
    showAuthNotice(
      context,
      title: 'Unable to continue',
      message: authErrorMessage(error),
      icon: Icons.error_outline,
      color: EcoAirColors.danger,
    );

Future<void> showAuthNotice(
  BuildContext context, {
  required String title,
  required String message,
  IconData icon = Icons.check_circle_outline,
  String action = 'OK',
  Color color = EcoAirColors.primary,
  Widget? detail,
}) => showDialog<void>(
  context: context,
  builder: (context) => AuthDialog(
    title: title,
    message: message,
    icon: icon,
    action: action,
    color: color,
    detail: detail,
    onAction: () => Navigator.pop(context),
  ),
);

class AuthDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String action;
  final VoidCallback onAction;
  final VoidCallback? onCancel;
  final Color color;
  final Widget? detail;

  const AuthDialog({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.action,
    required this.onAction,
    this.onCancel,
    this.color = EcoAirColors.primary,
    this.detail,
  });

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: EcoAirColors.text,
                fontSize: 22,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: EcoAirColors.muted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (detail != null) ...[const SizedBox(height: 16), detail!],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(action, textAlign: TextAlign.center),
            ),
            if (onCancel != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
            ],
          ],
        ),
      ),
    ),
  );
}

class AuthPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showBack;
  final bool busy;
  const AuthPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.showBack = true,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          if (showBack)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Back',
                onPressed: busy ? null : () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.air,
                            color: EcoAirColors.primary,
                            size: 32,
                          ),
                          SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'EcoAir Malaysia',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: EcoAirColors.muted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class AuthPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final TextInputAction action;
  final VoidCallback? onSubmit;
  const AuthPasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.hint = 'Enter your password',
    this.helper,
    this.validator,
    this.enabled = true,
    this.action = TextInputAction.next,
    this.onSubmit,
  });
  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscure = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    enabled: widget.enabled,
    obscureText: _obscure,
    autocorrect: false,
    enableSuggestions: false,
    autofillHints: [
      (widget.label == 'Password' && widget.helper == null) ||
              widget.label == 'Current password'
          ? AutofillHints.password
          : AutofillHints.newPassword,
    ],
    textInputAction: widget.action,
    validator: widget.validator,
    onFieldSubmitted: (_) => widget.onSubmit?.call(),
    decoration: authInput(widget.label, widget.hint, Icons.lock_outline)
        .copyWith(
          helperText: widget.helper,
          helperMaxLines: 2,
          suffixIcon: IconButton(
            tooltip: _obscure ? 'Show password' : 'Hide password',
            onPressed: widget.enabled
                ? () => setState(() => _obscure = !_obscure)
                : null,
            icon: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
  );
}

class AuthSubmitButton extends StatelessWidget {
  final String label;
  final bool busy;
  final bool working;
  final VoidCallback onPressed;
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.busy,
    this.working = true,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    width: double.infinity,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy && working
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    ),
  );
}

class AuthLeaveGuard extends StatefulWidget {
  final bool dirty;
  final bool busy;
  final Widget child;
  const AuthLeaveGuard({
    super.key,
    required this.dirty,
    required this.busy,
    required this.child,
  });
  @override
  State<AuthLeaveGuard> createState() => _AuthLeaveGuardState();
}

class _AuthLeaveGuardState extends State<AuthLeaveGuard> {
  bool _allow = false;
  bool _asking = false;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allow || (!widget.busy && !widget.dirty),
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || widget.busy || _asking) return;
      _asking = true;
      final discard = await confirmAuthAction(
        context,
        title: 'Discard changes?',
        message: 'Your unsaved entries will be cleared.',
        action: 'Discard',
      );
      _asking = false;
      if (!mounted || !discard) return;
      setState(() => _allow = true);
      await WidgetsBinding.instance.endOfFrame;
      if (context.mounted) Navigator.pop(context, result);
    },
    child: widget.child,
  );
}

Future<void> showOtpSentDialog(
  BuildContext context, {
  required String email,
}) => showAuthNotice(
  context,
  title: 'Check your email',
  message:
      'Your OTP is on its way. Enter the 6-digit code from your email to reset your password.',
  icon: Icons.mark_email_read_outlined,
  detail: Column(
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          const style = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
          final measure = TextPainter(
            text: TextSpan(text: email, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final label = measure.width <= constraints.maxWidth
              ? email
              : email.replaceFirst('@', '\n@');
          measure.dispose();
          return SelectableText(
            label,
            textAlign: TextAlign.center,
            style: style,
          );
        },
      ),
      const SizedBox(height: 12),
      const Text(
        'Valid for 10 minutes. Check your spam folder too.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: EcoAirColors.muted, height: 1.5),
      ),
    ],
  ),
);
