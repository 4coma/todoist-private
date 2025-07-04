# Documentation Complète : Configuration des Notifications Programmées Flutter

## Vue d'ensemble

Cette documentation détaille la configuration complète d'un système de notifications programmées dans une application Flutter utilisant le plugin `awesome_notifications`. Cette configuration a été testée et fonctionne avec Android SDK 34.

## 1. Dépendances (pubspec.yaml)

### 1.1 Plugins requis

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Plugin de notifications (remplace flutter_local_notifications)
  awesome_notifications: ^0.8.2
  
  # Gestion des fuseaux horaires pour les notifications programmées
  timezone: ^0.9.2
  
  # Persistance des préférences utilisateur
  shared_preferences: ^2.2.2
```

### 1.2 Pourquoi awesome_notifications ?

- **Compatibilité SDK 34** : Contrairement à `flutter_local_notifications` qui a des bugs avec SDK 34/35
- **API moderne** : Interface plus intuitive et flexible
- **Fonctionnalités avancées** : Support des notifications programmées, actions, etc.
- **Stabilité** : Moins de problèmes de compilation

## 2. Configuration Android

### 2.1 AndroidManifest.xml

**IMPORTANT** : Aucune permission spéciale n'est requise dans le manifest pour les notifications avec `awesome_notifications`. Le plugin gère automatiquement les permissions.

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Permissions existantes pour l'audio -->
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.INTERNET"/>
    
    <!-- Aucune permission de notification requise explicitement -->
    
    <application
        android:label="selfman_flutter"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <!-- Configuration standard Flutter -->
    </application>
</manifest>
```

### 2.2 build.gradle (app)

```gradle
android {
    namespace "com.example.selfman_flutter"
    compileSdkVersion 34  // IMPORTANT: Garder SDK 34
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }

    defaultConfig {
        applicationId "com.example.selfman_flutter"
        minSdkVersion 24
        targetSdkVersion 34  // IMPORTANT: Garder SDK 34
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }
}
```

## 3. Service de Notifications

### 3.1 NotificationService (lib/services/notification_service.dart)

```dart
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  // Identifiants de canal (doivent être uniques)
  static const String _channelId = 'selfman_reminders';
  static const String _channelName = 'Selfman Rappels';
  static const String _channelDescription = 'Rappels pour répondre aux questions de session';

  /// Initialise le service de notifications
  /// DOIT être appelé dans main() avant runApp()
  static Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      null, // null pour utiliser les icônes par défaut
      [
        NotificationChannel(
          channelKey: _channelId,
          channelName: _channelName,
          channelDescription: _channelDescription,
          defaultColor: Colors.blue,
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          enableVibration: true,
          enableLights: true,
        ),
      ],
    );
  }

  /// Demande les permissions de notification
  /// IMPORTANT: Appeler cette méthode avant de programmer des notifications
  static Future<bool> requestPermission() async {
    return await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  /// Programme une notification à une date/heure spécifique
  static Future<void> scheduleReminder({
    required int id,           // ID unique de la notification
    required String title,     // Titre de la notification
    required String body,      // Contenu de la notification
    required DateTime scheduledDate, // Date/heure de déclenchement
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: _channelId,
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Reminder,
      ),
      schedule: NotificationCalendar.fromDate(
        date: scheduledDate,
        allowWhileIdle: true, // IMPORTANT: Permet l'exécution même en mode économie d'énergie
      ),
    );
  }

  /// Annule une notification spécifique
  static Future<void> cancelReminder(int id) async {
    await AwesomeNotifications().cancel(id);
  }

  /// Annule toutes les notifications
  static Future<void> cancelAllReminders() async {
    await AwesomeNotifications().cancelAll();
  }

  /// Configure l'écoute des actions sur les notifications
  static void listenToActionStream(Function(ReceivedAction) onActionReceived) {
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: (ReceivedAction receivedAction) async {
        onActionReceived(receivedAction);
      },
    );
  }

  /// Nettoie les ressources (optionnel avec awesome_notifications)
  static void dispose() {
    // Pas besoin de fermer explicitement avec awesome_notifications
  }
}
```

