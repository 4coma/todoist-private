import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service de gestion de l'authentification Firebase
class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream pour écouter les changements d'état d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Getter pour l'utilisateur actuel
  User? get currentUser => _auth.currentUser;
  
  // Vérifier si un utilisateur est connecté
  bool get isAuthenticated => _auth.currentUser != null;
  
  // Obtenir l'ID de l'utilisateur actuel
  String? get currentUserId => _auth.currentUser?.uid;

  /// Créer un compte avec email et mot de passe
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔄 FirebaseAuthService: Création de compte pour $email');
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('✅ FirebaseAuthService: Compte créé avec succès');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthService: Erreur lors de la création du compte: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ FirebaseAuthService: Erreur inattendue: $e');
      rethrow;
    }
  }

  /// Se connecter avec email et mot de passe
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔄 FirebaseAuthService: Connexion pour $email');
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('✅ FirebaseAuthService: Connexion réussie');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthService: Erreur lors de la connexion: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ FirebaseAuthService: Erreur inattendue: $e');
      rethrow;
    }
  }

  /// Se connecter de manière anonyme (pour tester)
  Future<UserCredential> signInAnonymously() async {
    try {
      debugPrint('🔄 FirebaseAuthService: Connexion anonyme');
      final userCredential = await _auth.signInAnonymously();
      debugPrint('✅ FirebaseAuthService: Connexion anonyme réussie');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthService: Erreur lors de la connexion anonyme: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ FirebaseAuthService: Erreur inattendue: $e');
      rethrow;
    }
  }

  /// Se déconnecter
  Future<void> signOut() async {
    try {
      debugPrint('🔄 FirebaseAuthService: Déconnexion');
      await _auth.signOut();
      debugPrint('✅ FirebaseAuthService: Déconnexion réussie');
    } catch (e) {
      debugPrint('❌ FirebaseAuthService: Erreur lors de la déconnexion: $e');
      rethrow;
    }
  }

  /// Réinitialiser le mot de passe
  Future<void> resetPassword(String email) async {
    try {
      debugPrint('🔄 FirebaseAuthService: Réinitialisation du mot de passe pour $email');
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('✅ FirebaseAuthService: Email de réinitialisation envoyé');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthService: Erreur lors de la réinitialisation: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ FirebaseAuthService: Erreur inattendue: $e');
      rethrow;
    }
  }

  /// Changer le mot de passe (nécessite une reconnexion récente)
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Aucun utilisateur connecté');
      }

      if (user.email == null) {
        throw Exception('Email non disponible');
      }

      // Réauthentifier l'utilisateur
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Changer le mot de passe
      await user.updatePassword(newPassword);
      debugPrint('✅ FirebaseAuthService: Mot de passe changé avec succès');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthService: Erreur lors du changement de mot de passe: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ FirebaseAuthService: Erreur inattendue: $e');
      rethrow;
    }
  }

  /// Mettre à jour le profil utilisateur
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Aucun utilisateur connecté');
      }

      await user.updateDisplayName(displayName);
      await user.updatePhotoURL(photoURL);
      await user.reload();
      
      debugPrint('✅ FirebaseAuthService: Profil mis à jour');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthService: Erreur lors de la mise à jour du profil: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ FirebaseAuthService: Erreur inattendue: $e');
      rethrow;
    }
  }

  /// Supprimer le compte utilisateur
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Aucun utilisateur connecté');
      }

      await user.delete();
      debugPrint('✅ FirebaseAuthService: Compte supprimé');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthService: Erreur lors de la suppression du compte: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ FirebaseAuthService: Erreur inattendue: $e');
      rethrow;
    }
  }

  /// Gérer les exceptions Firebase Auth et les convertir en messages utilisateur
  Exception _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return Exception('Le mot de passe est trop faible');
      case 'email-already-in-use':
        return Exception('Cet email est déjà utilisé');
      case 'user-not-found':
        return Exception('Aucun compte trouvé avec cet email');
      case 'wrong-password':
        return Exception('Mot de passe incorrect');
      case 'invalid-email':
        return Exception('Email invalide');
      case 'user-disabled':
        return Exception('Ce compte a été désactivé');
      case 'too-many-requests':
        return Exception('Trop de tentatives. Veuillez réessayer plus tard');
      case 'operation-not-allowed':
        return Exception('Cette opération n\'est pas autorisée');
      case 'requires-recent-login':
        return Exception('Veuillez vous reconnecter pour effectuer cette action');
      default:
        return Exception('Erreur d\'authentification: ${e.message ?? e.code}');
    }
  }
}



