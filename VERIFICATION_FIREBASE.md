# 🔍 Vérification de la configuration Firebase

## ❓ Problème : Aucun log Firebase visible

Si vous ne voyez pas les logs Firebase (`✅ Firebase initialisé`), cela signifie que Firebase ne s'initialise pas correctement.

## 🔍 Vérifications à faire

### 1. Vérifier que `google-services.json` est présent

Le fichier doit être dans : `android/app/google-services.json`

**Vérifiez :**
```bash
ls -la android/app/google-services.json
```

### 2. Vérifier les plugins Gradle

**Fichier `android/settings.gradle`** doit contenir :
```gradle
plugins {
    ...
    id "com.google.gms.google-services" version "4.4.0" apply false
}
```

**Fichier `android/app/build.gradle`** doit contenir :
```gradle
plugins {
    ...
    id "com.google.gms.google-services"
}
```

### 3. Vérifier que Firebase est activé dans la console

1. Allez sur https://console.firebase.google.com/
2. Sélectionnez votre projet `todoom-a0f98`
3. Vérifiez que **Authentication** est activé
4. Vérifiez que **Firestore Database** est créé

### 4. Vérifier les logs au démarrage

Les logs Firebase apparaissent **au tout début** du démarrage de l'app, avant les autres logs.

**Cherchez dans les logs :**
- `✅ Firebase initialisé` (succès)
- `⚠️ Firebase non initialisé` (erreur)
- `✅ Authentifié anonymement` (si auth fonctionne)
- `⚠️ Erreur lors de l'authentification anonyme` (si auth échoue)

## 🐛 Erreurs courantes

### Erreur : "FirebaseApp not initialized"
→ `google-services.json` manquant ou mal placé

### Erreur : "Plugin not found"
→ Plugin Google Services non ajouté dans `settings.gradle`

### Erreur : "Permission denied"
→ Authentication ou Firestore non activés dans Firebase Console

### Aucune erreur mais pas de logs
→ Firebase s'initialise peut-être mais échoue silencieusement

## 🔧 Solution : Forcer les logs

Pour voir exactement ce qui se passe, modifiez temporairement `main.dart` :

```dart
// Initialiser Firebase
try {
  print('🔄 Tentative d\'initialisation Firebase...');
  await Firebase.initializeApp();
  print('✅ Firebase initialisé avec succès');
  debugPrint('✅ Firebase initialisé');
} catch (e, stackTrace) {
  print('❌ ERREUR Firebase: $e');
  print('❌ Stack trace: $stackTrace');
  debugPrint('⚠️ Firebase non initialisé (configuration manquante?): $e');
}
```

Les `print()` apparaîtront même si `debugPrint` ne fonctionne pas.

## 📋 Checklist de vérification

- [ ] `google-services.json` présent dans `android/app/`
- [ ] Plugin Google Services dans `settings.gradle`
- [ ] Plugin Google Services dans `app/build.gradle`
- [ ] Authentication activé dans Firebase Console
- [ ] Firestore créé dans Firebase Console
- [ ] Logs Firebase visibles au démarrage



