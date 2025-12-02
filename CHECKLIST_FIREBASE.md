# ✅ Checklist - Finalisation Firebase

## 🔧 Configuration Firebase (OBLIGATOIRE)

### 1. Créer le projet Firebase
- [ ] Aller sur [Firebase Console](https://console.firebase.google.com/)
- [ ] Créer un nouveau projet (ex: `todo-app`)
- [ ] Noter le nom du projet : ________________

### 2. Configuration Android
- [ ] Dans Firebase Console → Ajouter une app Android
- [ ] Trouver le **package name** dans `android/app/build.gradle` (ligne `applicationId`)
  - Package name actuel : ________________
- [ ] Télécharger `google-services.json`
- [ ] Placer `google-services.json` dans `android/app/google-services.json`
- [ ] Vérifier que `android/build.gradle` contient :
  ```gradle
  buildscript {
      dependencies {
          classpath 'com.google.gms:google-services:4.4.0'
      }
  }
  ```
- [ ] Vérifier que `android/app/build.gradle` contient (à la fin) :
  ```gradle
  apply plugin: 'com.google.gms.google-services'
  ```

### 3. Configuration iOS (si vous développez pour iOS)
- [ ] Dans Firebase Console → Ajouter une app iOS
- [ ] Trouver le **Bundle ID** dans Xcode ou `ios/Runner/Info.plist`
- [ ] Télécharger `GoogleService-Info.plist`
- [ ] Placer `GoogleService-Info.plist` dans `ios/Runner/`
- [ ] Exécuter `cd ios && pod install`

### 4. Activer les services Firebase

#### Authentication
- [ ] Aller dans Firebase Console → Authentication
- [ ] Cliquer sur "Get Started"
- [ ] Activer **Email/Password**
- [ ] (Optionnel) Activer **Anonymous** pour les tests

#### Cloud Firestore
- [ ] Aller dans Firebase Console → Firestore Database
- [ ] Cliquer sur "Create database"
- [ ] Choisir **Start in test mode** (pour commencer)
- [ ] Sélectionner une région (ex: `europe-west`)
- [ ] Cliquer sur "Enable"

### 5. Configurer les règles de sécurité
- [ ] Aller dans Firestore Database → Rules
- [ ] Copier le contenu de `firestore.rules` dans votre projet
- [ ] Cliquer sur "Publish"

## 📦 Installation des dépendances

- [ ] Exécuter `flutter pub get` dans le terminal
- [ ] Vérifier qu'il n'y a pas d'erreurs

## 🧪 Tests de base

### Test 1 : Vérifier l'initialisation
- [ ] Lancer l'app : `flutter run`
- [ ] Vérifier dans les logs qu'on voit : `✅ Firebase initialisé`
- [ ] Si erreur : vérifier que `google-services.json` est bien placé

### Test 2 : Authentification anonyme (pour tester)
- [ ] Ajouter temporairement dans `main.dart` après l'initialisation :
  ```dart
  // Test d'authentification anonyme
  try {
    final authService = FirebaseAuthService();
    if (!authService.isAuthenticated) {
      await authService.signInAnonymously();
      print('✅ Authentifié anonymement');
    }
  } catch (e) {
    print('❌ Erreur auth: $e');
  }
  ```
- [ ] Lancer l'app et vérifier les logs
- [ ] Vérifier que la synchronisation démarre

### Test 3 : Vérifier la synchronisation
- [ ] Créer quelques tâches dans l'app
- [ ] Vérifier dans Firebase Console → Firestore que les données apparaissent
- [ ] Modifier une tâche dans l'app
- [ ] Vérifier que la modification apparaît dans Firestore

### Test 4 : Migration des données existantes
- [ ] Si vous avez déjà des données locales
- [ ] Se connecter avec Firebase
- [ ] Vérifier que les données sont migrées automatiquement
- [ ] Vérifier dans Firestore que toutes les données sont présentes

## 🎨 UI d'authentification (RECOMMANDÉ)

### Option 1 : Écran de connexion simple
- [ ] Créer un écran de connexion (`lib/screens/login_screen.dart`)
- [ ] Ajouter des champs email/password
- [ ] Utiliser `FirebaseAuthService().signInWithEmailAndPassword()`
- [ ] Ajouter un lien "Créer un compte"
- [ ] Utiliser `FirebaseAuthService().signUpWithEmailAndPassword()`

### Option 2 : Utiliser un package
- [ ] Installer `flutterfire_ui` (optionnel, pour une UI pré-faite)
- [ ] Ou créer votre propre UI personnalisée

### Intégration dans l'app
- [ ] Vérifier l'état d'authentification au démarrage
- [ ] Afficher l'écran de connexion si non connecté
- [ ] Afficher l'app principale si connecté
- [ ] Ajouter un bouton de déconnexion dans les paramètres

## 🔍 Vérifications finales

### Vérifier la structure Firestore
- [ ] Ouvrir Firebase Console → Firestore Database
- [ ] Vérifier que la structure est :
  ```
  users/
    └── {userId}/
        ├── todos/
        ├── projects/
        ├── preferences/
        └── timer_data/
  ```

### Vérifier les logs
- [ ] Lancer l'app en mode debug
- [ ] Vérifier qu'il n'y a pas d'erreurs Firebase
- [ ] Vérifier que la synchronisation fonctionne

### Vérifier le mode offline
- [ ] Mettre l'app en mode avion
- [ ] Créer/modifier des tâches
- [ ] Remettre la connexion
- [ ] Vérifier que les données se synchronisent

## 📝 Notes importantes

### ⚠️ Points d'attention

1. **Sécurité** : Les règles Firestore sont en mode test. Pour la production, vous devrez :
   - Restreindre davantage les règles si nécessaire
   - Ajouter des validations supplémentaires

2. **Coûts Firebase** :
   - Firestore a un plan gratuit généreux
   - Surveillez l'utilisation dans la console Firebase
   - Configurez des alertes de budget si nécessaire

3. **Performance** :
   - La synchronisation automatique se fait toutes les 5 minutes
   - Les modifications locales sont synchronisées immédiatement
   - Le mode offline est activé par défaut

4. **Migration** :
   - La migration est automatique au premier lancement après connexion
   - Les données locales sont conservées (doublon temporaire)
   - Vous pouvez supprimer les données locales après vérification

### 🐛 Dépannage

Si vous rencontrez des problèmes :

1. **"FirebaseApp not initialized"**
   - Vérifiez que `google-services.json` est bien dans `android/app/`
   - Vérifiez que le plugin Google Services est dans `build.gradle`

2. **"Permission denied"**
   - Vérifiez les règles Firestore
   - Vérifiez que l'utilisateur est authentifié

3. **Les données ne se synchronisent pas**
   - Vérifiez les logs pour les erreurs
   - Vérifiez que Firestore est activé
   - Vérifiez que l'utilisateur est connecté

## ✅ Checklist finale

- [ ] Firebase configuré et fonctionnel
- [ ] Authentification testée
- [ ] Synchronisation testée
- [ ] Migration testée (si données existantes)
- [ ] UI d'authentification ajoutée (optionnel)
- [ ] Mode offline testé
- [ ] Pas d'erreurs dans les logs
- [ ] Données visibles dans Firestore Console

## 🎉 Une fois tout terminé

Votre application est maintenant prête avec :
- ✅ Synchronisation cloud automatique
- ✅ Sauvegarde de toutes les données utilisateur
- ✅ Synchronisation en temps réel
- ✅ Mode offline fonctionnel
- ✅ Migration automatique des données

---

**Besoin d'aide ?** Consultez :
- `FIREBASE_SETUP.md` pour la configuration détaillée
- `FIREBASE_IMPLEMENTATION.md` pour les détails techniques
- Les logs de l'application pour le débogage





