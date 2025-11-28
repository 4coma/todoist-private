import 'package:flutter/material.dart';
import '../models/project.dart';

import 'local_storage_service.dart';
import 'firebase_sync_service.dart';

class ProjectService {
  static final ProjectService _instance = ProjectService._internal();
  factory ProjectService() => _instance;
  ProjectService._internal();

  final LocalStorageService _storage = LocalStorageService();
  final FirebaseSyncService _firebaseSync = FirebaseSyncService();

  // Getters pour accéder aux données
  List<Project> get projects => _storage.projects;

  // Initialisation (déjà fait par LocalStorageService)
  Future<void> initialize() async {
    // Le LocalStorageService est déjà initialisé dans main.dart
  }

  // === MÉTHODES CRUD ===

  // Ajouter un projet
  Future<Project> addProject(Project project) async {
    final result = await _storage.addProject(project);
    
    // Synchroniser avec Firebase en arrière-plan
    _firebaseSync.syncProject(result).catchError((e) {
      debugPrint('⚠️ [ProjectService] Erreur lors de la synchronisation Firebase: $e');
    });
    
    return result;
  }

  // Mettre à jour un projet
  Future<Project?> updateProject(int id, Map<String, dynamic> updates) async {
    final result = await _storage.updateProject(id, updates);
    
    // Synchroniser avec Firebase en arrière-plan
    if (result != null) {
      _firebaseSync.syncProject(result).catchError((e) {
        debugPrint('⚠️ [ProjectService] Erreur lors de la synchronisation Firebase: $e');
      });
    }
    
    return result;
  }

  // Supprimer un projet
  Future<bool> deleteProject(int id) async {
    final result = await _storage.deleteProject(id);
    
    // Synchroniser avec Firebase en arrière-plan
    if (result) {
      _firebaseSync.deleteProjectFromFirebase(id).catchError((e) {
        debugPrint('⚠️ [ProjectService] Erreur lors de la synchronisation Firebase: $e');
      });
    }
    
    return result;
  }

  // Obtenir un projet par ID
  Project? getProject(int id) {
    return _storage.getProject(id);
  }

  // === MÉTHODES MÉTIER ===

  // Créer un nouveau projet
  Future<Project> createProject({
    required String name,
    required Color color,
  }) async {
    final project = Project(
      id: generateProjectId(),
      name: name,
      color: color,
    );

    return await addProject(project);
  }

  // Obtenir les projets avec le nombre de tâches
  List<Map<String, dynamic>> getProjectsWithTodoCount() {
    return projects.map((project) {
      final todoCount = _storage.getTodosByProject(project.id).length;
      final completedCount = _storage.getTodosByProject(project.id)
          .where((todo) => todo.isCompleted)
          .length;
      
      return {
        'project': project,
        'totalTodos': todoCount,
        'completedTodos': completedCount,
        'pendingTodos': todoCount - completedCount,
      };
    }).toList();
  }

  // Obtenir les projets avec des tâches en retard
  List<Project> getProjectsWithOverdueTodos() {
    final now = DateTime.now();
    final overdueTodos = _storage.todos.where((todo) => 
      !todo.isCompleted && 
      todo.dueDate != null && 
      todo.dueDate!.isBefore(now)
    ).toList();

    final projectIds = overdueTodos.map((todo) => todo.projectId).toSet();
    return projects.where((project) => projectIds.contains(project.id)).toList();
  }

  // Obtenir les projets avec des rappels aujourd'hui
  List<Project> getProjectsWithTodayReminders() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    
    final todayReminders = _storage.todos.where((todo) => 
      todo.reminder != null && 
      todo.reminder!.isAfter(today) && 
      todo.reminder!.isBefore(tomorrow)
    ).toList();

