import 'package:flutter/material.dart';

import '../data/auth_api.dart';
import '../data/auth_session.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _emailController =
      TextEditingController();
  final TextEditingController _passwordController =
      TextEditingController();

  final FocusNode _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    final isValid =
        _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await AuthSession.instance.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } on AuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'La connexion a échoué. Réessayez.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 2,
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color:
                                    colorScheme.primaryContainer,
                                borderRadius:
                                    BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.account_tree_outlined,
                                size: 38,
                                color: colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Planner',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Connectez-vous pour accéder à vos projets.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: _emailController,
                            autofocus: true,
                            enabled: !_isSubmitting,
                            keyboardType:
                                TextInputType.emailAddress,
                            textInputAction:
                                TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.username,
                              AutofillHints.email,
                            ],
                            decoration:
                                const InputDecoration(
                              labelText: 'Adresse e-mail',
                              prefixIcon:
                                  Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final email =
                                  value?.trim() ?? '';

                              if (email.isEmpty) {
                                return 'Saisissez votre adresse e-mail.';
                              }

                              if (!email.contains('@')) {
                                return 'L’adresse e-mail est invalide.';
                              }

                              return null;
                            },
                            onFieldSubmitted: (_) {
                              _passwordFocusNode
                                  .requestFocus();
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller:
                                _passwordController,
                            focusNode: _passwordFocusNode,
                            enabled: !_isSubmitting,
                            obscureText: _obscurePassword,
                            textInputAction:
                                TextInputAction.done,
                            autofillHints: const [
                              AutofillHints.password,
                            ],
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              prefixIcon:
                                  const Icon(Icons.lock_outline),
                              border:
                                  const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Afficher le mot de passe'
                                    : 'Masquer le mot de passe',
                                onPressed: _isSubmitting
                                    ? null
                                    : () {
                                        setState(() {
                                          _obscurePassword =
                                              !_obscurePassword;
                                        });
                                      },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons
                                          .visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.isEmpty) {
                                return 'Saisissez votre mot de passe.';
                              }

                              return null;
                            },
                            onFieldSubmitted: (_) =>
                                _submit(),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding:
                                  const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    colorScheme.errorContainer,
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: colorScheme
                                        .onErrorContainer,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: colorScheme
                                            .onErrorContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed:
                                _isSubmitting ? null : _submit,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Text(
                              _isSubmitting
                                  ? 'Connexion...'
                                  : 'Se connecter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
