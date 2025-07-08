import '../models/todo_item.dart';
import 'local_storage_service.dart';
import 'package:flutter/foundation.dart';

class TodoService {
  static final TodoService _instance = TodoService._internal();
  factory TodoService() => _instance;
  TodoService._internal();

  final LocalStorageService _storage = LocalStorageService();

  // Getters pour accéder aux données
  List<TodoItem> get todos => _storage.todos;
  List<TodoItem> get completedTodos => _storage.getCompletedTodos();
  List<TodoItem> get pendingTodos => _storage.getPendingTodos();

  // Initialisation (déjà fait par LocalStorageService)
  Future<void> initialize() async {
    // Le LocalStorageService est déjà initialisé dans main.dart
  }

  // === MÉTHODES CRUD ===

  // Ajouter une tâche
  Future<TodoItem> addTodo(TodoItem todo) async {
    debugPrint('🟢 [TodoService] addTodo: $todo');
    final result = await _storage.addTodo(todo);
    debugPrint('🟢 [TodoService] addTodo: done, total todos: ${_storage.todos.length}');
    return result;
  }

  // Mettre à jour une tâche
  Future<TodoItem?> updateTodo(int id, Map<String, dynamic> updates) async {
    debugPrint('🟡 [TodoService] updateTodo: id=$id, updates=$updates');
    final result = await _storage.updateTodo(id, updates);
    debugPrint('🟡 [TodoService] updateTodo: done, total todos: ${_storage.todos.length}');
    return result;
  }

  // Supprimer une tâche
  Future<bool> deleteTodo(int id) async {
    debugPrint('🔴 [TodoService] deleteTodo: id=$id');
    final result = await _storage.deleteTodo(id);
    debugPrint('🔴 [TodoService] deleteTodo: done, total todos: ${_storage.todos.length}');
    return result;
  }

  // Obtenir une tâche par ID
  TodoItem? getTodo(int id) {
    debugPrint('🔵 [TodoService] getTodo: id=$id');
    final result = _storage.getTodo(id);
    debugPrint('🔵 [TodoService] getTodo: result=$result');
    return result;
  }

  // === MÉTHODES MÉTIER ===

  // Obtenir les tâches par projet
  List<TodoItem> getTodosByProject(int projectId) {
    debugPrint('🟣 [TodoService] getTodosByProject: projectId=$projectId');
    final result = _storage.getTodosByProject(projectId);
    debugPrint('🟣 [TodoService] getTodosByProject: result count=${result.length}');
    return result;
  }

  // Obtenir les tâches racines (sans parent)
  List<TodoItem> getRootTodos() {
    return _storage.todos.where((todo) => todo.isRootTask).toList();
  }

  // Obtenir les sous-tâches d'une tâche
  List<TodoItem> getSubTasks(int parentId) {
    debugPrint('🟤 [TodoService] getSubTasks: parentId=$parentId');
    final result = _storage.todos.where((todo) => todo.parentId == parentId).toList();
    debugPrint('🟤 [TodoService] getSubTasks: result count=${result.length}');
    return result;
  }

  // Obtenir toutes les sous-tâches récursivement
  List<TodoItem> getAllSubTasks(int parentId) {
    debugPrint('🟠 [TodoService] getAllSubTasks: parentId=$parentId');
    List<TodoItem> allSubTasks = [];
    List<int> toProcess = [parentId];
    
    while (toProcess.isNotEmpty) {
      int currentId = toProcess.removeAt(0);
      List<TodoItem> directSubTasks = _storage.todos.where((todo) => todo.parentId == currentId).toList();
      allSubTasks.addAll(directSubTasks);
      toProcess.addAll(directSubTasks.map((todo) => todo.id));
    }
    
    debugPrint('🟠 [TodoService] getAllSubTasks: found ${allSubTasks.length}');
    return allSubTasks;
  }

  // Vérifier si une tâche a des sous-tâches
  bool hasSubTasks(int parentId) {
    debugPrint('⚫ [TodoService] hasSubTasks: parentId=$parentId');
    final result = _storage.todos.any((todo) => todo.parentId == parentId);
    debugPrint('⚫ [TodoService] hasSubTasks: result=$result');
    return result;
  }

  // Marquer une tâche comme terminée
  Future<TodoItem?> completeTodo(int id) async {
    return await updateTodo(id, {
      'isCompleted': true,
    });
  }

  // Marquer une tâche comme non terminée
  Future<TodoItem?> uncompleteTodo(int id) async {
    return await updateTodo(id, {
      'isCompleted': false,
    });
  }

  // Basculer le statut d'une tâche
  Future<TodoItem?> toggleTodo(int id) async {
    final todo = getTodo(id);
    if (todo != null) {
      return await updateTodo(id, {
        'isCompleted': !todo.isCompleted,
      });
    }
    return null;
  }

