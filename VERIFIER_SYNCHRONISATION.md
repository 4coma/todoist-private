# 🔍 Comment vérifier que les tâches sont synchronisées dans Firebase

## ✅ Méthode 1 : Vérifier dans Firebase Console

### Étapes :

1. **Allez sur** https://console.firebase.google.com/
2. **Sélectionnez votre projet** : `todoom-a0f98`
3. **Dans le menu de gauche**, cliquez sur **"Firestore Database"**
4. **Vous devriez voir** une structure comme :
   ```
   users/
     └── {userId}/
         └── todos/
             └── {todoId}/
                 ├── id: 1234567890
                 ├── title: "Ma tâche"
                 ├── description: "..."
                 ├── priority: "medium"
                 ├── isCompleted: false
                 ├── createdAt: Timestamp
                 └── updatedAt: Timestamp
   ```

### Comment trouver votre userId ?

- **Option 1** : Regardez dans les logs de l'app, vous devriez voir des messages avec l'ID utilisateur
- **Option 2** : Dans Firebase Console → Authentication → Users, vous verrez les utilisateurs anonymes

### Test rapide :

1. **Créez une nouvelle tâche** dans l'app
2. **Attendez 2-3 secondes**
3. **Actualisez la page Firestore** dans Firebase Console
4. **Vous devriez voir** la nouvelle tâche apparaître dans `users/{userId}/todos/`

## ✅ Méthode 2 : Vérifier dans les logs de l'app

Quand vous ajoutez une tâche, vous devriez voir dans les logs :

```
🟢 [TodoService] addTodo: ...
✅ FirebaseSyncService: Tâche {id} synchronisée
```

Si vous voyez une erreur, elle sera affichée avec :
```
❌ FirebaseSyncService: Erreur lors de la synchronisation de la tâche: ...
```

## ✅ Méthode 3 : Test en temps réel

1. **Ouvrez Firebase Console → Firestore Database** dans votre navigateur
2. **Créez une tâche** dans l'app
3. **Observez Firestore** - la tâche devrait apparaître **immédiatement** (sans rafraîchir la page)

## 🐛 Dépannage

### Les tâches n'apparaissent pas dans Firestore

**Vérifiez :**
1. ✅ Vous êtes authentifié (regardez les logs : `✅ Authentifié anonymement`)
2. ✅ Firebase Sync est initialisé (regardez les logs : `✅ Firebase Sync initialisé`)
3. ✅ Les règles Firestore sont correctes (copiées depuis `firestore.rules`)
4. ✅ Il n'y a pas d'erreurs dans les logs

### Erreur "Permission denied"

→ Vérifiez que les règles Firestore sont bien publiées dans Firebase Console

### Les logs ne montrent pas de synchronisation

→ Vérifiez que `FirebaseSyncService` est bien initialisé au démarrage








