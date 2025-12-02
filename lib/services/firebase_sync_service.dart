import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/todo_item.dart';
import '../models/project.dart';
import 'local_storage_service.dart';
import 'preferences_service.dart';
import 'firebase_auth_service.dart';

/// Service de synchronisation Firebase pour toutes les données utilisateur
class FirebaseSyncService {
  static final FirebaseSyncService _instance = FirebaseSyncService._internal();
  factory FirebaseSyncService() => _instance;
  FirebaseSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuthService _authService = FirebaseAuthService();
  final LocalStorageService _localStorage = LocalStorageService();
  final PreferencesService _preferencesService = PreferencesService();

  // Streams pour écouter les changements en temps réel
  StreamSubscription<QuerySnapshot>? _todosSubscription;
  StreamSubscription<QuerySnapshot>? _projectsSubscription;
  StreamSubscription<DocumentSnapshot>? _preferencesSubscription;
  StreamSubscription<DocumentSnapshot>? _timerDataSubscription;

  // État de synchronisation
  bool _isSyncing = false;
  bool _isInitialized = false;
  bool _isHandlingRemoteChanges = false; // Flag pour éviter les boucles de synchronisation
  Timer? _autoSyncTimer;

  // Getters
  bool get isSyncing => _isSyncing;
  bool get isInitialized => _isInitialized;

  /// Initialiser le service de synchronisation
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🔄 FirebaseSyncService: Initialisation...');

      // Vérifier l'authentification
      if (!_authService.isAuthenticated) {
        debugPrint('⚠️ FirebaseSyncService: Aucun utilisateur authentifié');
        return;
      }

