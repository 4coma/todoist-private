import 'package:flutter/foundation.dart';
import 'firebase_auth_service.dart';
import 'firebase_sync_service.dart';
import 'local_storage_service.dart';
import 'preferences_service.dart';
import 'todo_service.dart';
import 'project_service.dart';

/// Service de migration des données locales vers Firebase
class FirebaseMigrationService {
  static final FirebaseMigrationService _instance = FirebaseMigrationService._internal();
  factory FirebaseMigrationService() => _instance;
  FirebaseMigrationService._internal();

  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirebaseSyncService _syncService = FirebaseSyncService();
  final LocalStorageService _localStorage = LocalStorageService();
  final PreferencesService _preferencesService = PreferencesService();
  final TodoService _todoService = TodoService();
  final ProjectService _projectService = ProjectService();

  /// Vérifier si la migration a déjà été effectuée
  Future<bool> hasMigrated() async {
    return await _preferencesService.getPreference<bool>('firebase_migrated') ?? false;
  }

  /// Marquer la migration comme effectuée
  Future<void> markAsMigrated() async {
    await _preferencesService.setPreference('firebase_migrated', true);
    debugPrint('✅ FirebaseMigrationService: Migration marquée comme effectuée');
  }

  /// Migrer toutes les données locales vers Firebase
  Future<void> migrateAllData() async {
    // Vérifier l'authentification
    if (!_authService.isAuthenticated) {
      throw Exception('Vous devez être connecté pour migrer les données');
    }

    // Vérifier si déjà migré
    if (await hasMigrated()) {
      debugPrint('ℹ️ FirebaseMigrationService: Données déjà migrées');
      return;
    }

    try {
      debugPrint('🔄 FirebaseMigrationService: Début de la migration...');
      debugPrint('==========================================');

      // 1. Migrer les projets (doivent être migrés en premier)
      await _migrateProjects();
      debugPrint('');

      // 2. Migrer les tâches
      await _migrateTodos();
      debugPrint('');

      // 3. Migrer les préférences
      await _migratePreferences();
      debugPrint('');

      // 4. Migrer les données de timer
      await _migrateTimerData();
      debugPrint('');

      // 5. Marquer comme migré
      await markAsMigrated();

      debugPrint('==========================================');
      debugPrint('✅ FirebaseMigrationService: Migration terminée avec succès');
      debugPrint('==========================================');

      // 6. Démarrer la synchronisation automatique
      await _syncService.initialize();
    } catch (e) {
      debugPrint('❌ FirebaseMigrationService: Erreur lors de la migration: $e');
      rethrow;
    }
  }

  /// Migrer les projets
  Future<void> _migrateProjects() async {
    try {
      final projects = _projectService.projects;
      debugPrint('📦 FirebaseMigrationService: Migration de ${projects.length} projets...');

      if (projects.isEmpty) {
        debugPrint('ℹ️ FirebaseMigrationService: Aucun projet à migrer');
        return;
      }

      int successCount = 0;
      for (final project in projects) {
        try {
          await _syncService.syncProject(project);
          successCount++;
          debugPrint('   ✅ Projet migré: "${project.name}" (ID: ${project.id})');
        } catch (e) {
          debugPrint('   ❌ Erreur lors de la migration du projet "${project.name}": $e');
        }
      }

      debugPrint('✅ FirebaseMigrationService: $successCount/${projects.length} projets migrés');
    } catch (e) {
      debugPrint('❌ FirebaseMigrationService: Erreur lors de la migration des projets: $e');
      rethrow;
    }
  }

  /// Migrer les tâches
  Future<void> _migrateTodos() async {
    try {
      final todos = _todoService.todos;
      print('📋 FirebaseMigrationService: Migration de ${todos.length} tâches...');
      debugPrint('📋 FirebaseMigrationService: Migration de ${todos.length} tâches...');

      if (todos.isEmpty) {
        print('ℹ️ FirebaseMigrationService: Aucune tâche à migrer');
        debugPrint('ℹ️ FirebaseMigrationService: Aucune tâche à migrer');
        return;
      }

      int successCount = 0;
      int batchSize = 50; // Traiter par lots pour éviter les limites

      for (int i = 0; i < todos.length; i += batchSize) {
        final batch = todos.skip(i).take(batchSize).toList();
        
        for (final todo in batch) {
          try {
            print('   🔄 Migration de la tâche "${todo.title}" (ID: ${todo.id})...');
            await _syncService.syncTodo(todo);
            successCount++;
            if (successCount % 10 == 0) {
              print('   📊 $successCount/${todos.length} tâches migrées...');
              debugPrint('   📊 $successCount/${todos.length} tâches migrées...');
            }
          } catch (e, stackTrace) {
            print('   ❌ ERREUR lors de la migration de la tâche "${todo.title}": $e');
            print('   ❌ Stack trace: $stackTrace');
            debugPrint('   ❌ Erreur lors de la migration de la tâche "${todo.title}": $e');
          }
        }
      }

      print('✅ FirebaseMigrationService: $successCount/${todos.length} tâches migrées');
      debugPrint('✅ FirebaseMigrationService: $successCount/${todos.length} tâches migrées');
    } catch (e, stackTrace) {
      print('❌ FirebaseMigrationService: ERREUR lors de la migration des tâches: $e');
      print('❌ Stack trace: $stackTrace');
      debugPrint('❌ FirebaseMigrationService: Erreur lors de la migration des tâches: $e');
      rethrow;
    }
  }
  
