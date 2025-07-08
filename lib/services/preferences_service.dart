import 'local_storage_service.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  final LocalStorageService _storage = LocalStorageService();

  // Initialisation (déjà fait par LocalStorageService)
  Future<void> initialize() async {
    // Le LocalStorageService est déjà initialisé dans main.dart
  }

  // === GESTION DES PRÉFÉRENCES GÉNÉRALES ===

  // Obtenir une préférence typée
  T? getPreference<T>(String key) {
    return _storage.getPreference<T>(key);
  }

  // Définir une préférence
  Future<void> setPreference<T>(String key, T value) async {
    await _storage.setPreference(key, value);
  }

  // Supprimer une préférence
  Future<void> removePreference(String key) async {
    await _storage.removePreference(key);
  }

  // === PRÉFÉRENCES D'AFFICHAGE ===

  // Afficher les descriptions
  bool get showDescriptions => getPreference<bool>('show_descriptions') ?? false;
  
  Future<void> setShowDescriptions(bool value) async {
    await setPreference('show_descriptions', value);
  }

  // Thème sélectionné
  String get selectedTheme => getPreference<String>('selected_theme') ?? 'blue';
  
  Future<void> setSelectedTheme(String themeName) async {
    await setPreference('selected_theme', themeName);
  }

  // Mode sombre
  bool get isDarkMode => getPreference<bool>('dark_mode') ?? false;
  
  Future<void> setDarkMode(bool value) async {
    await setPreference('dark_mode', value);
  }

  // === PRÉFÉRENCES DE TRI ===

  // Type de tri par défaut
  String get defaultSortType => getPreference<String>('default_sort_type') ?? 'dateAdded';
  
  Future<void> setDefaultSortType(String sortType) async {
    await setPreference('default_sort_type', sortType);
  }

  // Ordre de tri (ascendant/descendant)
  bool get sortAscending => getPreference<bool>('sort_ascending') ?? true;
  
  Future<void> setSortAscending(bool value) async {
    await setPreference('sort_ascending', value);
  }

  // === PRÉFÉRENCES DE NOTIFICATIONS ===

  // Notifications activées
  bool get notificationsEnabled => getPreference<bool>('notifications_enabled') ?? true;
  
  Future<void> setNotificationsEnabled(bool value) async {
    await setPreference('notifications_enabled', value);
  }

  // Rappels automatiques
  bool get autoReminders => getPreference<bool>('auto_reminders') ?? true;
  
  Future<void> setAutoReminders(bool value) async {
    await setPreference('auto_reminders', value);
  }

  // Heure de rappel par défaut (minutes avant l'échéance)
  int get defaultReminderMinutes => getPreference<int>('default_reminder_minutes') ?? 30;
  
  Future<void> setDefaultReminderMinutes(int minutes) async {
    await setPreference('default_reminder_minutes', minutes);
  }

  // === PRÉFÉRENCES DE TIMER ===

  // Timer automatique
  bool get autoTimer => getPreference<bool>('auto_timer') ?? false;
  
  Future<void> setAutoTimer(bool value) async {
    await setPreference('auto_timer', value);
  }

  // Pause automatique du timer
  bool get autoPauseTimer => getPreference<bool>('auto_pause_timer') ?? true;
  
  Future<void> setAutoPauseTimer(bool value) async {
    await setPreference('auto_pause_timer', value);
  }

  // Durée de pause automatique (secondes)
  int get autoPauseDuration => getPreference<int>('auto_pause_duration') ?? 300; // 5 minutes
  
  Future<void> setAutoPauseDuration(int seconds) async {
    await setPreference('auto_pause_duration', seconds);
  }

  // === PRÉFÉRENCES DE SAUVEGARDE ===

  // Sauvegarde automatique
  bool get autoSave => getPreference<bool>('auto_save') ?? true;
  
  Future<void> setAutoSave(bool value) async {
    await setPreference('auto_save', value);
  }

  // Fréquence de sauvegarde (secondes)
  int get saveFrequency => getPreference<int>('save_frequency') ?? 30;
  
  Future<void> setSaveFrequency(int seconds) async {
    await setPreference('save_frequency', seconds);
  }

  // === PRÉFÉRENCES D'INTERFACE ===

  // Animation des transitions
  bool get enableAnimations => getPreference<bool>('enable_animations') ?? true;
  
  Future<void> setEnableAnimations(bool value) async {
    await setPreference('enable_animations', value);
  }

  // Vibration
  bool get enableVibration => getPreference<bool>('enable_vibration') ?? true;
  
  Future<void> setEnableVibration(bool value) async {
    await setPreference('enable_vibration', value);
  }

  // Son des notifications
  bool get enableNotificationSound => getPreference<bool>('enable_notification_sound') ?? true;
  
  Future<void> setEnableNotificationSound(bool value) async {
    await setPreference('enable_notification_sound', value);
  }

  // === PRÉFÉRENCES DE DONNÉES ===

  // Taille maximale des données (MB)
  int get maxDataSize => getPreference<int>('max_data_size') ?? 100;
  
  Future<void> setMaxDataSize(int megabytes) async {
    await setPreference('max_data_size', megabytes);
  }

  // Compression des données
  bool get compressData => getPreference<bool>('compress_data') ?? false;
  
  Future<void> setCompressData(bool value) async {
    await setPreference('compress_data', value);
  }

  // === PRÉFÉRENCES DE SÉCURITÉ ===

  // Chiffrement des données
  bool get encryptData => getPreference<bool>('encrypt_data') ?? true;
  
  Future<void> setEncryptData(bool value) async {
    await setPreference('encrypt_data', value);
  }

  // Verrouillage par biométrie
  bool get biometricLock => getPreference<bool>('biometric_lock') ?? false;
  
  Future<void> setBiometricLock(bool value) async {
    await setPreference('biometric_lock', value);
  }

  // === PRÉFÉRENCES DE STATISTIQUES ===

  // Collecte de statistiques
  bool get collectStats => getPreference<bool>('collect_stats') ?? true;
  
  Future<void> setCollectStats(bool value) async {
    await setPreference('collect_stats', value);
  }

  // Partage anonyme des données
  bool get shareAnonymousData => getPreference<bool>('share_anonymous_data') ?? false;
  
  Future<void> setShareAnonymousData(bool value) async {
    await setPreference('share_anonymous_data', value);
  }

  // === MÉTHODES UTILITAIRES ===

  // Réinitialiser toutes les préférences
  Future<void> resetAllPreferences() async {
    final keys = [
      'show_descriptions',
      'selected_theme',
      'dark_mode',
      'default_sort_type',
      'sort_ascending',
      'notifications_enabled',
      'auto_reminders',
      'default_reminder_minutes',
      'auto_timer',
      'auto_pause_timer',
      'auto_pause_duration',
      'auto_save',
      'save_frequency',
      'enable_animations',
      'enable_vibration',
      'enable_notification_sound',
      'max_data_size',
      'compress_data',
      'encrypt_data',
      'biometric_lock',
      'collect_stats',
      'share_anonymous_data',
    ];

    for (final key in keys) {
      await removePreference(key);
    }
  }

  // Réinitialiser les préférences d'affichage
  Future<void> resetDisplayPreferences() async {
    final keys = [
      'show_descriptions',
      'selected_theme',
      'dark_mode',
      'default_sort_type',
      'sort_ascending',
      'enable_animations',
    ];

    for (final key in keys) {
      await removePreference(key);
    }
  }

  // Réinitialiser les préférences de notifications
  Future<void> resetNotificationPreferences() async {
    final keys = [
      'notifications_enabled',
      'auto_reminders',
      'default_reminder_minutes',
      'enable_vibration',
      'enable_notification_sound',
    ];

    for (final key in keys) {
      await removePreference(key);
    }
  }

  // Obtenir toutes les préférences
  Map<String, dynamic> getAllPreferences() {
    return _storage.preferences;
  }

  // Exporter les préférences
  Map<String, dynamic> exportPreferences() {
    return {
      'version': '1.0.0',
      'exportDate': DateTime.now().toIso8601String(),
      'preferences': getAllPreferences(),
    };
  }

  // Importer les préférences
  Future<void> importPreferences(Map<String, dynamic> data) async {
    try {
      final version = data['version'] as String?;
      if (version == null || !version.startsWith('1.0')) {
        throw Exception('Version de préférences non supportée: $version');
      }

      final preferences = data['preferences'] as Map<String, dynamic>?;
      if (preferences != null) {
        for (final entry in preferences.entries) {
          await setPreference(entry.key, entry.value);
        }
      }
    } catch (e) {
      throw Exception('Erreur lors de l\'import des préférences: $e');
    }
  }

  // Valider une préférence
  bool validatePreference(String key, dynamic value) {
    switch (key) {
      case 'show_descriptions':
      case 'dark_mode':
      case 'notifications_enabled':
      case 'auto_reminders':
      case 'auto_timer':
      case 'auto_pause_timer':
      case 'auto_save':
      case 'enable_animations':
      case 'enable_vibration':
      case 'enable_notification_sound':
      case 'compress_data':
      case 'encrypt_data':
      case 'biometric_lock':
      case 'collect_stats':
      case 'share_anonymous_data':
        return value is bool;
      
      case 'default_reminder_minutes':
      case 'auto_pause_duration':
      case 'save_frequency':
      case 'max_data_size':
        return value is int && value > 0;
      
      case 'selected_theme':
      case 'default_sort_type':
        return value is String && value.isNotEmpty;
      
      default:
        return true; // Accepter les autres types
    }
  }
} 