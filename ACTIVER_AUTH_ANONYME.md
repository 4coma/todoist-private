# 🔓 Activer l'authentification anonyme dans Firebase

## ❌ Erreur actuelle

```
admin-restricted-operation - This operation is restricted to administrators only.
```

Cela signifie que l'authentification anonyme n'est pas activée dans votre projet Firebase.

## ✅ Solution : Activer l'authentification anonyme

### Étapes dans Firebase Console

1. **Allez sur** https://console.firebase.google.com/
2. **Sélectionnez votre projet** : `todoom-a0f98`
3. **Dans le menu de gauche**, cliquez sur **"Authentication"**
4. **Cliquez sur l'onglet "Sign-in method"** (en haut)
5. **Trouvez "Anonymous"** dans la liste des providers
6. **Cliquez sur "Anonymous"**
7. **Activez le toggle** (Enable)
8. **Cliquez sur "Save"**

## ✅ Vérification

Après activation, relancez l'app. Vous devriez voir dans les logs :

```
✅ Authentifié anonymement avec succès
✅ Firebase Sync initialisé avec succès
```

## 🔄 Alternative : Utiliser Email/Password

Si vous préférez ne pas utiliser l'authentification anonyme, vous pouvez :

1. **Activer Email/Password** dans Firebase Console (même procédure)
2. **Créer un compte** dans l'app avec email/mot de passe
3. **La synchronisation fonctionnera** avec ce compte

Mais pour tester rapidement, l'authentification anonyme est la plus simple.