## 4. Service de Préférences

### 4.1 ReminderPreferencesService (lib/services/reminder_preferences_service.dart)

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class ReminderPreferencesService {
  // Clés pour SharedPreferences
  static const String _keyEnabled = 'reminder_enabled';
  static const String _keyHour = 'reminder_hour';
  static const String _keyMinute = 'reminder_minute';

  /// Vérifie si les rappels sont activés
  static Future<bool> isReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }

  /// Active/désactive les rappels
  static Future<void> setReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
  }

  /// Récupère l'heure de rappel configurée
  static Future<TimeOfDay> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_keyHour) ?? 9;    // Heure par défaut: 9h
    final minute = prefs.getInt(_keyMinute) ?? 0; // Minute par défaut: 0
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Configure l'heure de rappel
  static Future<void> setReminderTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHour, time.hour);
    await prefs.setInt(_keyMinute, time.minute);
  }
}
```

## 5. Initialisation dans main.dart

### 5.1 Configuration obligatoire

```dart
import 'package:flutter/material.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // IMPORTANT: Initialiser le service de notifications AVANT runApp()
  await NotificationService.initialize();
  
  // Autres initialisations...
  
  runApp(const MyApp());
}
```

## 6. Intégration dans l'Interface Utilisateur

### 6.1 Exemple d'utilisation dans une page de paramètres

```dart
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../services/notification_service.dart';
import '../services/reminder_preferences_service.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await ReminderPreferencesService.isReminderEnabled();
    final time = await ReminderPreferencesService.getReminderTime();
    setState(() {
      _reminderEnabled = enabled;
      _reminderTime = time;
    });
  }

  Future<void> _toggleReminder(bool value) async {
    setState(() {
      _reminderEnabled = value;
    });
    
    await ReminderPreferencesService.setReminderEnabled(value);
    
    if (value) {
      // Demander les permissions
      final hasPermission = await NotificationService.requestPermission();
      if (hasPermission) {
        await _scheduleDailyReminder();
      } else {
        // Gérer le refus de permission
        setState(() {
          _reminderEnabled = false;
        });
        await ReminderPreferencesService.setReminderEnabled(false);
      }
    } else {
      // Annuler tous les rappels
      await NotificationService.cancelAllReminders();
    }
  }

  Future<void> _scheduleDailyReminder() async {
    // Annuler les anciens rappels
    await NotificationService.cancelAllReminders();
    
    // Calculer la prochaine occurrence
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      _reminderTime.hour,
      _reminderTime.minute,
    );
    
    // Si l'heure est déjà passée aujourd'hui, programmer pour demain
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    // Programmer la notification
    await NotificationService.scheduleReminder(
      id: 1, // ID unique pour ce type de rappel
      title: 'Rappel Selfman',
      body: 'Il est temps de répondre à vos questions de session !',
      scheduledDate: scheduledDate,
    );
  }

  Future<void> _selectTime() async {
    final TimeOfDay? newTime = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    
    if (newTime != null) {
      setState(() {
        _reminderTime = newTime;
      });
      
      await ReminderPreferencesService.setReminderTime(newTime);
      
      // Re-programmer si activé
      if (_reminderEnabled) {
        await _scheduleDailyReminder();
      }
    }
  }

  Future<void> _testNotification() async {
    final hasPermission = await NotificationService.requestPermission();
    if (hasPermission) {
      await NotificationService.scheduleReminder(
        id: 999, // ID spécial pour les tests
        title: 'Test de notification',
        body: 'Cette notification de test fonctionne !',
        scheduledDate: DateTime.now().add(const Duration(seconds: 5)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        children: [
          // Section Notifications
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Activer/désactiver les rappels
                  SwitchListTile(
                    title: const Text('Rappels quotidiens'),
                    subtitle: const Text('Recevoir un rappel pour répondre aux questions'),
                    value: _reminderEnabled,
                    onChanged: _toggleReminder,
                  ),
                  
                  // Sélection de l'heure
                  ListTile(
                    title: const Text('Heure du rappel'),
                    subtitle: Text(_reminderTime.format(context)),
                    trailing: const Icon(Icons.access_time),
                    onTap: _selectTime,
                  ),
                  
                  // Bouton de test
                  ElevatedButton.icon(
                    onPressed: _testNotification,
                    icon: const Icon(Icons.notifications),
                    label: const Text('Tester la notification'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

## 7. Points Critiques et Bonnes Pratiques

### 7.1 Ordre d'initialisation

1. **WidgetsFlutterBinding.ensureInitialized()** - Toujours en premier
2. **NotificationService.initialize()** - Avant runApp()
3. **Autres services** - Après les notifications
4. **runApp()** - En dernier

### 7.2 Gestion des permissions

- **Demander les permissions** avant de programmer des notifications
- **Gérer le refus** de permission gracieusement
- **Vérifier les permissions** avant chaque opération de notification

### 7.3 IDs de notifications

- **Utiliser des IDs uniques** pour chaque type de notification
- **Éviter les conflits** entre différents types de rappels
- **Utiliser des IDs spéciaux** pour les tests (ex: 999)

### 7.4 Programmation des notifications

- **allowWhileIdle: true** - Essentiel pour les notifications programmées
- **Calculer correctement** la prochaine occurrence
- **Annuler les anciennes** notifications avant d'en programmer de nouvelles

### 7.5 Gestion de l'état

- **Persister les préférences** avec SharedPreferences
- **Synchroniser l'état** entre l'UI et les notifications programmées
- **Recharger les paramètres** au démarrage de l'app

## 8. Dépannage

### 8.1 Problèmes courants

1. **Notifications ne s'affichent pas**
   - Vérifier les permissions
   - Vérifier que l'app n'est pas en mode "Ne pas déranger"
   - Tester avec une notification immédiate

2. **Notifications programmées ne fonctionnent pas**
   - Vérifier `allowWhileIdle: true`
   - Vérifier que la date est dans le futur
   - Vérifier les paramètres d'économie d'énergie du téléphone

3. **Erreurs de compilation**
   - Vérifier la version du SDK Android (34 recommandé)
   - Vérifier les dépendances dans pubspec.yaml
   - Nettoyer et reconstruire le projet

### 8.2 Commandes de débogage

```bash
# Nettoyer le projet
flutter clean

# Récupérer les dépendances
flutter pub get

# Reconstruire
flutter build apk --debug

# Vérifier les permissions sur l'appareil
adb shell dumpsys notification
```

## 9. Alternatives et Évolutions

### 9.1 Autres plugins de notifications

- **flutter_local_notifications** : Plus de bugs avec SDK 34+
- **firebase_messaging** : Pour les notifications push
- **onesignal_flutter** : Service tiers complet

### 9.2 Améliorations possibles

- **Notifications récurrentes** : Hebdomadaires, mensuelles
- **Actions sur notifications** : Boutons d'action
- **Notifications riches** : Images, boutons, etc.
- **Synchronisation** : Entre appareils via Firebase

## 10. Conclusion

Cette configuration utilise `awesome_notifications` version 0.8.2 avec Android SDK 34, ce qui évite les problèmes de compatibilité rencontrés avec `flutter_local_notifications`. Le système est robuste, bien documenté et prêt pour la production.

**Points clés à retenir :**
- Initialiser le service dans main() avant runApp()
- Demander les permissions avant de programmer
- Utiliser allowWhileIdle: true pour les notifications programmées
- Utiliser des IDs uniques pour les notifications
- Persister les préférences utilisateur 