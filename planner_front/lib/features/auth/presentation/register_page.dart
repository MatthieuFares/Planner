import 'package:flutter/material.dart';

import '../data/auth_api.dart';

class RegisterPage extends StatefulWidget {
  final String? initialEmail;

  const RegisterPage({
    super.key,
    this.initialEmail,
  });

  @override
  State<RegisterPage> createState() =>
      _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  late final TextEditingController _emailController;
  final TextEditingController _passwordController =
      TextEditingController();
  final TextEditingController
      _passwordConfirmationController =
      TextEditingController();

  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmationFocusNode = FocusNode();

  final AuthApi _authApi = AuthApi();

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _emailController = TextEditingController(
      text: widget.initialEmail?.trim() ?? '',
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    _passwordFocusNode.dispose();
    _confirmationFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final isValid =
        _formKey.currentState?.validate() ?? false;

    if (!isValid) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();

      await _authApi.register(
        email: email,
        password: _passwordController.text,
      );

      if (!mounted) return;

      Navigator.of(context).pop(email);
    } on AuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'L’inscription a échoué. Réessayez.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Saisissez votre adresse e-mail.';
    }

    final emailPattern = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailPattern.hasMatch(email)) {
      return 'L’adresse e-mail est invalide.';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Saisissez un mot de passe.';
    }

    if (password.length < 10) {
      return 'Utilisez au moins 10 caractères.';
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Ajoutez au moins une majuscule.';
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Ajoutez au moins une minuscule.';
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Ajoutez au moins un chiffre.';
    }

    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Ajoutez au moins un caractère spécial.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un compte'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 480),
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
                                Icons.person_add_alt_1_outlined,
                                size: 38,
                                color: colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Créer votre compte Planner',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Le compte devra ensuite être ajouté '
                            'à un projet par un Manager.',
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
                            validator: _validateEmail,
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
                                TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.newPassword,
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
                            validator: _validatePassword,
                            onFieldSubmitted: (_) {
                              _confirmationFocusNode
                                  .requestFocus();
                            },
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '10 caractères minimum, avec '
                            'majuscule, minuscule, chiffre et '
                            'caractère spécial.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller:
                                _passwordConfirmationController,
                            focusNode:
                                _confirmationFocusNode,
                            enabled: !_isSubmitting,
                            obscureText:
                                _obscureConfirmation,
                            textInputAction:
                                TextInputAction.done,
                            autofillHints: const [
                              AutofillHints.newPassword,
                            ],
                            decoration: InputDecoration(
                              labelText:
                                  'Confirmer le mot de passe',
                              prefixIcon:
                                  const Icon(
                                Icons.lock_reset_outlined,
                              ),
                              border:
                                  const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                tooltip: _obscureConfirmation
                                    ? 'Afficher la confirmation'
                                    : 'Masquer la confirmation',
                                onPressed: _isSubmitting
                                    ? null
                                    : () {
                                        setState(() {
                                          _obscureConfirmation =
                                              !_obscureConfirmation;
                                        });
                                      },
                                icon: Icon(
                                  _obscureConfirmation
                                      ? Icons.visibility_outlined
                                      : Icons
                                          .visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.isEmpty) {
                                return 'Confirmez votre mot de passe.';
                              }

                              if (value !=
                                  _passwordController.text) {
                                return 'Les mots de passe ne correspondent pas.';
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
                                : const Icon(
                                    Icons.person_add_alt_1,
                                  ),
                            label: Text(
                              _isSubmitting
                                  ? 'Création...'
                                  : 'Créer le compte',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _isSubmitting
                                ? null
                                : () {
                                    Navigator.of(context).pop();
                                  },
                            child: const Text(
                              'J’ai déjà un compte',
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
