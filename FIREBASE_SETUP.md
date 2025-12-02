# Configuration Firebase - Guide de démarrage

## 📋 Prérequis

1. Un compte Google
2. Accès à la [Console Firebase](https://console.firebase.google.com/)
3. Flutter SDK installé et configuré

## 🚀 Étapes de configuration

### 1. Créer un projet Firebase

1. Allez sur [Firebase Console](https://console.firebase.google.com/)
2. Cliquez sur "Ajouter un projet"
3. Entrez un nom pour votre projet (ex: `todo-app`)
4. Suivez les étapes de configuration
5. Activez Google Analytics (optionnel mais recommandé)

### 2. Ajouter une application Android

1. Dans la console Firebase, cliquez sur l'icône Android
2. Entrez le **package name** de votre app :
   - Trouvez-le dans `android/app/build.gradle` → `applicationId`
   - Exemple : `com.example.todo_app`
3. Téléchargez le fichier `google-services.json`
4. Placez-le dans `android/app/google-services.json`

### 3. Ajouter une application iOS (si nécessaire)

1. Dans la console Firebase, cliquez sur l'icône iOS
2. Entrez le **Bundle ID** de votre app
3. Téléchargez le fichier `GoogleService-Info.plist`
4. Placez-le dans `ios/Runner/GoogleService-Info.plist`
5. Ouvrez `ios/Runner.xcworkspace` dans Xcode
6. Glissez-déposez `GoogleService-Info.plist` dans le projet

### 4. Configurer les fichiers de build

#### Android

Modifiez `android/build.gradle` :

```gradle
buildscript {
    dependencies {
        // ... autres dépendances
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

Modifiez `android/app/build.gradle` (à la fin du fichier) :

```gradle
apply plugin: 'com.google.gms.google-services'
```

#### iOS

Si vous utilisez CocoaPods, exécutez :

```bash
cd ios
pod install
```

### 5. Activer les services Firebase

#### Authentication

1. Dans la console Firebase, allez dans **Authentication**
2. Cliquez sur **Get Started**
3. Activez **Email/Password** dans les méthodes de connexion
4. (Optionnel) Activez **Anonymous** pour les tests

#### Cloud Firestore

1. Dans la console Firebase, allez dans **Firestore Database**
2. Cliquez sur **Create database**
3. Choisissez **Start in test mode** (pour commencer)
4. Sélectionnez une région (ex: `europe-west`)

### 6. Configurer les règles de sécurité Firestore

Dans la console Firebase, allez dans **Firestore Database** → **Rules** et collez :

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Règle pour les utilisateurs authentifiés uniquement
    match /users/{userId} {
      // L'utilisateur ne peut accéder qu'à ses propres données
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Collections sous users/{userId}
      match /todos/{todoId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /projects/{projectId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /preferences/{preferenceId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /timer_data/{timerDataId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

Cliquez sur **Publish** pour activer les règles.

### 7. Installer les dépendances Flutter

Exécutez dans le terminal :

```bash
flutter pub get
```

### 8. Vérifier la configuration

Lancez l'application :

```bash
flutter run
```

Si tout est bien configuré, vous devriez voir dans les logs :
```
✅ Firebase initialisé
```

## 🔐 Configuration de l'authentification

### Créer un compte utilisateur

L'application nécessite une authentification pour synchroniser les données. Vous pouvez :

1. **Créer un compte dans l'app** (si vous ajoutez une UI d'authentification)
2. **Utiliser l'authentification anonyme** pour tester :
   ```dart
   final authService = FirebaseAuthService();
   await authService.signInAnonymously();
   ```

### Migration automatique

Lors de la première connexion, les données locales sont automatiquement migrées vers Firebase.

## 📊 Structure des données dans Firestore

```
users/
  └── {userId}/
      ├── todos/
      │   └── {todoId}/
      ├── projects/
      │   └── {projectId}/
      ├── preferences/
      │   └── preferences/
      └── timer_data/
          └── timer_data/
```

## 🧪 Tester la synchronisation

1. Créez quelques tâches et projets localement
2. Connectez-vous avec Firebase
3. Les données devraient être automatiquement migrées
4. Modifiez une tâche sur un autre appareil (si vous avez plusieurs appareils)
5. La modification devrait apparaître en temps réel

## ⚠️ Dépannage

### Erreur : "FirebaseApp not initialized"

- Vérifiez que `google-services.json` est bien placé dans `android/app/`
- Vérifiez que le plugin Google Services est bien configuré dans `build.gradle`

### Erreur : "Permission denied"

- Vérifiez que les règles Firestore sont bien configurées
- Vérifiez que l'utilisateur est bien authentifié

### Erreur : "Network request failed"

- Vérifiez votre connexion internet
- Vérifiez que Firestore est bien activé dans la console Firebase

### Les données ne se synchronisent pas

- Vérifiez que l'utilisateur est connecté : `FirebaseAuthService().isAuthenticated`
- Vérifiez les logs pour voir les erreurs de synchronisation
- Vérifiez que la persistance Firestore est activée

## 📚 Ressources

- [Documentation Firebase Flutter](https://firebase.flutter.dev/)
- [Guide Firestore](https://firebase.google.com/docs/firestore)
- [Règles de sécurité Firestore](https://firebase.google.com/docs/firestore/security/get-started)

## 🔄 Prochaines étapes

Une fois Firebase configuré :

1. ✅ Les données se synchronisent automatiquement
2. ✅ La migration des données locales est automatique
3. ✅ La synchronisation en temps réel est active
4. ✅ Le mode offline est supporté

Pour ajouter une UI d'authentification, vous pouvez créer des écrans de connexion/inscription qui utilisent `FirebaseAuthService`.





