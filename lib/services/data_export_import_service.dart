import 'todo_service.dart';
import 'project_service.dart';
import 'preferences_service.dart';
import 'local_storage_service.dart';
import '../models/todo_item.dart';
import '../models/project.dart';

class DataExportImportService {
  static final DataExportImportService _instance = DataExportImportService._internal();
  factory DataExportImportService() => _instance;
  DataExportImportService._internal();

  final TodoService _todoService = TodoService();
  final ProjectService _projectService = ProjectService();
  final PreferencesService _preferencesService = PreferencesService();

  /// Exporte toutes les données de l'application sous forme de Map (prêt à être encodé en JSON)
  Map<String, dynamic> exportAllData() {
    return {
      'version': '1.0.0',
      'exportDate': DateTime.now().toIso8601String(),
      'todos': _todoService.todos.map((t) => t.toJson()).toList(),
      'projects': _projectService.projects.map((p) => p.toJson()).toList(),
      'preferences': _preferencesService.getAllPreferences(),
    };
  }

  /// Importe toutes les données de l'application à partir d'un Map (issu d'un JSON)
  Future<void> importAllData(Map<String, dynamic> data) async {
    try {
      print('🔄 DataExportImportService: Début de l\'import des données...');
      
      // Vérifier la version
      final version = data['version'] as String?;
      if (version == null || !version.startsWith('1.0')) {
        throw Exception('Version de données non supportée: $version');
      }

      // Vider d'abord toutes les données existantes (sauf le projet par défaut)
      await clearAllData();

      // Créer un mapping des anciens IDs vers les nouveaux IDs pour éviter les conflits
      Map<int, int> projectIdMapping = {};
      Map<int, int> todoIdMapping = {};

      // Importer les projets
      if (data['projects'] != null) {
        final List<dynamic> projectsList = data['projects'] as List;
        print('📝 DataExportImportService: Import de ${projectsList.length} projets...');
        
        for (final projectJson in projectsList) {
          try {
            final originalProject = Project.fromJson(projectJson as Map<String, dynamic>);
            
            // Créer un nouveau projet avec un ID unique
            final newProject = Project(
              id: DateTime.now().millisecondsSinceEpoch + projectsList.indexOf(projectJson),
              name: originalProject.name,
              color: originalProject.color,
              isDefault: originalProject.isDefault,
              createdAt: originalProject.createdAt,
              updatedAt: originalProject.updatedAt,
            );
            
            // Sauvegarder le mapping d'ID
            projectIdMapping[originalProject.id] = newProject.id;
            
            await _projectService.addProject(newProject);
            print('   ✅ Projet importé: "${newProject.name}" (ID: ${originalProject.id} -> ${newProject.id})');
          } catch (e) {
            print('   ❌ Erreur lors de l\'import d\'un projet: $e');
            throw Exception('Erreur lors de l\'import du projet: $e');
          }
        }
      }

      // Importer les tâches
      if (data['todos'] != null) {
        final List<dynamic> todosList = data['todos'] as List;
        print('📝 DataExportImportService: Import de ${todosList.length} tâches...');
        
        for (final todoJson in todosList) {
          try {
            final originalTodo = TodoItem.fromJson(todoJson as Map<String, dynamic>);
            
            // Créer une nouvelle tâche avec un ID unique
            final newTodo = TodoItem(
              id: DateTime.now().millisecondsSinceEpoch + todosList.indexOf(todoJson) + 1000,
              title: originalTodo.title,
              description: originalTodo.description,
              dueDate: originalTodo.dueDate,
              priority: originalTodo.priority,
              projectId: projectIdMapping[originalTodo.projectId] ?? originalTodo.projectId,
              isCompleted: originalTodo.isCompleted,
              parentId: originalTodo.parentId != null ? 
                (todoIdMapping[originalTodo.parentId] ?? originalTodo.parentId) : null,
              level: originalTodo.level,
              reminder: originalTodo.reminder,
              estimatedMinutes: originalTodo.estimatedMinutes,
              elapsedMinutes: originalTodo.elapsedMinutes,
              elapsedSeconds: originalTodo.elapsedSeconds,
              createdAt: originalTodo.createdAt,
              updatedAt: originalTodo.updatedAt,
            );
            
            // Sauvegarder le mapping d'ID
            todoIdMapping[originalTodo.id] = newTodo.id;
            
            await _todoService.addTodo(newTodo);
            print('   ✅ Tâche importée: "${newTodo.title}" (ID: ${originalTodo.id} -> ${newTodo.id})');
          } catch (e) {
            print('   ❌ Erreur lors de l\'import d\'une tâche: $e');
            throw Exception('Erreur lors de l\'import de la tâche: $e');
          }
        }
      }

      // Mettre à jour les parentId des tâches avec les nouveaux IDs
      final allTodos = _todoService.todos;
      for (final todo in allTodos) {
        if (todo.parentId != null && todoIdMapping.containsKey(todo.parentId)) {
          await _todoService.updateTodo(todo.id, {
            'parentId': todoIdMapping[todo.parentId],
          });
          print('   🔄 ParentId mis à jour pour la tâche "${todo.title}": ${todo.parentId} -> ${todoIdMapping[todo.parentId]}');
        }
      }

      // Importer les préférences
      if (data['preferences'] != null) {
        final prefs = data['preferences'] as Map<String, dynamic>;
        print('📝 DataExportImportService: Import de ${prefs.length} préférences...');
        
        for (final entry in prefs.entries) {
          try {
            await _preferencesService.setPreference(entry.key, entry.value);
            print('   ✅ Préférence importée: "${entry.key}"');
          } catch (e) {
            print('   ❌ Erreur lors de l\'import d\'une préférence: $e');
            // Ne pas faire échouer l'import pour les préférences
          }
        }
      }

      print('✅ DataExportImportService: Import terminé avec succès');
      print('📊 Résumé de l\'import:');
      print('   - Projets importés: ${_projectService.projects.length}');
      print('   - Tâches importées: ${_todoService.todos.length}');
      print('   - Préférences importées: ${_preferencesService.getAllPreferences().length}');
      
      // Forcer la synchronisation avec LocalStorageService
      print('🔄 DataExportImportService: Synchronisation avec LocalStorageService...');
      final localStorageService = LocalStorageService();
      await localStorageService.reloadData();
      print('✅ DataExportImportService: Synchronisation terminée');
      
      // Vérifier que les données sont bien synchronisées
      final stats = localStorageService.getDataStats();
      print('📊 Vérification finale - LocalStorageService:');
      print('   - Projets: ${stats['projects']}');
      print('   - Tâches: ${stats['todos']}');
      print('   - Tâches complétées: ${stats['completed_todos']}');
      print('   - Tâches en attente: ${stats['pending_todos']}');
    } catch (e) {
      print('❌ DataExportImportService: Erreur lors de l\'import: $e');
      rethrow;
    }
  }

