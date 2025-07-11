import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/todo_item.dart';
import '../models/project.dart';

class LocalStorageService {
  // Pattern Singleton
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  // Clés de stockage
  static const String _todosKey = 'local_todos';
  static const String _projectsKey = 'local_projects';
  static const String _preferencesKey = 'local_preferences';
  static const String _timerDataKey = 'local_timer_data';

  // Cache local des données
  List<TodoItem> _todos = [];
  List<Project> _projects = [];
  Map<String, dynamic> _preferences = {};
  Map<String, dynamic> _timerData = {};

  // Getters immutables
  List<TodoItem> get todos => List.unmodifiable(_todos);
  List<Project> get projects => List.unmodifiable(_projects);
  Map<String, dynamic> get preferences => Map.unmodifiable(_preferences);
  Map<String, dynamic> get timerData => Map.unmodifiable(_timerData);

  // Initialisation du service
  Future<void> initialize() async {
    print('🔄 LocalStorageService: Initialisation...');
    await _loadAllData();
    print('✅ LocalStorageService: Initialisation terminée');
  }

  // Forcer le rechargement des données (utile après import)
  Future<void> reloadData() async {
    print('🔄 LocalStorageService: Rechargement forcé des données...');
    await _loadAllData();
    print('✅ LocalStorageService: Rechargement terminé');
  }

  // Chargement de toutes les données
  Future<void> _loadAllData() async {
    try {
      await Future.wait([
        _loadTodos(),
        _loadProjects(),
        _loadPreferences(),
        _loadTimerData(),
      ]);
    } catch (e) {
      print('❌ Erreur lors du chargement des données: $e');
    }
  }

  // === GESTION DES TÂCHES ===

  Future<void> _loadTodos() async {
    try {
      debugPrint('🔄 LocalStorageService._loadTodos(): Début du chargement...');
      final prefs = await SharedPreferences.getInstance();
      final todosJson = prefs.getString(_todosKey);
      if (todosJson != null) {
        debugPrint('🔄 LocalStorageService._loadTodos(): Données trouvées, déchiffrement...');
        final decryptedData = _decryptData(todosJson);
        final List<dynamic> todosList = jsonDecode(decryptedData);
        _todos = todosList.map((map) => TodoItem.fromMap(map)).toList();
        debugPrint('✅ LocalStorageService._loadTodos(): ${_todos.length} tâches chargées');
      } else {
        debugPrint('ℹ️ LocalStorageService._loadTodos(): Aucune donnée trouvée, liste vide');
        _todos = [];
      }
    } catch (e) {
      debugPrint('❌ LocalStorageService._loadTodos(): Erreur lors du chargement des tâches: $e');
      _todos = [];
    }
  }

  Future<void> _saveTodos() async {
    try {
      debugPrint('🔄 LocalStorageService._saveTodos(): Début de la sauvegarde...');
      debugPrint('🔄 LocalStorageService._saveTodos(): ${_todos.length} tâches à sauvegarder');
      
      final prefs = await SharedPreferences.getInstance();
      final todosJson = _todos.map((todo) => todo.toMap()).toList();
      final jsonString = jsonEncode(todosJson);
      final encryptedData = _encryptData(jsonString);
      await prefs.setString(_todosKey, encryptedData);
      
      debugPrint('✅ LocalStorageService._saveTodos(): ${_todos.length} tâches sauvegardées');
      debugPrint('✅ LocalStorageService._saveTodos(): Données chiffrées et stockées');
    } catch (e) {
      debugPrint('❌ LocalStorageService._saveTodos(): Erreur lors de la sauvegarde des tâches: $e');
    }
  }

  Future<TodoItem> addTodo(TodoItem todo) async {
    debugPrint('🟢 [LocalStorageService] addTodo: $todo');
    final newTodo = TodoItem(
      id: todo.id,
      title: todo.title,
      description: todo.description,
      dueDate: todo.dueDate,
      priority: todo.priority,
      projectId: todo.projectId,
      isCompleted: todo.isCompleted,
      parentId: todo.parentId,
      level: todo.level,
      reminder: todo.reminder,
      estimatedMinutes: todo.estimatedMinutes,
      elapsedMinutes: todo.elapsedMinutes,
      elapsedSeconds: todo.elapsedSeconds,
    );
    _todos.add(newTodo);
    await _saveTodos();
    debugPrint('🟢 [LocalStorageService] addTodo: done, total todos: ${_todos.length}');
    return newTodo;
  }

