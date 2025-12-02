# 🧪 Test de la synchronisation Firebase

## ✅ Étape 1 : Vérifier que Firebase est initialisé

1. **Lancez l'app** et regardez les logs
2. **Vérifiez** que vous voyez : `✅ Firebase initialisé`

## ✅ Étape 2 : Se connecter à Firebase (Auth anonyme pour test)

Pour tester rapidement, ajoutez temporairement ce code dans `main.dart` après l'initialisation Firebase (ligne ~50) :

```dart
// Test d'authentification anonyme
try {
  final authService = FirebaseAuthService();
  if (!authService.isAuthenticated) {
    await authService.signInAnonymously();
    debugPrint('✅ Authentifié anonymement');
    
    // Initialiser la synchronisation
    final syncService = FirebaseSyncService();
    await syncService.initialize();
    debugPrint('✅ Synchronisation initialisée');
  }
} catch (e) {
  debugPrint('❌ Erreur auth: $e');
}
```

## ✅ Étape 3 : Vérifier la synchronisation

### Test 1 : Créer une tâche
1. **Créez une nouvelle tâche** dans l'app
2. **Attendez quelques secondes** (la synchronisation se fait en arrière-plan)
3. **Allez dans Firebase Console → Firestore Database**
4. **Vérifiez** que vous voyez :
   ```
   users/
     └── {userId}/
         └── todos/
             └── {todoId}/
                 ├── title: "..."
                 ├── description: "..."
                 └── ...
   ```

### Test 2 : Modifier une tâche
1. **Modifiez une tâche existante** (titre, description, etc.)
2. **Attendez quelques secondes**
3. **Vérifiez dans Firestore** que les modifications sont présentes

### Test 3 : Créer un projet
1. **Créez un nouveau projet** dans l'app
2. **Attendez quelques secondes**
3. **Vérifiez dans Firestore** :
   ```
   users/
     └── {userId}/
         └── projects/
             └── {projectId}/
                 ├── name: "..."
                 ├── color: ...
                 └── ...
   ```

### Test 4 : Vérifier les préférences
1. **Changez une préférence** (thème, etc.)
2. **Attendez quelques secondes**
3. **Vérifiez dans Firestore** :
   ```
   users/
     └── {userId}/
         └── preferences/
             └── preferences/
                 └── {key: value}
   ```

## ✅ Étape 4 : Vérifier la migration automatique

Si vous avez des données locales qui n'ont pas encore été migrées :

1. **Connectez-vous à Firebase** (voir Étape 2)
2. **Relancez l'app**
3. **Vérifiez les logs** : `🔄 Données locales détectées, migration automatique...`
4. **Vérifiez dans Firestore** que toutes vos données sont présentes

## ✅ Étape 5 : Test de synchronisation en temps réel

1. **Ouvrez Firebase Console → Firestore** dans votre navigateur
2. **Créez une tâche dans l'app**
3. **Observez Firestore** — la tâche devrait apparaître **immédiatement** (sans rafraîchir)

## 🆘 Dépannage

### Les données ne se synchronisent pas

**Vérifiez :**
1. ✅ Firebase est initialisé (`✅ Firebase initialisé` dans les logs)
2. ✅ Vous êtes authentifié (`FirebaseAuthService().isAuthenticated` retourne `true`)
3. ✅ Firestore est créé dans Firebase Console
4. ✅ Les règles Firestore sont configurées (copiées depuis `firestore.rules`)
5. ✅ Authentication est activé dans Firebase Console

**Logs à vérifier :**
- `✅ Firebase Sync initialisé pour l'utilisateur connecté`
- `✅ Tâche X synchronisée` (après création/modification)
- `✅ Projet X synchronisé` (après création/modification)

### Erreur "Permission denied"

→ Vérifiez que les règles Firestore sont bien publiées dans Firebase Console

### Erreur "User not authenticated"

→ Vérifiez que l'authentification anonyme ou email/password fonctionne

## 📊 Checklist de vérification

- [ ] Firebase initialisé
- [ ] Authentification fonctionnelle
- [ ] Synchronisation initialisée
- [ ] Création de tâche → visible dans Firestore
- [ ] Modification de tâche → visible dans Firestore
- [ ] Création de projet → visible dans Firestore
- [ ] Modification de préférence → visible dans Firestore
- [ ] Synchronisation en temps réel fonctionnelle
- [ ] Migration automatique fonctionnelle (si données locales)

## 🎯 Prochaines étapes après vérification

Une fois la synchronisation vérifiée :
1. ✅ Créer une UI d'authentification (optionnel mais recommandé)
2. ✅ Tester sur plusieurs appareils
3. ✅ Vérifier le mode offline