  /// Forcer la synchronisation de toutes les tâches existantes (utile pour réparer)
  Future<void> forceSyncAllTodos() async {
    if (!_authService.isAuthenticated) {
      throw Exception('Vous devez être connecté pour synchroniser les tâches');
    }

    try {
      print('🔄 FirebaseMigrationService: Synchronisation forcée de toutes les tâches...');
      final todos = _todoService.todos;
      print('📋 ${todos.length} tâches à synchroniser...');

      int successCount = 0;
      for (final todo in todos) {
        try {
          await _syncService.syncTodo(todo);
          successCount++;
          if (successCount % 50 == 0) {
            print('   📊 $successCount/${todos.length} tâches synchronisées...');
          }
        } catch (e) {
          print('   ❌ Erreur lors de la synchronisation de la tâche "${todo.title}": $e');
        }
      }

      print('✅ FirebaseMigrationService: $successCount/${todos.length} tâches synchronisées avec succès');
    } catch (e) {
      print('❌ FirebaseMigrationService: Erreur lors de la synchronisation forcée: $e');
      rethrow;
    }
  }

  /// Migrer les préférences
  Future<void> _migratePreferences() async {
    try {
      final preferences = _preferencesService.getAllPreferences();
      debugPrint('⚙️ FirebaseMigrationService: Migration de ${preferences.length} préférences...');

      if (preferences.isEmpty) {
        debugPrint('ℹ️ FirebaseMigrationService: Aucune préférence à migrer');
        return;
      }

      // Exclure la préférence de migration elle-même
      final prefsToMigrate = Map<String, dynamic>.from(preferences);
      prefsToMigrate.remove('firebase_migrated');

      if (prefsToMigrate.isEmpty) {
        debugPrint('ℹ️ FirebaseMigrationService: Aucune préférence à migrer (hors métadonnées)');
        return;
      }

      await _syncService.syncPreferences();
      debugPrint('✅ FirebaseMigrationService: Préférences migrées');
    } catch (e) {
      debugPrint('❌ FirebaseMigrationService: Erreur lors de la migration des préférences: $e');
      rethrow;
    }
  }

  /// Migrer les données de timer
  Future<void> _migrateTimerData() async {
    try {
      final timerData = _localStorage.timerData;
      debugPrint('⏱️ FirebaseMigrationService: Migration des données de timer...');

      if (timerData.isEmpty) {
        debugPrint('ℹ️ FirebaseMigrationService: Aucune donnée de timer à migrer');
        return;
      }

      await _syncService.syncTimerData();
      debugPrint('✅ FirebaseMigrationService: Données de timer migrées');
    } catch (e) {
      debugPrint('❌ FirebaseMigrationService: Erreur lors de la migration des données de timer: $e');
      rethrow;
    }
  }

  /// Obtenir des statistiques sur les données à migrer
  Map<String, int> getMigrationStats() {
    return {
      'todos': _todoService.todos.length,
      'projects': _projectService.projects.length,
      'preferences': _preferencesService.getAllPreferences().length,
      'timer_data': _localStorage.timerData.length,
    };
  }

  /// Vérifier si des données existent à migrer
  bool hasDataToMigrate() {
    final stats = getMigrationStats();
    return stats['todos']! > 0 ||
        stats['projects']! > 0 ||
        stats['preferences']! > 0 ||
        stats['timer_data']! > 0;
  }

  /// Réinitialiser le statut de migration (pour tester)
  Future<void> resetMigrationStatus() async {
    await _preferencesService.removePreference('firebase_migrated');
    debugPrint('🔄 FirebaseMigrationService: Statut de migration réinitialisé');
  }
}