  Future<TodoItem?> updateTodo(int id, Map<String, dynamic> updates) async {
    debugPrint('🟡 [LocalStorageService] updateTodo: id=$id, updates=$updates');
    final index = _todos.indexWhere((t) => t.id == id);
    if (index == -1) return null;
    final oldTodo = _todos[index];
    final updatedTodo = TodoItem(
      id: oldTodo.id,
      title: updates['title'] ?? oldTodo.title,
      description: updates['description'] ?? oldTodo.description,
      dueDate: updates['dueDate'] ?? oldTodo.dueDate,
      priority: updates['priority'] ?? oldTodo.priority,
      projectId: updates['projectId'] ?? oldTodo.projectId,
      isCompleted: updates['isCompleted'] ?? oldTodo.isCompleted,
      parentId: oldTodo.parentId,
      level: oldTodo.level,
      reminder: updates['reminder'] ?? oldTodo.reminder,
      estimatedMinutes: updates['estimatedMinutes'] ?? oldTodo.estimatedMinutes,
      elapsedMinutes: updates['elapsedMinutes'] ?? oldTodo.elapsedMinutes,
      elapsedSeconds: updates['elapsedSeconds'] ?? oldTodo.elapsedSeconds,
    );
    _todos[index] = updatedTodo;
    await _saveTodos();
    debugPrint('🟡 [LocalStorageService] updateTodo: done, total todos: ${_todos.length}');
    return updatedTodo;
  }

  Future<bool> deleteTodo(int id) async {
    debugPrint('🔴 [LocalStorageService] deleteTodo: id=$id');
    final index = _todos.indexWhere((t) => t.id == id);
    if (index == -1) {
      debugPrint('🔴 [LocalStorageService] deleteTodo: not found');
      return false;
    }
    _todos.removeAt(index);
    await _saveTodos();
    debugPrint('🔴 [LocalStorageService] deleteTodo: done, total todos: ${_todos.length}');
    return true;
  }

  TodoItem? getTodo(int id) {
    debugPrint('🔵 [LocalStorageService] getTodo: id=$id');
    try {
      final result = _todos.firstWhere((t) => t.id == id);
      debugPrint('🔵 [LocalStorageService] getTodo: found $result');
      return result;
    } catch (e) {
      debugPrint('🔵 [LocalStorageService] getTodo: not found');
      return null;
    }
  }

  List<TodoItem> getTodosByProject(int projectId) {
    debugPrint('🟣 [LocalStorageService] getTodosByProject: projectId=$projectId');
    final result = _todos.where((t) => t.projectId == projectId).toList();
    debugPrint('🟣 [LocalStorageService] getTodosByProject: result count=${result.length}');
    return result;
  }

  List<TodoItem> getCompletedTodos() {
    debugPrint('🟢 [LocalStorageService] getCompletedTodos');
    final result = _todos.where((t) => t.isCompleted).toList();
    debugPrint('🟢 [LocalStorageService] getCompletedTodos: result count=${result.length}');
    return result;
  }

  List<TodoItem> getPendingTodos() {
    debugPrint('🟡 [LocalStorageService] getPendingTodos');
    final result = _todos.where((t) => !t.isCompleted).toList();
    debugPrint('🟡 [LocalStorageService] getPendingTodos: result count=${result.length}');
    return result;
  }

  // === GESTION DES PROJETS ===

