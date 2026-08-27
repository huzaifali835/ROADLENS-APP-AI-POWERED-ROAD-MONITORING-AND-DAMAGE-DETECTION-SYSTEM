import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import 'auth_controller.dart';
import 'auth_scaffold.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final success = await ref
        .read(authControllerProvider.notifier)
        .requestPasswordReset(_emailController.text);
    if (success && mounted) setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final loading = state.status == AuthActionStatus.loading;
    return AuthScaffold(
      title: _submitted ? 'Check your email' : 'Reset password',
      subtitle: _submitted
          ? 'A mock recovery message has been prepared for this Phase 1 flow.'
          : 'Enter your account email to request a reset link.',
      child: _submitted
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.mark_email_read_outlined,
                        color: AppColors.success,
                        size: 42,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No message was sent. Email delivery will be connected to the real auth service in Phase 2.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.pop(),
                  child: const Text('Back to Login'),
                ),
              ],
            )
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('forgot-email-field'),
                    controller: _emailController,
                    enabled: !loading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty || !email.contains('@')) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    key: const Key('forgot-submit-button'),
                    onPressed: loading ? null : _submit,
                    child: loading
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Send Reset Link'),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: loading ? null : () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Back to Login'),
                  ),
                ],
              ),
            ),
    );
  }
}
