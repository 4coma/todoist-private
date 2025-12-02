# 📦 Migration des données existantes vers Firebase

## ⚠️ Problème

Les données de l'**app installée (release)** et celles du **mode debug** sont **séparées**. Quand vous lancez en mode debug, vous ne voyez pas les données de l'app installée.

## ✅ Solution : 2 méthodes

---

## 🎯 Méthode 1 : Export/Import (RECOMMANDÉE - 5 minutes)

### Étape 1 : Exporter depuis l'app installée

1. **Ouvrez l'app installée** sur votre téléphone (la version release avec vos données)
2. **Allez dans les Paramètres** de l'app
3. **Trouvez la section "Export/Import"** ou "Sauvegarde"
4. **Cliquez sur "Exporter"** ou "Sauvegarder"
5. **Sauvegardez le fichier JSON** sur votre téléphone (dans Downloads ou Documents)

### Étape 2 : Importer dans l'app debug

1. **Lancez l'app en mode debug** (celle que vous développez)
2. **Allez dans les Paramètres**
3. **Trouvez "Import"** ou "Restaurer"
4. **Sélectionnez le fichier JSON** que vous avez exporté
5. **Confirmez l'import**

### Étape 3 : Synchroniser avec Firebase

1. **Connectez-vous à Firebase** (auth anonyme ou email/password)
2. **La migration automatique se déclenchera** au prochain lancement
3. **Vos données seront synchronisées** vers Firebase

---

## 🎯 Méthode 2 : Copie directe des SharedPreferences (AVANCÉE)

Si vous avez accès ADB, vous pouvez copier directement les données :

### Étape 1 : Exporter les SharedPreferences de l'app release

```bash
# Trouver le package name de l'app release
adb shell pm list packages | grep todo

# Exporter les SharedPreferences
adb shell run-as com.todoom.app cp -r /data/data/com.todoom.app/shared_prefs /sdcard/todo_backup/
adb pull /sdcard/todo_backup /tmp/todo_backup
```

### Étape 2 : Importer dans l'app debug

```bash
# Package name de l'app debug (généralement le même)
adb push /tmp/todo_backup/shared_prefs /sdcard/todo_restore/
adb shell run-as com.todoom.app cp -r /sdcard/todo_restore/shared_prefs /data/data/com.todoom.app/
```

⚠️ **Attention** : Cette méthode nécessite que l'app soit en mode debug et que vous ayez les permissions ADB.

---

## 🎯 Méthode 3 : Utiliser la même signature (POUR PRODUCTION)

Pour que l'app release et debug partagent les mêmes données, elles doivent avoir la **même signature**. Mais en développement, c'est rarement le cas.

**Solution pour la production** :
- Quand vous publierez l'app avec Firebase, les utilisateurs qui ont déjà l'app verront leurs données migrées automatiquement
- La migration se fera au premier lancement après la mise à jour

---

## 📋 Checklist de migration

### Depuis l'app installée (release)
- [ ] Exporter les données (JSON)
- [ ] Vérifier que le fichier contient bien toutes les données

### Dans l'app debug
- [ ] Importer le fichier JSON
- [ ] Vérifier que les données sont bien présentes
- [ ] Se connecter à Firebase (auth anonyme ou email)
- [ ] Vérifier que la migration se déclenche
- [ ] Vérifier dans Firebase Console que les données sont synchronisées

---

## 🔍 Vérification

### Vérifier que les données sont bien importées

Dans l'app debug, après l'import :
- Vérifiez que vous voyez vos tâches
- Vérifiez que vous voyez vos projets
- Vérifiez que les préférences sont conservées

### Vérifier la synchronisation Firebase

1. **Dans Firebase Console → Firestore Database**
2. **Vérifiez la structure** :
   ```
   users/
     └── {userId}/
         ├── todos/
         │   └── {todoId}/
         ├── projects/
         │   └── {projectId}/
         ├── preferences/
         └── timer_data/
   ```
3. **Vérifiez que vos données sont présentes**

---

## 🆘 Dépannage

### Les données ne s'importent pas
- Vérifiez le format du fichier JSON
- Vérifiez les logs pour les erreurs
- Essayez d'exporter à nouveau depuis l'app release

### La migration Firebase ne se déclenche pas
- Vérifiez que vous êtes connecté à Firebase
- Vérifiez les logs : `🔄 Données locales détectées, migration automatique...`
- Vérifiez que `hasDataToMigrate()` retourne `true`

### Les données ne se synchronisent pas
- Vérifiez que Firestore est bien créé
- Vérifiez que les règles Firestore sont configurées
- Vérifiez les logs pour les erreurs de synchronisation

---

## 💡 Astuce

**Pour éviter ce problème à l'avenir** :
- Utilisez toujours la même signature pour release et debug (en production)
- Ou testez directement sur l'app release installée (build release et installez-la)

---

## 🎯 Prochaines étapes

Une fois les données migrées :
1. ✅ Vos données sont dans Firebase
2. ✅ Elles se synchroniseront automatiquement
3. ✅ Vous pouvez utiliser l'app sur plusieurs appareils
4. ✅ Les données seront sauvegardées dans le cloud