  /// Méthode de test pour vérifier l'import avec des données d'exemple
  Future<void> testImport() async {
    print('🧪 DataExportImportService: Test d\'import avec des données d\'exemple...');
    
    final testData = {
      'version': '1.0.0',
      'exportDate': DateTime.now().toIso8601String(),
      'projects': [
        {
          'id': 999,
          'name': 'Projet de Test',
          'color': 4280391411,
          'isDefault': false,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        }
      ],
      'todos': [
        {
          'id': 999001,
          'title': 'Tâche de test 1',
          'description': 'Description de la tâche de test',
          'dueDate': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
          'priority': 'high',
          'projectId': 999,
          'isCompleted': false,
          'parentId': null,
          'level': 0,
          'reminder': null,
          'estimatedMinutes': 60,
          'elapsedMinutes': 0,
          'elapsedSeconds': 0,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        },
        {
          'id': 999002,
          'title': 'Tâche de test 2',
          'description': 'Sous-tâche de test',
          'dueDate': null,
          'priority': 'medium',
          'projectId': 999,
          'isCompleted': true,
          'parentId': 999001,
          'level': 1,
          'reminder': null,
          'estimatedMinutes': 30,
          'elapsedMinutes': 15,
          'elapsedSeconds': 900,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        }
      ],
      'preferences': {
        'test_preference': 'test_value',
        'show_descriptions': true,
      }
    };
    
    try {
      await importAllData(testData);
      print('✅ Test d\'import réussi !');
    } catch (e) {
      print('❌ Test d\'import échoué: $e');
      rethrow;
    }
  }

  /// Supprime toutes les données de l'application
  Future<void> clearAllData() async {
    try {
      print('🔄 DataExportImportService.clearAllData(): Début de la suppression...');
      print('🔄 ==========================================');
      print('🔄 SUPPRESSION DE TOUTES LES DONNÉES');
      print('🔄 ==========================================');
      
      // Forcer la suppression directe du stockage local
      final localStorageService = LocalStorageService();
      
      // Supprimer toutes les données du stockage persistant
      await localStorageService.clearAllData();
      print('✅ Toutes les données supprimées du stockage persistant');
      
      // Supprimer toutes les préférences (sauf celles essentielles)
      final prefs = _preferencesService.getAllPreferences();
      print('📝 DataExportImportService.clearAllData(): ${prefs.length} préférences à vérifier');
      
      for (final key in prefs.keys) {
        // Garder quelques préférences essentielles
        if (!['selectedTheme', 'reminder_enabled', 'reminder_hour', 'reminder_minute'].contains(key)) {
          try {
            await _preferencesService.removePreference(key);
            print('   ✅ Préférence supprimée: "$key"');
          } catch (e) {
            print('   ❌ Erreur lors de la suppression de la préférence "$key": $e');
          }
        } else {
          print('   ⚠️ Préférence essentielle conservée: "$key"');
        }
      }

      // Vider les listes en mémoire
      _todoService.clearAllTodos();
      _projectService.clearAllProjects();
      
      print('✅ DataExportImportService.clearAllData(): Suppression terminée');
      print('✅ ==========================================');
      print('✅ SUPPRESSION TERMINÉE');
      print('✅ ==========================================');
    } catch (e) {
      print('❌ DataExportImportService.clearAllData(): Erreur lors de la suppression des données: $e');
      print('❌ ==========================================');
      print('❌ ERREUR LORS DE LA SUPPRESSION');
      print('❌ ==========================================');
      rethrow;
    }
  }
} 