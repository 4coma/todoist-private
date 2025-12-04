import 'package:flutter/material.dart';
import '../../services/firebase_auth_service.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets.dart';
import '../../design_system/forms.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;

  final FirebaseAuthService _authService = FirebaseAuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isSignUp) {
        await _authService.signUpWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compte créé avec succès !'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await _authService.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      // La navigation sera gérée par le StreamBuilder dans main.dart
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isSignUp 
              ? 'Erreur lors de la création du compte: $e'
              : 'Erreur de connexion: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer votre email'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await _authService.resetPassword(_emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email de réinitialisation envoyé !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surfaceColor = DSColor.getSurface(brightness);
    final surfaceSoftColor = DSColor.getSurfaceSoft(brightness);
    final mutedColor = DSColor.getMuted(brightness);

    return Scaffold(
      backgroundColor: surfaceColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo/Titre
                  Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: DSColor.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isSignUp ? 'Créer un compte' : 'Connexion',
                    style: DSTypo.h1Of(context),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp 
                      ? 'Créez un compte pour synchroniser vos tâches'
                      : 'Connectez-vous pour synchroniser vos tâches',
                    style: DSTypo.body.copyWith(color: mutedColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Champ Email
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email',
                        style: DSTypo.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: DSColor.getHeading(brightness),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: DSRadius.soft,
                          boxShadow: brightness == Brightness.dark
                              ? []
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer votre email';
                            }
                            if (!value.contains('@')) {
                              return 'Email invalide';
                            }
                            return null;
                          },
                          style: DSTypo.body.copyWith(color: DSColor.getHeading(brightness)),
                          decoration: InputDecoration(
                            hintText: 'votre@email.com',
                            hintStyle: DSTypo.body.copyWith(color: mutedColor),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            filled: true,
                            fillColor: surfaceColor,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: OutlineInputBorder(
                              borderRadius: DSRadius.soft,
                              borderSide: const BorderSide(color: DSColor.primary, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Champ Mot de passe
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mot de passe',
                        style: DSTypo.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: DSColor.getHeading(brightness),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: DSRadius.soft,
                          boxShadow: brightness == Brightness.dark
                              ? []
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer votre mot de passe';
                            }
                            if (value.length < 6) {
                              return 'Le mot de passe doit contenir au moins 6 caractères';
                            }
                            return null;
                          },
                          style: DSTypo.body.copyWith(color: DSColor.getHeading(brightness)),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            hintStyle: DSTypo.body.copyWith(color: mutedColor),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            filled: true,
                            fillColor: surfaceColor,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: OutlineInputBorder(
                              borderRadius: DSRadius.soft,
                              borderSide: const BorderSide(color: DSColor.primary, width: 1.5),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                color: mutedColor,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Lien mot de passe oublié (uniquement en mode connexion)
                  if (!_isSignUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _resetPassword,
                        child: Text(
                          'Mot de passe oublié ?',
                          style: DSTypo.caption.copyWith(color: DSColor.primary),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Bouton de connexion/inscription
                  DSButton(
                    label: _isSignUp ? 'Créer le compte' : 'Se connecter',
                    icon: _isSignUp ? Icons.person_add : Icons.login,
                    onPressed: _isLoading ? null : _handleAuth,
                  ),
                  const SizedBox(height: 16),

                  // Lien pour basculer entre connexion/inscription
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isSignUp 
                          ? 'Déjà un compte ? '
                          : 'Pas encore de compte ? ',
                        style: DSTypo.body.copyWith(color: mutedColor),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isSignUp = !_isSignUp;
                            _formKey.currentState?.reset();
                          });
                        },
                        child: Text(
                          _isSignUp ? 'Se connecter' : 'Créer un compte',
                          style: DSTypo.body.copyWith(
                            color: DSColor.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

