import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // Générer un ID valide pour les notifications (32-bit)
  int _generateNotificationId(int taskId) {
    // Utiliser l'ID de la tâche pour générer un ID de notification cohérent
    // Assurer que l'ID reste dans les limites 32-bit d'Android
    return (taskId % 1000000) + 1000; // IDs entre 1000 et 1000999
  }

  Future<void> initialize() async {
    // Initialiser timezone
    tz.initializeTimeZones();
    
    // Définir le timezone local
    tz.setLocalLocation(tz.getLocation('Europe/Paris'));

    // Configuration pour Android
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configuration pour Linux
    const LinuxInitializationSettings linuxSettings = 
        LinuxInitializationSettings(
          defaultActionName: 'Open notification',
        );

    // Configuration générale
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      linux: linuxSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Demander les permissions sur Android
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final bool? granted = await androidImplementation.requestNotificationsPermission();
      debugPrint('Permission accordée: $granted');
      
      // Note: Les permissions d'alarme exacte sont gérées automatiquement par le système
      debugPrint('Permissions de notification demandées');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapée: ${response.payload}');
    // Ici vous pouvez ajouter la logique pour ouvrir l'app ou une page spécifique
  }

  Future<void> scheduleTaskReminder({
    required int taskId, // ID de la tâche (peut être grand)
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      // Générer un ID valide pour la notification basé sur l'ID de la tâche
      final int notificationId = _generateNotificationId(taskId);
      
      // Annuler toute notification existante pour cette tâche
      await cancelNotification(notificationId);

      // Vérifier que la date est dans le futur
      if (scheduledDate.isBefore(DateTime.now())) {
        debugPrint('Date de notification dans le passé: $scheduledDate');
        return;
      }

      // Créer la notification
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'task_reminders',
        'Task Reminders',
        channelDescription: 'Notifications for task reminders',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails(
        actions: <LinuxNotificationAction>[
          LinuxNotificationAction(
            key: 'complete',
            label: 'Complete Task',
          ),
          LinuxNotificationAction(
            key: 'snooze',
            label: 'Snooze 15 min',
          ),
        ],
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        linux: linuxDetails,
      );

      // Convertir la date en TZDateTime
      final tz.TZDateTime scheduledTZDate = tz.TZDateTime.from(scheduledDate, tz.local);
      
      debugPrint('=== DEBUG TÂCHE PROGRAMMÉE ===');
      debugPrint('Tâche ID: $taskId, Notification ID: $notificationId');
      debugPrint('Date actuelle: ${DateTime.now().toString()}');
      debugPrint('Date programmée: ${scheduledDate.toString()}');
      debugPrint('TZDateTime programmée: ${scheduledTZDate.toString()}');
      debugPrint('Fuseau horaire: ${tz.local.name}');
      debugPrint('Délai: ${scheduledDate.difference(DateTime.now()).inMinutes} minutes');

      // Programmer la notification
      await _notifications.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledTZDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: 
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      
      debugPrint('✅ Notification programmée avec succès pour ID: $notificationId');
      debugPrint('=== FIN DEBUG TÂCHE ===');
    } catch (e) {
      debugPrint('Erreur lors de la programmation de la notification: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    try {
      // Vérifier que l'ID est dans la plage valide pour Android (32-bit)
      if (id > 2147483647 || id < -2147483648) {
        debugPrint('ID de notification invalide (trop grand) pour annulation: $id');
        return;
      }
      
      await _notifications.cancel(id);
      debugPrint('Notification annulée pour ID: $id');
    } catch (e) {
      debugPrint('Erreur lors de l\'annulation de la notification: $e');
    }
  }

  // Annuler la notification d'une tâche spécifique
  Future<void> cancelTaskNotification(int taskId) async {
    final int notificationId = _generateNotificationId(taskId);
    await cancelNotification(notificationId);
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      debugPrint('Toutes les notifications ont été annulées');
    } catch (e) {
      debugPrint('Erreur lors de l\'annulation de toutes les notifications: $e');
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      final notifications = await _notifications.pendingNotificationRequests();
      debugPrint('Notifications en attente: ${notifications.length}');
      for (final notification in notifications) {
        debugPrint('Notification en attente: ID=${notification.id}, Titre=${notification.title}');
      }
      return notifications;
    } catch (e) {
      debugPrint('Erreur lors de la récupération des notifications: $e');
      return [];
    }
  }

  // Vérifier l'état des permissions
  Future<void> checkPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final bool? notificationsEnabled = await androidImplementation.areNotificationsEnabled();
      
      debugPrint('Notifications activées: $notificationsEnabled');
      debugPrint('Permissions d\'alarme exacte demandées lors de l\'initialisation');
    }
  }

  // Méthode de test pour programmer une notification dans 1 minute
  Future<void> scheduleTestNotification() async {
    try {
      final int notificationId = 999;
      final DateTime now = DateTime.now();
      final DateTime scheduledDate = now.add(const Duration(minutes: 1));
      
      debugPrint('=== DEBUG NOTIFICATION PROGRAMMÉE ===');
      debugPrint('Date actuelle: ${now.toString()}');
      debugPrint('Date programmée: ${scheduledDate.toString()}');
      debugPrint('Fuseau horaire local: ${tz.local.name}');
      debugPrint('Délai: ${scheduledDate.difference(now).inSeconds} secondes');
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'test_scheduled_channel',
        'Test Scheduled Channel',
        channelDescription: 'Channel for test scheduled notifications',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      final tz.TZDateTime scheduledTZDate = tz.TZDateTime.from(scheduledDate, tz.local);
      debugPrint('TZDateTime programmée: ${scheduledTZDate.toString()}');
      
      await _notifications.zonedSchedule(
        notificationId,
        'Test Notification Programmé',
        'Cette notification a été programmée pour dans 1 minute',
        scheduledTZDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: 
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      
      debugPrint('✅ Notification de test programmée avec succès pour: ${scheduledTZDate.toString()}');
      debugPrint('=== FIN DEBUG ===');
    } catch (e) {
      debugPrint('❌ Erreur lors de la programmation de la notification de test: $e');
    }
  }

  // Méthode de test pour envoyer une notification immédiate
  Future<void> showTestNotification() async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'test_channel',
        'Test Channel',
        channelDescription: 'Channel for test notifications',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      await _notifications.show(
        999, // ID unique pour le test
        'Test Notification',
        'Ceci est une notification de test',
        details,
      );
      
      debugPrint('Notification de test envoyée');
    } catch (e) {
      debugPrint('Erreur lors de l\'envoi de la notification de test: $e');
    }
  }
} 