      // Activer la persistance offline (uniquement pour Web)
      // Pour Android/iOS, la persistance est activée par défaut
      try {
        if (kIsWeb) {
          await _firestore.enablePersistence();
          debugPrint('✅ FirebaseSyncService: Persistance activée (Web)');
        } else {
          // Pour Android/iOS, la persistance est activée par défaut
          // On peut configurer les settings si nécessaire
          _firestore.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          );
          debugPrint('✅ FirebaseSyncService: Persistance activée (Mobile)');
        }
      } catch (e) {
        debugPrint('⚠️ FirebaseSyncService: Erreur lors de l\'activation de la persistance: $e');
        // Continuer même si la persistance échoue
      }

      // Démarrer l'écoute en temps réel
      _startRealtimeListeners();

      // Démarrer la synchronisation automatique
      _startAutoSync();

      _isInitialized = true;
      debugPrint('✅ FirebaseSyncService: Initialisation terminée');
    } catch (e) {
      debugPrint('❌ FirebaseSyncService: Erreur lors de l\'initialisation: $e');
      rethrow;
    }
  }

  /// Démarrer les écouteurs en temps réel
  void _startRealtimeListeners() {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    // Écouter les changements de tâches
    _todosSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('todos')
        .snapshots()
        .listen(
      (QuerySnapshot snapshot) {
        _handleTodosChanges(snapshot.docs);
      },
      onError: (error) {
        debugPrint('❌ FirebaseSyncService: Erreur lors de l\'écoute des tâches: $error');
      },
    );

    // Écouter les changements de projets
    _projectsSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('projects')
        .snapshots()
        .listen(
      (QuerySnapshot snapshot) {
        _handleProjectsChanges(snapshot.docs);
      },
      onError: (error) {
        debugPrint('❌ FirebaseSyncService: Erreur lors de l\'écoute des projets: $error');
      },
    );

    // Écouter les changements de préférences
    _preferencesSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('preferences')
        .doc('preferences')
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.exists) {
          _handlePreferencesChanges(snapshot.data()!);
        }
      },
      onError: (error) {
        debugPrint('❌ FirebaseSyncService: Erreur lors de l\'écoute des préférences: $error');
      },
    );

    // Écouter les changements de données de timer
    _timerDataSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('timer_data')
        .doc('timer_data')
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.exists) {
          _handleTimerDataChanges(snapshot.data()!);
        }
      },
      onError: (error) {
        debugPrint('❌ FirebaseSyncService: Erreur lors de l\'écoute des données de timer: $error');
      },
    );

    debugPrint('✅ FirebaseSyncService: Écouteurs en temps réel démarrés');
  }

  /// Arrêter les écouteurs en temps réel
  void _stopRealtimeListeners() {
    _todosSubscription?.cancel();
    _projectsSubscription?.cancel();
    _preferencesSubscription?.cancel();
    _timerDataSubscription?.cancel();
    debugPrint('✅ FirebaseSyncService: Écouteurs en temps réel arrêtés');
  }

  /// Démarrer la synchronisation automatique périodique
  void _startAutoSync() {
    // Synchronisation toutes les 5 minutes
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!_isSyncing && _authService.isAuthenticated) {
        syncAll();
      }
    });
    debugPrint('✅ FirebaseSyncService: Synchronisation automatique démarrée');
  }

  /// Arrêter la synchronisation automatique
  void _stopAutoSync() {
    _autoSyncTimer?.cancel();
    debugPrint('✅ FirebaseSyncService: Synchronisation automatique arrêtée');
  }

  /// Synchroniser toutes les données
  Future<void> syncAll() async {
    if (_isSyncing) {
      debugPrint('⚠️ FirebaseSyncService: Synchronisation déjà en cours');
      return;
    }

    if (!_authService.isAuthenticated) {
      debugPrint('⚠️ FirebaseSyncService: Aucun utilisateur authentifié');
      return;
    }

    _isSyncing = true;

    try {
      await Future.wait([
        syncTodos(),
        syncProjects(),
        syncPreferences(),
        syncTimerData(),
      ]);
    } catch (e) {
      debugPrint('❌ FirebaseSyncService: Erreur lors de la synchronisation: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // ========== SYNCHRONISATION DES TÂCHES ==========

  /// Synchroniser les tâches
  Future<void> syncTodos() async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    // Éviter la synchronisation si on est en train de gérer des changements distants
    if (_isHandlingRemoteChanges) {
      return;
    }

    try {
      // 1. Récupérer les tâches depuis Firebase
      final firestoreSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('todos')
          .get();

      final firestoreTodos = firestoreSnapshot.docs
          .map((doc) => TodoItem.fromMap(doc.data()))
          .toList();

      // 2. Récupérer les tâches locales
      final localTodos = _localStorage.todos;

      // 3. Fusionner intelligemment (last-write-wins)
      final mergedTodos = _mergeTodos(localTodos, firestoreTodos);

      // 4. Détecter les suppressions AVANT la fusion
      final firestoreTodoIds = firestoreTodos.map((t) => t.id).toSet();
      final localTodoIds = localTodos.map((t) => t.id).toSet();
      
      // Tâches supprimées dans Firebase (existent localement mais pas dans Firebase)
      final deletedInFirebase = localTodoIds.difference(firestoreTodoIds);
      
      // Tâches supprimées localement (existent dans Firebase mais pas localement)
      final deletedLocally = firestoreTodoIds.difference(localTodoIds);

      // 5. Supprimer les tâches qui ont été supprimées dans Firebase (sauf si modifiées localement récemment)
      final now = DateTime.now();
      final finalTodos = mergedTodos.where((todo) {
        if (deletedInFirebase.contains(todo.id)) {
          // Garder la tâche si elle a été modifiée localement récemment (dans les 5 dernières secondes)
          final timeSinceUpdate = now.difference(todo.updatedAt);
          return timeSinceUpdate.inSeconds < 5;
        }
        return true;
      }).toList();

      // 6. Mettre à jour le cache local
      await _localStorage.updateAllTodos(finalTodos);

      // 7. Synchroniser vers Firebase (uniquement les modifications locales)
      await _syncTodosToFirebase(finalTodos, firestoreTodos);

      // 8. Supprimer de Firebase les tâches supprimées localement
      // (celles qui existent dans Firebase mais plus dans les données locales)
      for (final deletedId in deletedLocally) {
        try {
          await deleteTodoFromFirebase(deletedId);
        } catch (e) {
          // Ignorer les erreurs si la tâche n'existe déjà plus dans Firebase
        }
      }
    } catch (e) {
      debugPrint('❌ FirebaseSyncService: Erreur lors de la synchronisation des tâches: $e');
      rethrow;
    }
  }

  /// Fusionner les tâches locales et Firebase (last-write-wins)
  List<TodoItem> _mergeTodos(List<TodoItem> localTodos, List<TodoItem> firestoreTodos) {
    final Map<int, TodoItem> mergedMap = {};

    // Ajouter les tâches Firebase
    for (final todo in firestoreTodos) {
      mergedMap[todo.id] = todo;
    }

    // Fusionner avec les tâches locales (les plus récentes gagnent)
    for (final localTodo in localTodos) {
      final existing = mergedMap[localTodo.id];
      if (existing == null || localTodo.updatedAt.isAfter(existing.updatedAt)) {
        mergedMap[localTodo.id] = localTodo;
      }
    }

    return mergedMap.values.toList();
  }

  /// Synchroniser les tâches vers Firebase
  Future<void> _syncTodosToFirebase(
    List<TodoItem> currentTodos,
    List<TodoItem> firestoreTodos,
  ) async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    final batch = _firestore.batch();
    int updateCount = 0;

    // Trouver les tâches à mettre à jour
    for (final todo in currentTodos) {
      final firestoreTodo = firestoreTodos.firstWhere(
        (t) => t.id == todo.id,
        orElse: () => TodoItem(
          id: -1,
          title: '',
          description: '',
          priority: Priority.medium,
          isCompleted: false,
        ),
      );

      // Mettre à jour si la version locale est plus récente
      if (firestoreTodo.id == -1 || todo.updatedAt.isAfter(firestoreTodo.updatedAt)) {
        final todoRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('todos')
            .doc(todo.id.toString());

        batch.set(todoRef, todo.toMap(), SetOptions(merge: true));
        updateCount++;
      }
    }

    if (updateCount > 0) {
      await batch.commit();
      debugPrint('✅ FirebaseSyncService: $updateCount tâches mises à jour dans Firebase');
    }
  }

  /// Gérer les changements de tâches en temps réel
  void _handleTodosChanges(List<DocumentSnapshot> docs) {
    if (_isHandlingRemoteChanges) return; // Éviter les appels récursifs
    
    try {
      _isHandlingRemoteChanges = true;
      
      final todos = docs
          .map((doc) => TodoItem.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      // Récupérer les tâches locales actuelles
      final localTodos = _localStorage.todos;
      final localTodoIds = localTodos.map((t) => t.id).toSet();
      final firestoreTodoIds = todos.map((t) => t.id).toSet();

      // Fusionner intelligemment : garder les versions locales plus récentes
      final Map<int, TodoItem> mergedMap = {};
      
      // D'abord, ajouter toutes les tâches de Firebase
      for (final todo in todos) {
        mergedMap[todo.id] = todo;
      }
      
      // Ensuite, remplacer par les versions locales si elles sont plus récentes
      for (final localTodo in localTodos) {
        final firestoreTodo = mergedMap[localTodo.id];
        if (firestoreTodo == null || localTodo.updatedAt.isAfter(firestoreTodo.updatedAt)) {
          mergedMap[localTodo.id] = localTodo;
        }
      }

      // Supprimer les tâches qui n'existent plus dans Firebase ET qui n'ont pas été modifiées localement récemment
      final now = DateTime.now();
      final finalTodos = mergedMap.values.where((todo) {
        // Garder la tâche si elle existe dans Firebase
        if (firestoreTodoIds.contains(todo.id)) return true;
        // Garder la tâche si elle a été modifiée localement récemment (dans les 5 dernières secondes)
        // Cela évite de supprimer une tâche qui vient d'être créée localement
        if (localTodoIds.contains(todo.id)) {
          final timeSinceUpdate = now.difference(todo.updatedAt);
          return timeSinceUpdate.inSeconds < 5;
        }
        return false;
      }).toList();

      // Mettre à jour le cache local sans déclencher de nouvelle synchronisation
      _localStorage.updateAllTodos(finalTodos);
    } catch (e) {
      debugPrint('❌ FirebaseSyncService: Erreur lors de la mise à jour des tâches: $e');
    } finally {
      _isHandlingRemoteChanges = false;
    }
  }

  /// Ajouter ou mettre à jour une tâche dans Firebase
  Future<void> syncTodo(TodoItem todo) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      return;
    }

    // Éviter la synchronisation si on est en train de gérer des changements distants
    if (_isHandlingRemoteChanges) {
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('todos')
          .doc(todo.id.toString())
          .set(todo.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ FirebaseSyncService: Erreur lors de la synchronisation de la tâche ${todo.id}: $e');
      rethrow;
    }
  }

  /// Supprimer une tâche de Firebase
  Future<void> deleteTodoFromFirebase(int todoId) async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('todos')
          .doc(todoId.toString())
          .delete();

    } catch (e) {
      debugPrint('❌ FirebaseSyncService: Erreur lors de la suppression de la tâche: $e');
      rethrow;
    }
  }

  // ========== SYNCHRONISATION DES PROJETS ==========

  /// Synchroniser les projets
  Future<void> syncProjects() async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    try {
      final firestoreSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('projects')
          .get();

      final firestoreProjects = firestoreSnapshot.docs
          .map((doc) => Project.fromMap(doc.data()))
          .toList();

      final localProjects = _localStorage.projects;
      final mergedProjects = _mergeProjects(localProjects, firestoreProjects);

      await _localStorage.updateAllProjects(mergedProjects);
      await _syncProjectsToFirebase(mergedProjects, firestoreProjects);
    } catch (e) {
      debugPrint('❌ FirebaseSyncService: Erreur lors de la synchronisation des projets: $e');
      rethrow;
    }
  }

  List<Project> _mergeProjects(List<Project> localProjects, List<Project> firestoreProjects) {
    final Map<int, Project> mergedMap = {};

    for (final project in firestoreProjects) {
      mergedMap[project.id] = project;
    }

    for (final localProject in localProjects) {
      final existing = mergedMap[localProject.id];
      if (existing == null || localProject.updatedAt.isAfter(existing.updatedAt)) {
        mergedMap[localProject.id] = localProject;
      }
    }

    return mergedMap.values.toList();
  }

  Future<void> _syncProjectsToFirebase(
    List<Project> currentProjects,
    List<Project> firestoreProjects,
  ) async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    final batch = _firestore.batch();
    int updateCount = 0;

    for (final project in currentProjects) {
      final firestoreProject = firestoreProjects.firstWhere(
        (p) => p.id == project.id,
        orElse: () => Project(
          id: -1,
          name: '',
          color: const Color(0xFF000000),
        ),
      );

      if (firestoreProject.id == -1 || project.updatedAt.isAfter(firestoreProject.updatedAt)) {
        final projectRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('projects')
            .doc(project.id.toString());

        batch.set(projectRef, project.toMap(), SetOptions(merge: true));
        updateCount++;
      }
    }

      if (updateCount > 0) {
        await batch.commit();
      }
  }

  void _handleProjectsChanges(List<DocumentSnapshot> docs) {
    if (_isHandlingRemoteChanges) return;
    
    try {
      _isHandlingRemoteChanges = true;
      
      final projects = docs
          .map((doc) => Project.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      // Fusionner intelligemment avec les projets locaux
      final localProjects = _localStorage.projects;
      final mergedProjects = _mergeProjects(localProjects, projects);
      
      _localStorage.updateAllProjects(mergedProjects);
    } catch (e) {
      debugPrint('❌ FirebaseSyncService: Erreur lors de la mise à jour des projets: $e');
    } finally {
      _isHandlingRemoteChanges = false;
    }
  }

  Future<void> syncProject(Project project) async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('projects')
          .doc(project.id.toString())
          .set(project.toMap(), SetOptions(merge: true));

    } catch (e) {
      debugPrint('❌ FirebaseSyncService: Erreur lors de la synchronisation du projet: $e');
      rethrow;
    }
  }

  Future<void> deleteProjectFromFirebase(int projectId) async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('projects')
          .doc(projectId.toString())
          .delete();

    } catch (e) {
      debugPrint('❌ FirebaseSyncService: Erreur lors de la suppression du projet: $e');
      rethrow;
    }
  }

  // ========== SYNCHRONISATION DES PRÉFÉRENCES ==========

  Future<void> syncPreferences() async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    try {
      final prefsDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('preferences')
          .get();

      final firestorePrefs = prefsDoc.exists
          ? Map<String, dynamic>.from(prefsDoc.data()!)
          : <String, dynamic>{};

      final localPrefs = _preferencesService.getAllPreferences();
      final mergedPrefs = _mergePreferences(localPrefs, firestorePrefs);

      // Mettre à jour les préférences locales
      for (final entry in mergedPrefs.entries) {
        await _preferencesService.setPreference(entry.key, entry.value);
      }

      // Synchroniser vers Firebase
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('preferences')
          .set(mergedPrefs, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ FirebaseSyncService: Erreur lors de la synchronisation des préférences: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _mergePreferences(
    Map<String, dynamic> localPrefs,
    Map<String, dynamic> firestorePrefs,
  ) {
    // Merge simple : les préférences locales ont la priorité
    final merged = Map<String, dynamic>.from(firestorePrefs);
    merged.addAll(localPrefs);
    return merged;
  }

  void _handlePreferencesChanges(Map<String, dynamic> data) {
    if (_isHandlingRemoteChanges) return;
    
    try {
      _isHandlingRemoteChanges = true;
      
      for (final entry in data.entries) {
        _preferencesService.setPreference(entry.key, entry.value);
      }
    } catch (e) {
      debugPrint('❌ FirebaseSyncService: Erreur lors de la mise à jour des préférences: $e');
    } finally {
      _isHandlingRemoteChanges = false;
    }
  }

  // ========== SYNCHRONISATION DES DONNÉES DE TIMER ==========

  Future<void> syncTimerData() async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    try {
      final timerDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('timer_data')
          .doc('timer_data')
          .get();

      final firestoreTimerData = timerDoc.exists
          ? Map<String, dynamic>.from(timerDoc.data()!)
          : <String, dynamic>{};

      final localTimerData = _localStorage.timerData;
      final mergedTimerData = _mergeTimerData(localTimerData, firestoreTimerData);

      // Mettre à jour les données de timer locales
      for (final entry in mergedTimerData.entries) {
        await _localStorage.setTimerData(entry.key, entry.value);
      }

      // Synchroniser vers Firebase
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('timer_data')
          .doc('timer_data')
          .set(mergedTimerData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ FirebaseSyncService: Erreur lors de la synchronisation des données de timer: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _mergeTimerData(
    Map<String, dynamic> localTimerData,
    Map<String, dynamic> firestoreTimerData,
  ) {
    final merged = Map<String, dynamic>.from(firestoreTimerData);
    merged.addAll(localTimerData);
    return merged;
  }

  void _handleTimerDataChanges(Map<String, dynamic> data) {
    if (_isHandlingRemoteChanges) return;
    
    try {
      _isHandlingRemoteChanges = true;
      
      for (final entry in data.entries) {
        _localStorage.setTimerData(entry.key, entry.value);
      }
    } catch (e) {
      debugPrint('❌ FirebaseSyncService: Erreur lors de la mise à jour des données de timer: $e');
    } finally {
      _isHandlingRemoteChanges = false;
    }
  }

  // ========== NETTOYAGE ==========

  /// Arrêter le service et nettoyer les ressources
  void dispose() {
    _stopRealtimeListeners();
    _stopAutoSync();
    _isInitialized = false;
    debugPrint('✅ FirebaseSyncService: Service arrêté');
  }
}

