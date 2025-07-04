import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  // Identifiants de canal (doivent être uniques)
  static const String _channelId = 'todo_reminders';
  static const String _channelName = 'Todo Rappels';
  static const String _channelDescription = 'Rappels pour les tâches à faire';

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
    debugPrint('🔍 === PROGRAMMATION RAPPEL AVEC AWESOME_NOTIFICATIONS ===');
    debugPrint('🔍 ID: $id, Titre: $title, Date: $scheduledDate');
    
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
    
    debugPrint('✅ Rappel programmé avec succès pour ID: $id');
    debugPrint('🔍 === FIN PROGRAMMATION RAPPEL ===');
  }

  /// Annule une notification spécifique
  static Future<void> cancelReminder(int id) async {
    await AwesomeNotifications().cancel(id);
    debugPrint('Notification annulée pour ID: $id');
  }

  /// Annule toutes les notifications
  static Future<void> cancelAllReminders() async {
    await AwesomeNotifications().cancelAll();
    debugPrint('Toutes les notifications ont été annulées');
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

  // Générer un ID valide pour les notifications (32-bit)
  static int _generateNotificationId(int taskId) {
    // Utiliser l'ID de la tâche pour générer un ID de notification cohérent
    // Assurer que l'ID reste dans les limites 32-bit d'Android
    return (taskId % 1000000) + 1000; // IDs entre 1000 et 1000999
  }

  // Méthode de compatibilité avec l'ancien code
  static Future<void> scheduleTaskReminder({
    required int taskId,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    // Générer un ID valide pour la notification basé sur l'ID de la tâche
    final int notificationId = _generateNotificationId(taskId);
    
    await scheduleReminder(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
    );
  }

  // Méthode de compatibilité avec l'ancien code
  static Future<void> cancelTaskNotification(int taskId) async {
    final int notificationId = _generateNotificationId(taskId);
    await cancelReminder(notificationId);
  }

  // Méthode de test pour envoyer une notification immédiate
  static Future<void> showTestNotification() async {
    try {
      debugPrint('🔍 === TEST NOTIFICATION IMMÉDIATE ===');
      
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 999,
          channelKey: _channelId,
          title: 'Test Notification',
          body: 'Ceci est une notification de test',
          notificationLayout: NotificationLayout.Default,
        ),
      );
      
      debugPrint('✅ Notification de test envoyée');
      debugPrint('🔍 === FIN TEST IMMÉDIAT ===');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'envoi de la notification de test: $e');
    }
  }

  // Méthode de test pour programmer une notification dans 10 secondes
  static Future<void> scheduleQuickTestNotification() async {
    try {
      final DateTime scheduledDate = DateTime.now().add(const Duration(seconds: 10));
      
      debugPrint('🔍 === TEST RAPIDE NOTIFICATION PROGRAMMÉE ===');
      debugPrint('🔍 Date actuelle: ${DateTime.now().toString()}');
      debugPrint('🔍 Date programmée: ${scheduledDate.toString()}');
      debugPrint('🔍 Délai: 10 secondes');
      
      await scheduleReminder(
        id: 888,
        title: 'Test Rapide - 10 secondes',
        body: 'Cette notification devrait apparaître dans 10 secondes',
        scheduledDate: scheduledDate,
      );
      
      debugPrint('✅ Test rapide programmé avec succès');
      debugPrint('🔍 === FIN TEST RAPIDE ===');
    } catch (e) {
      debugPrint('❌ Erreur lors du test rapide: $e');
    }
  }

  // Vérifier l'état des permissions
  static Future<void> checkPermissions() async {
    debugPrint('🔍 === ÉTAT DES PERMISSIONS ===');
    
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    debugPrint('🔍 Notifications autorisées: $isAllowed');
    
    if (!isAllowed) {
      debugPrint('❌ Les notifications ne sont pas autorisées');
      debugPrint('L\'utilisateur doit les activer dans les paramètres système');
    } else {
      debugPrint('✅ Toutes les permissions sont accordées');
    }
    
    debugPrint('🔍 === FIN ÉTAT DES PERMISSIONS ===');
  }
} 