  // Mettre à jour le temps écoulé d'une tâche
  Future<TodoItem?> updateElapsedTime(int id, int elapsedSeconds) async {
    return await updateTodo(id, {
      'elapsedSeconds': elapsedSeconds,
      'elapsedMinutes': elapsedSeconds ~/ 60,
    });
  }

  // Ajouter du temps à une tâche
  Future<TodoItem?> addElapsedTime(int id, int additionalSeconds) async {
    final todo = getTodo(id);
    if (todo != null) {
      final newElapsedSeconds = todo.elapsedSeconds + additionalSeconds;
      return await updateElapsedTime(id, newElapsedSeconds);
    }
    return null;
  }

  // Créer une sous-tâche
  Future<TodoItem> createSubTask({
    required int parentId,
    required String title,
    required String description,
    DateTime? dueDate,
    Priority priority = Priority.medium,
    bool isCompleted = false,
    int? estimatedMinutes,
  }) async {
    final parentTodo = getTodo(parentId);
    if (parentTodo == null) {
      throw Exception('Tâche parente non trouvée');
    }

    if (!parentTodo.canHaveSubTasks) {
      throw Exception('Impossible de créer une sous-tâche au-delà du niveau 3');
    }

    final subTask = TodoItem(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      projectId: parentTodo.projectId,
      isCompleted: isCompleted,
      parentId: parentId,
      level: parentTodo.level + 1,
      estimatedMinutes: estimatedMinutes,
    );

    return await addTodo(subTask);
  }

  // Supprimer une tâche et toutes ses sous-tâches
  Future<bool> deleteTodoWithSubTasks(int id) async {
    debugPrint('🔴 [TodoService] deleteTodoWithSubTasks: id=$id');
    final subTasks = getAllSubTasks(id);
    debugPrint('🔴 [TodoService] deleteTodoWithSubTasks: subTasks=${subTasks.map((t) => t.id).toList()}');
    for (final subTask in subTasks) {
      await _storage.deleteTodo(subTask.id);
    }
    final result = await _storage.deleteTodo(id);
    debugPrint('🔴 [TodoService] deleteTodoWithSubTasks: done, total todos: ${_storage.todos.length}');
    return result;
  }

  // Déplacer une tâche vers un autre projet
  Future<TodoItem?> moveTodoToProject(int todoId, int newProjectId) async {
    return await updateTodo(todoId, {
      'projectId': newProjectId,
    });
  }

  // Obtenir les tâches en retard
  List<TodoItem> getOverdueTodos() {
    final now = DateTime.now();
    return _storage.todos.where((todo) => 
      !todo.isCompleted && 
      todo.dueDate != null && 
      todo.dueDate!.isBefore(now)
    ).toList();
  }

  // Obtenir les tâches avec rappel aujourd'hui
  List<TodoItem> getTodayReminders() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    
    return _storage.todos.where((todo) => 
      todo.reminder != null && 
      todo.reminder!.isAfter(today) && 
      todo.reminder!.isBefore(tomorrow)
    ).toList();
  }

  // Obtenir les tâches avec rappel dans les prochaines heures
  List<TodoItem> getUpcomingReminders({int hours = 24}) {
    final now = DateTime.now();
    final future = now.add(Duration(hours: hours));
    
    return _storage.todos.where((todo) => 
      todo.reminder != null && 
      todo.reminder!.isAfter(now) && 
      todo.reminder!.isBefore(future)
    ).toList();
  }

  // Rechercher des tâches par texte
  List<TodoItem> searchTodos(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _storage.todos.where((todo) => 
      todo.title.toLowerCase().contains(lowercaseQuery) ||
      todo.description.toLowerCase().contains(lowercaseQuery)
    ).toList();
  }

  // Obtenir les statistiques des tâches
  Map<String, int> getTodoStats() {
    final todos = _storage.todos;
    return {
      'total': todos.length,
      'completed': todos.where((t) => t.isCompleted).length,
      'pending': todos.where((t) => !t.isCompleted).length,
      'overdue': getOverdueTodos().length,
      'with_reminders': todos.where((t) => t.reminder != null).length,
      'with_estimates': todos.where((t) => t.estimatedMinutes != null).length,
    };
  }

  // Générer un ID unique pour une nouvelle tâche
  int generateTodoId() {
    return DateTime.now().millisecondsSinceEpoch;
  }

  // Valider une tâche avant sauvegarde
  bool validateTodo(TodoItem todo) {
    return todo.title.isNotEmpty && 
           todo.projectId > 0 &&
           todo.level >= 0 && 
           todo.level <= 3;
  }
} 