import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/util/validators.dart';
import '../../core/widgets/widgets.dart';

enum _Mode { signIn, signUp, forgot }

/// Google + email/password. No phone OTP. Staff access is granted in the database, never from this screen.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.from});
  final String? from;
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  _Mode _mode = _Mode.signIn;
  bool _busy = false, _show = false, _left = false;
  String? _error, _info;

  /// Closes this screen once an account is signed in. The router also redirects, but a screen opened with
  /// push() (for example from Profile) is not removed by a redirect, so the screen leaves by itself.
  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(widget.from ?? '/');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() { _busy = true; _error = null; _info = null; });
    try {
      await f();
    } catch (e) {
      if (mounted) setState(() => _error = toAppException(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final auth = ref.read(authServiceProvider);
    _run(() async {
      switch (_mode) {
        case _Mode.signIn:
          await auth.signIn(email: _email.text, password: _password.text);
          _leave();
        case _Mode.signUp:
          final signedIn = await auth.signUp(email: _email.text, password: _password.text, fullName: _name.text);
          if (signedIn) _leave();
          if (!signedIn && mounted) {
            setState(() { _info = 'We sent a verification link to ${_email.text.trim()}. Open it, then sign in.'; _mode = _Mode.signIn; });
          }
        case _Mode.forgot:
          await auth.resetPassword(_email.text);
          if (mounted) setState(() { _info = 'If that email is registered, a reset link is on its way.'; _mode = _Mode.signIn; });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Google sign-in returns through a deep link, so the account can appear while this screen is open
    ref.listen(currentUserIdProvider, (_, next) {
      if (next != null) _leave();
    });
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final title = switch (_mode) { _Mode.signIn => 'Sign in', _Mode.signUp => 'Create account', _Mode.forgot => 'Reset password' };
    return Scaffold(
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), tooltip: 'Back', onPressed: () => context.canPop() ? context.pop() : context.go('/'))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
          const Center(child: LogoBadge(size: 88)),
          const SizedBox(height: 12),
          Center(child: Text('Budget Aapka, Phone Hamara', style: t.titleMedium)),
          const SizedBox(height: 24),
          Text(title, style: t.headlineSmall),
          const SizedBox(height: 16),
          if (_info != null) _Notice(_info!, tone: Tone.success),
          if (_error != null) _Notice(_error!, tone: Tone.danger),
          Form(
            key: _form,
            child: Column(children: [
              if (_mode == _Mode.signUp) ...[
                AppTextField(label: 'Full name', controller: _name, validator: validateName, autofillHints: const [AutofillHints.name], textInputAction: TextInputAction.next),
                const SizedBox(height: 12),
              ],
              AppTextField(label: 'Email', controller: _email, validator: validateEmail, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], textInputAction: TextInputAction.next),
              if (_mode != _Mode.forgot) ...[
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Password', controller: _password, obscure: !_show,
                  validator: _mode == _Mode.signUp ? validatePassword : (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                  autofillHints: [_mode == _Mode.signUp ? AutofillHints.newPassword : AutofillHints.password],
                  onFieldSubmitted: (_) => _submit(),
                  suffix: IconButton(
                    tooltip: _show ? 'Hide password' : 'Show password',
                    icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _show = !_show),
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          AppButton(title, _busy ? null : _submit, loading: _busy),
          if (_mode == _Mode.signIn) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => setState(() { _mode = _Mode.forgot; _error = null; }), child: const Text('Forgot password?'))),
          if (_mode != _Mode.forgot) ...[
            const SizedBox(height: 8),
            Row(children: [const Expanded(child: Divider()), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: t.bodySmall?.copyWith(color: s.onSurfaceVariant))), const Expanded(child: Divider())]),
            const SizedBox(height: 16),
            AppButton('Continue with Google', _busy ? null : () => _run(() => ref.read(authServiceProvider).signInWithGoogle()), style: BtnStyle.outlined, icon: Icons.g_mobiledata),
          ],
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => setState(() { _mode = _mode == _Mode.signUp ? _Mode.signIn : _Mode.signUp; _error = null; _info = null; }),
              child: Text(_mode == _Mode.signUp ? 'Already have an account? Sign in' : (_mode == _Mode.forgot ? 'Back to sign in' : 'New here? Create an account')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Browsing needs no account. You only sign in to save phones, check out and track orders.', style: t.bodySmall?.copyWith(color: s.onSurfaceVariant), textAlign: TextAlign.center),
          ),
        ]),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, {required this.tone});
  final String text;
  final Tone tone;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final ok = tone == Tone.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: ok ? s.tertiaryContainer : s.errorContainer),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(ok ? Icons.check_circle_outline : Icons.error_outline, color: ok ? s.onTertiaryContainer : s.onErrorContainer),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ok ? s.onTertiaryContainer : s.onErrorContainer))),
      ]),
    );
  }
}
