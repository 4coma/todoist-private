# ➕ Ajouter l'authentification anonyme dans Firebase

## 📋 Étapes détaillées

### 1. Dans Firebase Console → Authentication → Sign-in method

Vous voyez actuellement :
- **Email/Password** (Enabled)

### 2. Cliquez sur "Add new provider"

Le bouton bleu en haut à droite de la section "Sign-in providers"

### 3. Dans la liste déroulante, sélectionnez "Anonymous"

Vous verrez une liste de providers disponibles :
- Email/Password (déjà ajouté)
- **Anonymous** ← Sélectionnez celui-ci
- Google
- Facebook
- etc.

### 4. Activez Anonymous

Une fois "Anonymous" sélectionné :
- Une fenêtre s'ouvre
- **Activez le toggle** (Enable)
- **Cliquez sur "Save"**

### 5. Vérification

Vous devriez maintenant voir dans la liste :
- Email/Password (Enabled)
- **Anonymous (Enabled)** ← Nouveau

## ✅ Alternative : Utiliser Email/Password pour tester

Si vous ne trouvez pas "Anonymous" ou préférez utiliser Email/Password :

1. **Email/Password est déjà activé** ✅
2. **Créez un compte** dans l'app avec email/mot de passe
3. **La synchronisation fonctionnera** avec ce compte

Mais pour tester rapidement sans créer de compte, l'authentification anonyme est plus pratique.