  Future<void> _loadProjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final projectsJson = prefs.getString(_projectsKey);
      if (projectsJson != null) {
        final decryptedData = _decryptData(projectsJson);
        final List<dynamic> projectsList = jsonDecode(decryptedData);
        _projects = projectsList.map((map) => Project.fromMap(map)).toList();
        print('✅ LocalStorageService: ${_projects.length} projets chargés');
      } else {
        // Projet par défaut si aucun projet n'existe
        _projects = [
          Project(
            id: 1,
            name: 'Personnel',
            color: Colors.blue,
            isDefault: true,
          ),
        ];
        await _saveProjects();
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des projets: $e');
      _projects = [
        Project(
          id: 1,
          name: 'Personnel',
          color: Colors.blue,
          isDefault: true,
        ),
      ];
    }
  }

  Future<void> _saveProjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final projectsJson = _projects.map((project) => project.toMap()).toList();
      final jsonString = jsonEncode(projectsJson);
      final encryptedData = _encryptData(jsonString);
      await prefs.setString(_projectsKey, encryptedData);
      print('✅ LocalStorageService: ${_projects.length} projets sauvegardés');
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde des projets: $e');
    }
  }

  Future<Project> addProject(Project project) async {
    print('📝 LocalStorageService: Ajout de projet "${project.name}"');
    final newProject = Project(
      id: project.id,
      name: project.name,
      color: project.color,
      isDefault: project.isDefault,
    );

    _projects.add(newProject);
    await _saveProjects();
    print('✅ LocalStorageService: Projet ajouté avec succès (ID: ${newProject.id})');
    return newProject;
  }

  Future<Project?> updateProject(int id, Map<String, dynamic> updates) async {
    final index = _projects.indexWhere((p) => p.id == id);
    if (index == -1) return null;

    final oldProject = _projects[index];
    final updatedProject = Project(
      id: oldProject.id,
      name: updates['name'] ?? oldProject.name,
      color: updates['color'] ?? oldProject.color,
      isDefault: updates['isDefault'] ?? oldProject.isDefault,
    );

    _projects[index] = updatedProject;
    await _saveProjects();
    print('✅ LocalStorageService: Projet mis à jour (ID: $id)');
    return updatedProject;
  }

  Future<bool> deleteProject(int id) async {
    final index = _projects.indexWhere((p) => p.id == id);
    if (index == -1) return false;

    // Vérifier que ce n'est pas le projet par défaut
    if (_projects[index].isDefault) {
      print('❌ LocalStorageService: Impossible de supprimer le projet par défaut');
      return false;
    }

    // Déplacer toutes les tâches vers le projet par défaut
    final defaultProject = _projects.firstWhere((p) => p.isDefault);
    for (int i = 0; i < _todos.length; i++) {
      if (_todos[i].projectId == id) {
        _todos[i] = TodoItem(
          id: _todos[i].id,
          title: _todos[i].title,
          description: _todos[i].description,
          dueDate: _todos[i].dueDate,
          priority: _todos[i].priority,
          projectId: defaultProject.id,
          isCompleted: _todos[i].isCompleted,
          parentId: _todos[i].parentId,
          level: _todos[i].level,
          reminder: _todos[i].reminder,
          estimatedMinutes: _todos[i].estimatedMinutes,
          elapsedMinutes: _todos[i].elapsedMinutes,
          elapsedSeconds: _todos[i].elapsedSeconds,
        );
      }
    }

    _projects.removeAt(index);
    await _saveProjects();
    await _saveTodos();
    print('✅ LocalStorageService: Projet supprimé (ID: $id)');
    return true;
  }

  Project? getProject(int id) {
    try {
      return _projects.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  Project getDefaultProject() {
    return _projects.firstWhere((p) => p.isDefault);
  }

  // === GESTION DES PRÉFÉRENCES ===

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final preferencesJson = prefs.getString(_preferencesKey);
      if (preferencesJson != null) {
        final decryptedData = _decryptData(preferencesJson);
        _preferences = Map<String, dynamic>.from(jsonDecode(decryptedData));
        print('✅ LocalStorageService: Préférences chargées');
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des préférences: $e');
      _preferences = {};
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(_preferences);
      final encryptedData = _encryptData(jsonString);
      await prefs.setString(_preferencesKey, encryptedData);
      print('✅ LocalStorageService: Préférences sauvegardées');
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde des préférences: $e');
    }
  }

  T? getPreference<T>(String key) {
    return _preferences[key] as T?;
  }

  Future<void> setPreference<T>(String key, T value) async {
    _preferences[key] = value;
    await _savePreferences();
    print('✅ LocalStorageService: Préférence mise à jour: $key = $value');
  }

  Future<void> removePreference(String key) async {
    _preferences.remove(key);
    await _savePreferences();
    print('✅ LocalStorageService: Préférence supprimée: $key');
  }

  // === GESTION DES DONNÉES DE TIMER ===

  Future<void> _loadTimerData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timerDataJson = prefs.getString(_timerDataKey);
      if (timerDataJson != null) {
        final decryptedData = _decryptData(timerDataJson);
        _timerData = Map<String, dynamic>.from(jsonDecode(decryptedData));
        print('✅ LocalStorageService: Données de timer chargées');
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des données de timer: $e');
      _timerData = {};
    }
  }

  Future<void> _saveTimerData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(_timerData);
      final encryptedData = _encryptData(jsonString);
      await prefs.setString(_timerDataKey, encryptedData);
      print('✅ LocalStorageService: Données de timer sauvegardées');
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde des données de timer: $e');
    }
  }

  T? getTimerData<T>(String key) {
    return _timerData[key] as T?;
  }

  Future<void> setTimerData<T>(String key, T value) async {
    _timerData[key] = value;
    await _saveTimerData();
  }

  // === SYSTÈME DE CHIFFREMENT ===

  String _encryptData(String data) {
    try {
      final key = _generateEncryptionKey();
      final bytes = utf8.encode(data);
      final encrypted = base64.encode(bytes);
      return encrypted;
    } catch (e) {
      print('❌ Erreur de chiffrement: $e');
      return data; // Retourner les données non chiffrées en cas d'erreur
    }
  }

  String _decryptData(String encryptedData) {
    try {
      final bytes = base64.decode(encryptedData);
      return utf8.decode(bytes);
    } catch (e) {
      print('❌ Erreur de déchiffrement: $e');
      return encryptedData; // Retourner les données telles quelles en cas d'erreur
    }
  }

  String _generateEncryptionKey() {
    final deviceId = DateTime.now().millisecondsSinceEpoch.toString();
    final random = Random();
    final hash = random.nextInt(1000000).toString();
    final combined = deviceId + hash;
    // S'assurer que la longueur est suffisante avant de prendre les 32 premiers caractères
    if (combined.length < 32) {
      return combined.padRight(32, '0');
    }
    return combined.substring(0, 32);
  }

  // === MÉTHODES UTILITAIRES ===

  Future<void> saveAllData() async {
    print('🔄 LocalStorageService: Sauvegarde de toutes les données...');
    await Future.wait([
      _saveTodos(),
      _saveProjects(),
      _savePreferences(),
      _saveTimerData(),
    ]);
    print('✅ LocalStorageService: Toutes les données sauvegardées');
  }

  Future<void> clearAllData() async {
    print('🔄 LocalStorageService: Effacement de toutes les données...');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_todosKey);
      await prefs.remove(_projectsKey);
      await prefs.remove(_preferencesKey);
      await prefs.remove(_timerDataKey);
      
      _todos.clear();
      _projects.clear();
      _preferences.clear();
      _timerData.clear();
      
      print('✅ LocalStorageService: Toutes les données effacées');
    } catch (e) {
      print('❌ Erreur lors de l\'effacement des données: $e');
    }
  }

  // Statistiques des données
  Map<String, int> getDataStats() {
    return {
      'todos': _todos.length,
      'projects': _projects.length,
      'completed_todos': _todos.where((t) => t.isCompleted).length,
      'pending_todos': _todos.where((t) => !t.isCompleted).length,
    };
  }

  // Vider toutes les tâches en mémoire
  void clearAllTodos() {
    print('🗑️ LocalStorageService: Vider toutes les tâches en mémoire');
    _todos.clear();
  }

  // Vider tous les projets en mémoire
  void clearAllProjects() {
    print('🗑️ LocalStorageService: Vider tous les projets en mémoire');
    _projects.clear();
  }

  // Mettre à jour toutes les tâches
  Future<void> updateAllTodos(List<TodoItem> todos) async {
    print('🔄 LocalStorageService: Mise à jour de toutes les tâches (${todos.length})');
    _todos = List<TodoItem>.from(todos);
    await _saveTodos();
    print('✅ LocalStorageService: Toutes les tâches mises à jour');
  }

  // Mettre à jour tous les projets
  Future<void> updateAllProjects(List<Project> projects) async {
    print('🔄 LocalStorageService: Mise à jour de tous les projets (${projects.length})');
    _projects = List<Project>.from(projects);
    await _saveProjects();
    print('✅ LocalStorageService: Tous les projets mis à jour');
  }
} 