import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_storage_service.dart';
import 'todo_service.dart';
import 'project_service.dart';
import 'preferences_service.dart';
import '../models/todo_item.dart';
import '../models/project.dart';

// Résultat de la migration
class MigrationResult {
  int migratedTodos = 0;
  int migratedProjects = 0;
  int migratedPreferences = 0;
  int errors = 0;
  bool hasErrors = false;
  String? errorMessage;
  
  bool get isSuccessful => !hasErrors && errors == 0;
  
  @override
  String toString() {
    return 'MigrationResult{migratedTodos: $migratedTodos, migratedProjects: $migratedProjects, migratedPreferences: $migratedPreferences, errors: $errors, hasErrors: $hasErrors}';
  }
}

class DataMigrationService {
  static final DataMigrationService _instance = DataMigrationService._internal();
  factory DataMigrationService() => _instance;
  DataMigrationService._internal();

  final LocalStorageService _storage = LocalStorageService();
  final TodoService _todoService = TodoService();
  final ProjectService _projectService = ProjectService();
  final PreferencesService _preferencesService = PreferencesService();

  // Clés des anciens SharedPreferences
  static const String _oldTodosKey = 'todos';
  static const String _oldProjectsKey = 'projects';

  // Vérifier si une migration est nécessaire
  Future<bool> needsMigration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Vérifier s'il y a des données dans l'ancien format
      final hasOldTodos = prefs.getString(_oldTodosKey) != null;
      final hasOldProjects = prefs.getString(_oldProjectsKey) != null;
      
      // Vérifier s'il y a des données dans le nouveau format
      final hasNewTodos = prefs.getString('local_todos') != null;
      final hasNewProjects = prefs.getString('local_projects') != null;
      