    final projectIds = todayReminders.map((todo) => todo.projectId).toSet();
    return projects.where((project) => projectIds.contains(project.id)).toList();
  }

  // Obtenir les statistiques d'un projet
  Map<String, int> getProjectStats(int projectId) {
    final projectTodos = _storage.getTodosByProject(projectId);
    final now = DateTime.now();
    
    return {
      'total': projectTodos.length,
      'completed': projectTodos.where((t) => t.isCompleted).length,
      'pending': projectTodos.where((t) => !t.isCompleted).length,
      'overdue': projectTodos.where((t) => 
        !t.isCompleted && 
        t.dueDate != null && 
        t.dueDate!.isBefore(now)
      ).length,
      'with_reminders': projectTodos.where((t) => t.reminder != null).length,
      'with_estimates': projectTodos.where((t) => t.estimatedMinutes != null).length,
    };
  }

  // Obtenir le pourcentage de progression d'un projet
  double getProjectProgress(int projectId) {
    final projectTodos = _storage.getTodosByProject(projectId);
    if (projectTodos.isEmpty) return 0.0;
    
    final completedCount = projectTodos.where((t) => t.isCompleted).length;
    return (completedCount / projectTodos.length).clamp(0.0, 1.0);
  }

  // Obtenir le temps total estimé d'un projet
  int getProjectEstimatedTime(int projectId) {
    final projectTodos = _storage.getTodosByProject(projectId);
    return projectTodos
        .where((todo) => todo.estimatedMinutes != null)
        .fold(0, (sum, todo) => sum + (todo.estimatedMinutes ?? 0));
  }

  // Obtenir le temps total écoulé d'un projet
  int getProjectElapsedTime(int projectId) {
    final projectTodos = _storage.getTodosByProject(projectId);
    return projectTodos.fold(0, (sum, todo) => sum + todo.elapsedSeconds);
  }

  // Rechercher des projets par nom
  List<Project> searchProjects(String query) {
    final lowercaseQuery = query.toLowerCase();
    return projects.where((project) => 
      project.name.toLowerCase().contains(lowercaseQuery)
    ).toList();
  }

  // Vérifier si un projet peut être supprimé
  bool canDeleteProject(int projectId) {
    final project = getProject(projectId);
    if (project == null) return false;
    
    // Tous les projets peuvent être supprimés
    return true;
  }

  // Déplacer toutes les tâches d'un projet vers un autre
  Future<bool> moveAllTodosToProject(int fromProjectId, int toProjectId) async {
    final fromProject = getProject(fromProjectId);
    final toProject = getProject(toProjectId);
    
    if (fromProject == null || toProject == null) return false;
    
    final projectTodos = _storage.getTodosByProject(fromProjectId);
    
    for (final todo in projectTodos) {
      await _storage.updateTodo(todo.id, {
        'projectId': toProjectId,
      });
    }
    
    return true;
  }

  // Fusionner deux projets
  Future<bool> mergeProjects(int sourceProjectId, int targetProjectId) async {
    final sourceProject = getProject(sourceProjectId);
    final targetProject = getProject(targetProjectId);
    
    if (sourceProject == null || targetProject == null) return false;
    
    // Déplacer toutes les tâches
    final success = await moveAllTodosToProject(sourceProjectId, targetProjectId);
    if (!success) return false;
    
    // Supprimer le projet source
    return await deleteProject(sourceProjectId);
  }

  // Obtenir les couleurs disponibles pour les projets
  List<Color> getAvailableColors() {
    return [
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
      Colors.lime,
      Colors.brown,
    ];
  }

  // Obtenir une couleur aléatoire pour un nouveau projet
  Color getRandomColor() {
    final colors = getAvailableColors();
    final random = DateTime.now().millisecondsSinceEpoch % colors.length;
    return colors[random];
  }

  // Vérifier si un nom de projet existe déjà
  bool isProjectNameTaken(String name, {int? excludeProjectId}) {
    return projects.any((project) => 
      project.name.toLowerCase() == name.toLowerCase() &&
      (excludeProjectId == null || project.id != excludeProjectId)
    );
  }

  // Valider un projet avant sauvegarde
  bool validateProject(Project project) {
    return project.name.isNotEmpty && 
           project.name.length <= 50 &&
           !isProjectNameTaken(project.name, excludeProjectId: project.id);
  }

  // Générer un ID unique pour un nouveau projet
  int generateProjectId() {
    return DateTime.now().millisecondsSinceEpoch;
  }

  // Obtenir les statistiques globales des projets
  Map<String, dynamic> getGlobalProjectStats() {
    final projectStats = projects.map((project) {
      final stats = getProjectStats(project.id);
      return {
        'project': project,
        'stats': stats,
        'progress': getProjectProgress(project.id),
        'estimatedTime': getProjectEstimatedTime(project.id),
        'elapsedTime': getProjectElapsedTime(project.id),
      };
    }).toList();

    final totalTodos = _storage.todos.length;
    final totalCompleted = _storage.todos.where((t) => t.isCompleted).length;
    final totalOverdue = _storage.todos.where((t) => 
      !t.isCompleted && 
      t.dueDate != null && 
      t.dueDate!.isBefore(DateTime.now())
    ).length;

    return {
      'projects': projectStats,
      'totalProjects': projects.length,
      'totalTodos': totalTodos,
      'totalCompleted': totalCompleted,
      'totalOverdue': totalOverdue,
      'overallProgress': totalTodos > 0 ? (totalCompleted / totalTodos).clamp(0.0, 1.0) : 0.0,
    };
  }

  // Vider tous les projets en mémoire
  void clearAllProjects() {
    debugPrint('🗑️ [ProjectService] clearAllProjects: vider tous les projets en mémoire');
    _storage.clearAllProjects();
  }
} 