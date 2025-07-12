# Rapport d'erreur : Notifications non fonctionnelles en mode Release

## Résumé du problème
Les notifications avec `awesome_notifications` fonctionnent correctement en mode debug mais échouent silencieusement en mode release sur Android.

## Détails techniques

### Environnement
- **Flutter** : Version stable
- **Platform** : Android
- **Plugin** : awesome_notifications
- **Mode** : Release (problème) vs Debug (fonctionne)

### Symptômes observés
1. **Mode Debug** : Notifications programmées et affichées correctement
2. **Mode Release** : Aucune notification n'apparaît, même si le code d'initialisation s'exécute sans erreur

### Logs observés
```
# Mode Debug (fonctionne)
I/flutter: 🔍 === DÉBUT PROGRAMMATION RAPPEL ===
I/flutter: 🔍 Payload: {taskId: 1752324916992}
D/Android: [Awesome Notifications](23038): Scheduled created (NotificationScheduler:228)
I/flutter: ✅ Rappel programmé avec succès pour ID: 917992

# Mode Release (ne fonctionne pas)
# Aucun log de notification visible
```

## Causes possibles

### 1. Problème de permissions
En mode release, les permissions peuvent être gérées différemment :
- Permissions de notification non accordées
- Permissions de réveil d'écran manquantes
- Permissions de planification de tâches en arrière-plan

### 2. Optimisations du compilateur
Les optimisations en mode release peuvent :
- Supprimer du code considéré comme "mort"
- Modifier l'ordre d'initialisation des plugins
- Désactiver certaines fonctionnalités de débogage nécessaires

### 3. Configuration Android
- **ProGuard/R8** : Obfuscation du code qui peut affecter les plugins
- **Manifest** : Permissions ou configurations spécifiques manquantes
- **Build variants** : Différences de configuration entre debug et release

### 4. Timing d'initialisation
En mode release, l'initialisation peut être plus rapide et le plugin peut ne pas être prêt quand les notifications sont programmées.

## Solutions à tester

### 1. Vérification des permissions
```dart
// Ajouter une vérification explicite des permissions
await AwesomeNotifications().requestPermissionToSendNotifications();
```

### 2. Configuration ProGuard
Ajouter dans `android/app/proguard-rules.pro` :
```pro
-keep class me.carda.awesome_notifications.** { *; }
-keep class me.carda.awesome_notifications.core.** { *; }
```

### 3. Délai d'initialisation
```dart
// Ajouter un délai avant la programmation
await Future.delayed(Duration(milliseconds: 500));
```

### 4. Vérification du manifest
S'assurer que `android/app/src/main/AndroidManifest.xml` contient :
```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
```

### 5. Logs détaillés en release
Activer les logs même en release pour diagnostiquer :
```dart
if (kDebugMode || kReleaseMode) {
  print("🔍 Debug notification scheduling...");
}
```

## Étapes de reproduction
1. Build en mode debug : `flutter build apk --debug`
2. Installer et tester les notifications → ✅ Fonctionne
3. Build en mode release : `flutter build apk --release`
4. Installer et tester les notifications → ❌ Ne fonctionne pas

## Impact
- **Utilisateur** : Ne reçoit pas les rappels de tâches
- **Fonctionnalité** : Système de notifications inutilisable en production
- **UX** : Perte de fonctionnalité critique pour une app de todo

## Priorité
**HAUTE** - Fonctionnalité critique pour l'expérience utilisateur

## Prochaines étapes
1. Tester les solutions proposées une par une
2. Ajouter des logs détaillés en mode release
3. Vérifier la configuration Android
4. Considérer une alternative si le problème persiste

---
*Rapport généré le $(date)* 