      // Migration nécessaire si on a des anciennes données mais pas de nouvelles
      return (hasOldTodos || hasOldProjects) && (!hasNewTodos && !hasNewProjects);
    } catch (e) {
      print('❌ Erreur lors de la vérification de migration: $e');
      return false;
    }
  }

  // Effectuer la migration complète
  Future<MigrationResult> migrateAllData() async {
    print('🔄 DataMigrationService: Début de la migration des données...');
    
    final result = MigrationResult();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Migration des projets
      await _migrateProjects(prefs, result);
      
      // 2. Migration des tâches
      await _migrateTodos(prefs, result);
      
      // 3. Migration des préférences
      await _migratePreferences(prefs, result);
      
      // 4. Sauvegarder toutes les données migrées
      await _storage.saveAllData();
      
      print('✅ DataMigrationService: Migration terminée avec succès');
      print('📊 Résultats: $result');
      
      return result;
    } catch (e) {
      result.hasErrors = true;
      result.errorMessage = e.toString();
      print('❌ DataMigrationService: Erreur lors de la migration: $e');
      return result;
    }
  }

  // Migration des projets
  Future<void> _migrateProjects(SharedPreferences prefs, MigrationResult result) async {
    try {
      final projectsJson = prefs.getString(_oldProjectsKey);
      if (projectsJson != null && projectsJson.isNotEmpty) {
        print('📝 DataMigrationService: Migration des projets...');
        
        final List<dynamic> projectsList = jsonDecode(projectsJson);
        for (final projectMap in projectsList) {
          try {
            final project = Project.fromMap(projectMap as Map<String, dynamic>);
            
                    // Vérifier si le projet n'existe pas déjà
        final existingProject = _projectService.getProject(project.id);
        if (existingProject == null) {
          await _projectService.addProject(project);
          result.migratedProjects++;
          print('   ✅ Projet migré: "${project.name}"');
        } else {
          print('   ⚠️ Projet déjà existant, ignoré: "${project.name}"');
        }
          } catch (e) {
            print('   ❌ Erreur lors de la migration d\'un projet: $e');
            result.errors++;
          }
        }
      } else {
        print('ℹ️ DataMigrationService: Aucun projet à migrer');
      }
    } catch (e) {
      print('❌ DataMigrationService: Erreur lors de la migration des projets: $e');
      result.errors++;
    }
  }

  // Migration des tâches
  Future<void> _migrateTodos(SharedPreferences prefs, MigrationResult result) async {
    try {
      final todosJson = prefs.getString(_oldTodosKey);
      if (todosJson != null && todosJson.isNotEmpty) {
        print('📝 DataMigrationService: Migration des tâches...');
        
        final List<dynamic> todosList = jsonDecode(todosJson);
        for (final todoMap in todosList) {
          try {
            final todo = TodoItem.fromMap(todoMap as Map<String, dynamic>);
            
                    // Vérifier si la tâche n'existe pas déjà
        final existingTodo = _todoService.getTodo(todo.id);
        if (existingTodo == null) {
          await _todoService.addTodo(todo);
          result.migratedTodos++;
          print('   ✅ Tâche migrée: "${todo.title}"');
        } else {
          print('   ⚠️ Tâche déjà existante, ignorée: "${todo.title}"');
        }
          } catch (e) {
            print('   ❌ Erreur lors de la migration d\'une tâche: $e');
            result.errors++;
          }
        }
      } else {
        print('ℹ️ DataMigrationService: Aucune tâche à migrer');
      }
    } catch (e) {
      print('❌ DataMigrationService: Erreur lors de la migration des tâches: $e');
      result.errors++;
    }
  }

  // Migration des préférences
  Future<void> _migratePreferences(SharedPreferences prefs, MigrationResult result) async {
    try {
      print('📝 DataMigrationService: Migration des préférences...');
      
      // Migrer les préférences existantes
      final showDescriptions = prefs.getBool('show_descriptions');
      if (showDescriptions != null) {
        await _preferencesService.setShowDescriptions(showDescriptions);
        result.migratedPreferences++;
        print('   ✅ Préférence migrée: show_descriptions = $showDescriptions');
      }
      
      // Migrer d'autres préférences si elles existent
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key != _oldTodosKey && key != _oldProjectsKey && key != 'show_descriptions') {
          try {
            final value = prefs.get(key);
            if (value != null) {
              await _preferencesService.setPreference(key, value);
              result.migratedPreferences++;
              print('   ✅ Préférence migrée: $key = $value');
            }
          } catch (e) {
            print('   ❌ Erreur lors de la migration de la préférence $key: $e');
            result.errors++;
          }
        }
      }
    } catch (e) {
      print('❌ DataMigrationService: Erreur lors de la migration des préférences: $e');
      result.errors++;
    }
  }

  // Nettoyer les anciennes données après migration réussie
  Future<void> cleanupOldData() async {
    try {
      print('🧹 DataMigrationService: Nettoyage des anciennes données...');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_oldTodosKey);
      await prefs.remove(_oldProjectsKey);
      
      print('✅ DataMigrationService: Anciennes données nettoyées');
    } catch (e) {
      print('❌ DataMigrationService: Erreur lors du nettoyage: $e');
    }
  }

  // Rollback en cas d'erreur
  Future<void> rollback() async {
    try {
      print('🔄 DataMigrationService: Rollback de la migration...');
      
      // Effacer les nouvelles données
      await _storage.clearAllData();
      
      print('✅ DataMigrationService: Rollback terminé');
    } catch (e) {
      print('❌ DataMigrationService: Erreur lors du rollback: $e');
    }
  }

  // Vérifier l'intégrité des données migrées
  Future<bool> verifyMigration() async {
    try {
      print('🔍 DataMigrationService: Vérification de l\'intégrité des données...');
      
      final stats = _storage.getDataStats();
      final hasData = stats['todos']! > 0 || stats['projects']! > 0;
      
      if (hasData) {
        print('✅ DataMigrationService: Données migrées avec succès');
        print('📊 Statistiques: $stats');
        return true;
      } else {
        print('⚠️ DataMigrationService: Aucune donnée trouvée après migration');
        return false;
      }
    } catch (e) {
      print('❌ DataMigrationService: Erreur lors de la vérification: $e');
      return false;
    }
  }
} 