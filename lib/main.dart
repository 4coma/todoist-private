import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'themes.dart';
import 'services/notification_service.dart';
import 'services/local_storage_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'services/timer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/data_export_import_service.dart';
import 'services/file_service.dart';
import 'models/project.dart';
import 'models/todo_item.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'services/test_data_generator_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'screens/design_system_demo.dart';
import 'design_system/tokens.dart';
import 'design_system/widgets.dart';
import 'design_system/forms.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/firebase_auth_service.dart';
import 'services/firebase_sync_service.dart';
import 'services/firebase_migration_service.dart';
import 'services/project_service.dart';
import 'services/preferences_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser Firebase
  try {
    print('🔄 Tentative d\'initialisation Firebase...');
    await Firebase.initializeApp();
    print('✅ Firebase initialisé avec succès');
    debugPrint('✅ Firebase initialisé');
  } catch (e, stackTrace) {
    print('❌ ERREUR Firebase: $e');
    print('❌ Stack trace: $stackTrace');
    debugPrint('⚠️ Firebase non initialisé (configuration manquante?): $e');
    // L'application peut continuer sans Firebase si non configuré
  }
  
  // Initialiser le service de stockage local
  final localStorageService = LocalStorageService();
  await localStorageService.initialize();
  
  // Initialiser le service de notifications
  await NotificationService.initialize();
  
  // Initialiser Firebase Sync si un utilisateur est connecté
  try {
    final authService = FirebaseAuthService();
    
    // Test d'authentification anonyme (pour tester la synchronisation)
    if (!authService.isAuthenticated) {
      try {
        print('🔄 Tentative d\'authentification anonyme...');
        await authService.signInAnonymously();
        final userId = authService.currentUserId;
        print('✅ Authentifié anonymement avec succès');
        print('   👤 User ID: $userId');
        print('   📍 Chemin Firestore: users/$userId/');
        debugPrint('✅ Authentifié anonymement');
      } catch (e, stackTrace) {
        print('❌ ERREUR authentification anonyme: $e');
        print('❌ Stack trace: $stackTrace');
        debugPrint('⚠️ Erreur lors de l\'authentification anonyme: $e');
      }
    }
    
    if (authService.isAuthenticated) {
      print('🔄 Initialisation de la synchronisation Firebase...');
      final syncService = FirebaseSyncService();
      await syncService.initialize();
      print('✅ Firebase Sync initialisé avec succès');
      debugPrint('✅ Firebase Sync initialisé pour l\'utilisateur connecté');
      
      // Vérifier et effectuer la migration si nécessaire
      final migrationService = FirebaseMigrationService();
      if (!await migrationService.hasMigrated() && migrationService.hasDataToMigrate()) {
        print('🔄 Données locales détectées, migration automatique...');
        debugPrint('🔄 Données locales détectées, migration automatique...');
        try {
          await migrationService.migrateAllData();
          print('✅ Migration terminée avec succès');
        } catch (e, stackTrace) {
          print('❌ ERREUR migration: $e');
          print('❌ Stack trace: $stackTrace');
          debugPrint('⚠️ Erreur lors de la migration automatique: $e');
        }
      } else {
        print('ℹ️ Aucune migration nécessaire (déjà migré ou pas de données)');
        
        // Forcer la synchronisation de toutes les tâches existantes (pour réparer)
        // TODO: Retirer ce code après vérification
        try {
          print('🔄 Synchronisation forcée de toutes les tâches existantes...');
          await migrationService.forceSyncAllTodos();
          print('✅ Synchronisation forcée terminée');
        } catch (e) {
          print('⚠️ Erreur lors de la synchronisation forcée: $e');
        }
      }
    } else {
      print('⚠️ Aucun utilisateur authentifié, synchronisation Firebase désactivée');
    }
  } catch (e, stackTrace) {
    print('❌ ERREUR générale Firebase Sync: $e');
    print('❌ Stack trace: $stackTrace');
    debugPrint('⚠️ Erreur lors de l\'initialisation Firebase Sync: $e');
    // L'application peut continuer sans synchronisation Firebase
  }
  
  // Demander les permissions de notification explicitement
  try {
    final hasPermission = await NotificationService.requestPermission();
    debugPrint('🔍 Permissions demandées: $hasPermission');
  } catch (e) {
    debugPrint('❌ Erreur lors de la demande de permissions: $e');
  }
  
  // Vérifier l'état des permissions
  await NotificationService.checkPermissions();
  
  // Configurer l'écoute des notifications pour la navigation
  NotificationService.listenToActionStream(_handleNotificationAction);
  
  runApp(const TodoApp());
}

// Variable globale pour accéder à l'état de la page principale
_TodoHomePageState? _globalHomePageState;

void _handleNotificationAction(ReceivedAction action) {
  debugPrint('🔔 Notification cliquée: ${action.payload}');
  
  // Extraire l'ID de la tâche du payload
  final taskIdString = action.payload?['taskId'];
  if (taskIdString != null) {
    final taskId = int.tryParse(taskIdString);
    if (taskId != null && _globalHomePageState != null) {
      debugPrint('🔔 Navigation vers la tâche ID: $taskId');
      try {
        _globalHomePageState!._navigateToTask(taskId);
      } catch (e) {
        debugPrint('❌ Erreur lors de la navigation vers la tâche $taskId: $e');
        // Afficher un message d'erreur à l'utilisateur
        if (_globalHomePageState!.mounted) {
          ScaffoldMessenger.of(_globalHomePageState!.context).showSnackBar(
            SnackBar(
              content: Text('Tâche non trouvée ou supprimée'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }
}

class TodoApp extends StatefulWidget {
  const TodoApp({super.key});

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  ThemeData _currentTheme = AppThemes.blueTheme;
  String _selectedColor = 'blue';
  bool _isDarkMode = false;
  bool _autoThemeMode = false;
  Timer? _themeCheckTimer;

  @override
  void initState() {
    super.initState();
    _loadSavedTheme();
    _startThemeCheckTimer();
  }

  @override
  void dispose() {
    _themeCheckTimer?.cancel();
    super.dispose();
  }

  /// Détermine si le mode sombre doit être activé selon l'heure (21h-8h)
  bool _shouldUseDarkModeByTime() {
    final now = DateTime.now();
    final hour = now.hour;
    // Dark mode de 21h (21) à 8h (8) du matin
    return hour >= 21 || hour < 8;
  }

  /// Vérifie l'heure et met à jour le thème si nécessaire
  void _checkAndUpdateTheme() {
    if (_autoThemeMode) {
      final shouldBeDark = _shouldUseDarkModeByTime();
      if (shouldBeDark != _isDarkMode) {
        setState(() {
          _isDarkMode = shouldBeDark;
          _currentTheme = AppThemes.getTheme(_selectedColor, _isDarkMode);
        });
        debugPrint('🔄 Thème automatique mis à jour: ${_isDarkMode ? "dark" : "light"}');
      }
    }
  }

  /// Démarre un timer pour vérifier périodiquement l'heure
  void _startThemeCheckTimer() {
    _themeCheckTimer?.cancel();
    if (_autoThemeMode) {
      // Vérifier toutes les minutes
      _themeCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
        _checkAndUpdateTheme();
      });
    }
  }

  Future<void> _loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedColor = prefs.getString('selected_color') ?? 'blue';
      final isDarkMode = prefs.getBool('is_dark_mode') ?? false;
      final autoThemeMode = prefs.getBool('auto_theme_mode') ?? false;
      
      setState(() {
        _selectedColor = selectedColor;
        _autoThemeMode = autoThemeMode;
        
        // Si le mode automatique est activé, déterminer le thème selon l'heure
        if (autoThemeMode) {
          _isDarkMode = _shouldUseDarkModeByTime();
        } else {
          _isDarkMode = isDarkMode;
        }
        
        _currentTheme = AppThemes.getTheme(selectedColor, _isDarkMode);
      });
      
      _startThemeCheckTimer();
      debugPrint('✅ Thème chargé: couleur=$selectedColor, dark=$_isDarkMode, auto=$autoThemeMode');
    } catch (e) {
      debugPrint('❌ Erreur lors du chargement du thème: $e');
    }
  }

  void _changeTheme(String colorName, bool isDarkMode) async {
    setState(() {
      _selectedColor = colorName;
      // Si le mode automatique est activé, ne pas changer manuellement le dark mode
      if (!_autoThemeMode) {
        _isDarkMode = isDarkMode;
      }
      _currentTheme = AppThemes.getTheme(colorName, _isDarkMode);
    });
    
    // Sauvegarder les préférences de thème
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_color', colorName);
      if (!_autoThemeMode) {
        await prefs.setBool('is_dark_mode', isDarkMode);
      }
      debugPrint('✅ Thème sauvegardé: couleur=$colorName, dark=$_isDarkMode, auto=$_autoThemeMode');
    } catch (e) {
      debugPrint('❌ Erreur lors de la sauvegarde du thème: $e');
    }
  }

  void _setAutoThemeMode(bool enabled) async {
    bool newDarkMode = _isDarkMode;
    
    if (enabled) {
      // Activer le mode automatique : déterminer le thème selon l'heure
      newDarkMode = _shouldUseDarkModeByTime();
    } else {
      // Désactiver le mode automatique : charger la préférence sauvegardée
      try {
        final prefs = await SharedPreferences.getInstance();
        newDarkMode = prefs.getBool('is_dark_mode') ?? false;
      } catch (e) {
        debugPrint('❌ Erreur lors du chargement de la préférence dark mode: $e');
      }
    }
    
    setState(() {
      _autoThemeMode = enabled;
      _isDarkMode = newDarkMode;
      _currentTheme = AppThemes.getTheme(_selectedColor, _isDarkMode);
    });
    
    _startThemeCheckTimer();
    
    // Sauvegarder la préférence
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_theme_mode', enabled);
      debugPrint('✅ Mode automatique ${enabled ? "activé" : "désactivé"}');
    } catch (e) {
      debugPrint('❌ Erreur lors de la sauvegarde du mode automatique: $e');
    }
  }

  // Méthode de compatibilité avec l'ancien système
  void _changeThemeLegacy(ThemeData theme) async {
    setState(() {
      _currentTheme = theme;
    });
    
    // Sauvegarder le thème sélectionné
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeName = _getThemeName(theme);
      await prefs.setString('selected_theme', themeName);
      debugPrint('✅ Thème sauvegardé: $themeName');
    } catch (e) {
      debugPrint('❌ Erreur lors de la sauvegarde du thème: $e');
    }
  }

  ThemeData _getThemeFromName(String themeName) {
    switch (themeName) {
      case 'blue':
        return AppThemes.blueTheme;
      case 'green':
        return AppThemes.greenTheme;
      case 'purple':
        return AppThemes.purpleTheme;
      case 'orange':
        return AppThemes.orangeTheme;
      case 'gradient':
        return AppThemes.gradientTheme;
      case 'dark':
        return AppThemes.darkTheme;
      case 'minimal':
        return AppThemes.minimalTheme;
      default:
        return AppThemes.blueTheme;
    }
  }

  String _getThemeName(ThemeData theme) {
    if (theme == AppThemes.blueTheme) return 'blue';
    if (theme == AppThemes.greenTheme) return 'green';
    if (theme == AppThemes.purpleTheme) return 'purple';
    if (theme == AppThemes.orangeTheme) return 'orange';
    if (theme == AppThemes.gradientTheme) return 'gradient';
    if (theme == AppThemes.darkTheme) return 'dark';
    if (theme == AppThemes.minimalTheme) return 'minimal';
    return 'blue';
  }

  @override
  Widget build(BuildContext context) {
    // Créer les thèmes clair et sombre basés sur la couleur sélectionnée
    final lightTheme = AppThemes.getTheme(_selectedColor, false);
    final darkTheme = AppThemes.getTheme(_selectedColor, true);
    
    return MaterialApp(
      title: 'Todo App',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false, // Enlève le banner DEBUG
      locale: const Locale('fr', 'BE'), // Locale belge (lundi comme premier jour)
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'BE'), // Français belge
        Locale('fr'), // Français par défaut
      ],
      home: TodoHomePage(
        onThemeChanged: _changeTheme,
        onThemeChangedLegacy: _changeThemeLegacy,
        autoThemeMode: _autoThemeMode,
        onAutoThemeModeChanged: _setAutoThemeMode,
      ),
    );
  }
}

enum SortType {
  dueDate,
  name,
  dateAdded,
  priority,
}

enum ViewMode {
  list,
  calendar,
}

class TodoHomePage extends StatefulWidget {
  final Function(String, bool) onThemeChanged;
  final Function(ThemeData) onThemeChangedLegacy;
  final bool autoThemeMode;
  final Function(bool) onAutoThemeModeChanged;
  
  const TodoHomePage({
    super.key, 
    required this.onThemeChanged,
    required this.onThemeChangedLegacy,
    this.autoThemeMode = false,
    required this.onAutoThemeModeChanged,
  });

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Project> _projects = [];
  List<TodoItem> _todos = [];
  Project? _selectedProject;
  SortType _currentSort = SortType.dateAdded;
  ViewMode _currentView = ViewMode.list;
  DateTime _calendarSelectedDate = DateTime.now();
  bool _isSidebarOpen = false;
  bool _showDescriptions = false;
  bool _showCompletedTasks = false; // Mode "Tâches achevées" (sidebar)
  bool _showCompletedTasksInProjects = false; // Option "Afficher les tâches terminées" (paramètres)
  bool _showNoProjectTasks = false; // Mode "Tâches sans projet"
  bool _showShoppingList = false; // Mode "Courses" (liste de courses)
  bool _isSearchActive = false; // État de la recherche
  String _searchQuery = ''; // Terme de recherche

  String _openAiApiKeys = '';
  
  // Variables pour le nouveau système de thèmes
  String _selectedColor = 'blue';
  bool _isDarkMode = false;

  // Set pour suivre les tâches dépliées (affichant leurs sous-tâches)
  final Set<int> _expandedTasks = {};

  final TimerService _timerService = TimerService();

  @override
  void initState() {
    super.initState();
    _timerService.addListener(_onTimerTick);
    _loadData();
    _loadSettings();
    _loadThemePreferences();
    
    // Configurer la variable globale pour la navigation depuis les notifications
    _globalHomePageState = this;
  }

  @override
  void dispose() {
    _timerService.removeListener(_onTimerTick);
    // Sauvegarder les données avant de fermer l'app
    _saveData();
    super.dispose();
  }

  void _onTimerTick() {
    if (_timerService.isRunning && _timerService.currentTaskId != -1) {
      setState(() {}); // Pour rafraîchir l'affichage du temps en cours
    }
  }

  void _handlePlayPause(TodoItem todo) {
    if (_timerService.isTaskRunning(todo.id)) {
      final seconds = _timerService.elapsedSeconds;
      setState(() {
        final index = _todos.indexWhere((t) => t.id == todo.id);
        if (index != -1) {
          _todos[index].elapsedSeconds += seconds;
        }
      });
      _timerService.pauseTimer();
      _saveData();
    } else {
      final alreadyElapsedSeconds = todo.elapsedSeconds;
      _timerService.startTimer(todo.id, alreadyElapsedSeconds: alreadyElapsedSeconds);
    }
    setState(() {});
  }

  // Charger les données sauvegardées
  Future<void> _loadData() async {
    try {
      debugPrint('🔄 _loadData(): Début du chargement des données...');
      final localStorageService = LocalStorageService();
      

      
      // Charger les projets (créer une copie modifiable)
      setState(() {
        _projects = List<Project>.from(localStorageService.projects);
        _selectedProject = null; // Afficher "Toutes les tâches" par défaut
      });
      debugPrint('✅ _loadData(): ${_projects.length} projets chargés');

      // Charger les tâches (créer une copie modifiable)
      setState(() {
        _todos = List<TodoItem>.from(localStorageService.todos);
      });
      debugPrint('✅ _loadData(): ${_todos.length} tâches chargées');

      // Charger les paramètres utilisateur
      await _loadSettings();

      // Reprogrammer les notifications pour les tâches avec rappel
      await _rescheduleNotifications();
      
      // Forcer la mise à jour de l'interface
      setState(() {});
      
      debugPrint('✅ _loadData(): Données chargées avec succès - ${_projects.length} projets, ${_todos.length} tâches');
    } catch (e) {
      debugPrint('❌ _loadData(): Erreur lors du chargement des données: $e');
    }
  }

  // Charger les paramètres utilisateur
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final preferencesService = PreferencesService();
      setState(() {
        _showDescriptions = prefs.getBool('show_descriptions') ?? false;
        _showCompletedTasksInProjects = prefs.getBool('show_completed_tasks') ?? false;
        _openAiApiKeys = prefs.getString('openai_api_keys') ?? '';
      });
      
      // Vérifier si la liste de courses est activée et créer le projet si nécessaire
      final shoppingListEnabled = preferencesService.shoppingListEnabled;
      if (shoppingListEnabled) {
        final projectService = ProjectService();
        try {
          await projectService.getOrCreateShoppingListProject();
          // Recharger les projets pour inclure le projet "courses"
          final localStorageService = LocalStorageService();
          setState(() {
            _projects = List<Project>.from(localStorageService.projects);
          });
        } catch (e) {
          debugPrint('⚠️ Erreur lors de la création du projet courses: $e');
        }
      }
      
      debugPrint('✅ Paramètres chargés: show_descriptions = $_showDescriptions, show_completed_tasks_in_projects = $_showCompletedTasksInProjects, openai_keys_présents = ${_openAiApiKeys.isNotEmpty}, shopping_list_enabled = $shoppingListEnabled');
    } catch (e) {
      debugPrint('❌ Erreur lors du chargement des paramètres: $e');
    }
  }

  // Charger les préférences de thème
  Future<void> _loadThemePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _selectedColor = prefs.getString('selected_color') ?? 'blue';
        _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
      });
      debugPrint('✅ Préférences de thème chargées: couleur = $_selectedColor, dark = $_isDarkMode');
    } catch (e) {
      debugPrint('❌ Erreur lors du chargement des préférences de thème: $e');
    }
  }

  // Sauvegarder les paramètres utilisateur
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('show_descriptions', _showDescriptions);
      await prefs.setBool('show_completed_tasks', _showCompletedTasksInProjects);
      debugPrint('✅ Paramètres sauvegardés: show_descriptions = $_showDescriptions, show_completed_tasks_in_projects = $_showCompletedTasksInProjects');
    } catch (e) {
      debugPrint('❌ Erreur lors de la sauvegarde des paramètres: $e');
    }
  }

  // Reprogrammer les notifications pour toutes les tâches avec rappel
  Future<void> _rescheduleNotifications() async {
    try {
      debugPrint('🔄 _rescheduleNotifications(): Début de la reprogrammation...');
      
      // Ne PAS annuler toutes les notifications - cela supprime même celles déjà affichées
      // Au lieu de cela, on annule uniquement les notifications pour les tâches qui n'ont plus besoin de rappel
      int cancelledCount = 0;
      for (final todo in _todos) {
        // Annuler la notification si :
        // - La tâche est terminée
        // - La tâche n'a plus de rappel
        // - Le rappel est dans le passé
        if (todo.isCompleted || 
            todo.reminder == null || 
            (todo.reminder != null && todo.reminder!.isBefore(DateTime.now()))) {
          try {
            await NotificationService.cancelTaskNotification(todo.id);
            cancelledCount++;
            debugPrint('🔄 _rescheduleNotifications(): Notification annulée pour tâche ${todo.id} (terminée/sans rappel/rappel passé)');
          } catch (e) {
            debugPrint('❌ _rescheduleNotifications(): Erreur lors de l\'annulation pour tâche ${todo.id}: $e');
          }
        }
      }
      debugPrint('🔄 _rescheduleNotifications(): $cancelledCount notifications annulées (tâches terminées/sans rappel)');
      
      // Programmer les notifications pour les tâches avec rappel valide
      // awesome_notifications gère automatiquement les doublons si on utilise le même ID
      int scheduledCount = 0;
      for (final todo in _todos) {
        if (todo.reminder != null && todo.reminder!.isAfter(DateTime.now()) && !todo.isCompleted) {
          try {
            await NotificationService.scheduleTaskReminder(
              taskId: todo.id,
              title: todo.title,
              body: todo.description.isNotEmpty ? todo.description : 'Rappel de tâche',
              scheduledDate: todo.reminder!,
            );
            scheduledCount++;
            debugPrint('🔄 _rescheduleNotifications(): Notification programmée pour "${todo.title}" à ${todo.reminder}');
          } catch (e) {
            debugPrint('❌ _rescheduleNotifications(): Erreur pour la tâche ${todo.id}: $e');
          }
        }
      }
      
      debugPrint('✅ _rescheduleNotifications(): $scheduledCount notifications programmées avec succès');
    } catch (e) {
      debugPrint('❌ _rescheduleNotifications(): Erreur lors de la reprogrammation des rappels: $e');
    }
  }

  // Méthode pour sauvegarder les données
  Future<void> _saveData() async {
    try {
      debugPrint('🔄 _saveData(): Début de la sauvegarde...');
      debugPrint('🔄 _saveData(): ${_projects.length} projets à sauvegarder');
      debugPrint('🔄 _saveData(): ${_todos.length} tâches à sauvegarder');
      
      final localStorageService = LocalStorageService();
      await localStorageService.updateAllProjects(_projects);
      await localStorageService.updateAllTodos(_todos);
      
      // Recharger les données depuis le service pour s'assurer de la cohérence
      setState(() {
        _projects = List<Project>.from(localStorageService.projects);
        _todos = List<TodoItem>.from(localStorageService.todos);
      });
      
      // Forcer le rafraîchissement de la sidebar
      _refreshSidebarCounts();
      
      debugPrint('✅ _saveData(): Données sauvegardées avec succès');
      debugPrint('✅ _saveData(): ${_projects.length} projets, ${_todos.length} tâches');
    } catch (e) {
      debugPrint('❌ _saveData(): Erreur lors de la sauvegarde: $e');
    }
  }

  // Méthode pour rafraîchir les compteurs de la sidebar
  void _refreshSidebarCounts() {
    debugPrint('🔄 _refreshSidebarCounts(): Rafraîchissement des compteurs de la sidebar');
    
    // Forcer un setState pour rafraîchir la sidebar
    setState(() {
      debugPrint('🔄 _refreshSidebarCounts(): setState() appelé');
    });
    
    // Log des compteurs pour chaque projet
    for (final project in _projects) {
      final taskCount = _todos.where((todo) => todo.projectId == project.id && !todo.isCompleted).length;
      debugPrint('🔄 _refreshSidebarCounts(): Projet "${project.name}": $taskCount tâches');
    }
  }

  Future<void> _handleTodoResult(dynamic result) async {
    if (result != null && result['todo'] != null) {
      final newTodo = result['todo'] as TodoItem;
      final rawSubTasks = result['subTasks'] as List?;
      final List<TodoItem> subTasks = [];

      if (rawSubTasks != null) {
        for (final item in rawSubTasks) {
          if (item is TodoItem) {
            subTasks.add(item);
          } else if (item is Map<String, dynamic>) {
            // Support fallback if les sous-tâches arrivent sérialisées
            try {
              subTasks.add(TodoItem.fromJson(item));
            } catch (_) {
              try {
                subTasks.add(TodoItem.fromMap(item));
              } catch (_) {
                debugPrint('❌ Impossible de parser une sous-tâche: $item');
              }
            }
          }
        }
      }
      
      setState(() {
        _todos.add(newTodo);
        
        // Ajouter les sous-tâches avec le bon parentId
        for (final subTask in subTasks) {
          final updatedSubTask = subTask.copyWith(
            parentId: newTodo.id, // Lier à la tâche parente
            level: newTodo.level + 1,
            projectId: newTodo.projectId, // Hériter du projet de la tâche principale
          );
          _todos.add(updatedSubTask);
        }
      });
      
      // Sauvegarder les données
      await _saveData();
      // Planifier la notification pour la tâche principale
      if (newTodo.reminder != null) {
        await NotificationService.scheduleTaskReminder(
          taskId: newTodo.id,
          title: newTodo.title,
          body: newTodo.description.isNotEmpty ? newTodo.description : 'Rappel de tâche',
          scheduledDate: newTodo.reminder!,
        );
      }
      // Planifier les notifications pour les sous-tâches
      for (final subTask in subTasks) {
        if (subTask.reminder != null) {
          await NotificationService.scheduleTaskReminder(
            taskId: subTask.id,
            title: subTask.title,
            body: subTask.description.isNotEmpty ? subTask.description : 'Rappel de sous-tâche',
            scheduledDate: subTask.reminder!,
          );
        }
      }

      // Afficher un toast de confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tâche "${newTodo.title}" ajoutée'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _addTodo() {
    // Si on est dans la vue "Courses", sélectionner automatiquement le projet "courses"
    Project? projectToSelect = _selectedProject;
    if (_showShoppingList) {
      final shoppingListProject = ProjectService().getShoppingListProject();
      if (shoppingListProject != null) {
        projectToSelect = shoppingListProject;
      }
    }
    
    // Inclure le projet "courses" dans la liste des projets si activé
    final List<Project> projectsToShow = List.from(_projects);
    if (PreferencesService().shoppingListEnabled) {
      final shoppingListProject = ProjectService().getShoppingListProject();
      if (shoppingListProject != null && !projectsToShow.any((p) => p.id == shoppingListProject.id)) {
        projectsToShow.add(shoppingListProject);
      }
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Transparent pour laisser le fond blanc du container
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white, // Force white fill color
          ),
        ),
        child: AddTodoModal(
        projects: projectsToShow,
        selectedProject: projectToSelect, // Passer le projet sélectionné (ou "courses" si dans la vue courses)
        ),
      ),
    ).then(_handleTodoResult);
  }

  Future<String?> _recordAudio() async {
    final recorder = AudioRecorder();
    if (!await recorder.hasPermission()) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) return null;
    }
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/todo_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: filePath);

    // Interface d'enregistrement améliorée
    final shouldSave = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Builder(
        builder: (context) {
          final brightness = Theme.of(context).brightness;
          final surfaceColor = DSColor.getSurface(brightness);
          final headingColor = DSColor.getHeading(brightness);
          final primaryColor = DSColor.primary;
          final bottomPadding = MediaQuery.of(context).padding.bottom;
          
          return Padding(
            padding: EdgeInsets.only(bottom: bottomPadding + 16), // Remonter la modale
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: DSShadow.card,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                // Indicateur d'enregistrement (Microphone pulsant ou actif)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.mic, size: 48, color: primaryColor),
                ),
                const SizedBox(height: 24),
                Text(
                  'Je vous écoute...',
                  style: DSTypo.h2.copyWith(color: headingColor),
                ),
                const SizedBox(height: 8),
                Text(
                  'Parlez maintenant pour créer une tâche',
                  style: DSTypo.body.copyWith(color: DSColor.getMuted(brightness)),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: DSButton.secondary(
                        label: 'Annuler',
                        icon: Icons.close,
                        onPressed: () => Navigator.of(ctx).pop(false),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DSButton(
                        label: 'Terminer',
                        icon: Icons.check,
                        onPressed: () => Navigator.of(ctx).pop(true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
            ),
          );
        },
      ),
    );

    final path = await recorder.stop();
    await recorder.dispose();

    if (shouldSave == true) {
      return path;
    } else {
      // Si annulé, on essaie de supprimer le fichier temporaire
      if (path != null) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('Erreur lors de la suppression du fichier vocal annulé: $e');
        }
      }
      return null;
    }
  }

  Future<String?> _transcribeAudio(String path, String apiKey) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
    )
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..fields['model'] = 'whisper-1'
      ..files.add(await http.MultipartFile.fromPath('file', path));

    final response = await request.send();
    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      final data = jsonDecode(respStr);
      return data['text'];
    }
    return null;
  }

  /// Détecte si la transcription mentionne la liste de courses
  bool _isShoppingListRequest(String text) {
    final lowerText = text.toLowerCase();
    final shoppingKeywords = [
      'liste de courses',
      'liste des courses',
      'ajoute à la liste de courses',
      'ajouter à la liste de courses',
      'ajoute à la liste des courses',
      'ajouter à la liste des courses',
      'ajoute à courses',
      'ajouter à courses',
      'ajoute aux courses',
      'ajouter aux courses',
      'courses',
      'liste courses',
      'shopping list',
    ];
    
    return shoppingKeywords.any((keyword) => lowerText.contains(keyword));
  }

  /// Extrait plusieurs éléments de la liste de courses depuis un texte
  Future<List<Map<String, dynamic>>> _extractShoppingListItemsFromText(
      String text, String apiKey) async {
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    
    final prompt = '''
Tu es un assistant intelligent pour gérer une liste de courses. Analyse le texte suivant et extrait TOUS les éléments de courses mentionnés.

Texte: "$text"

INSTRUCTIONS IMPORTANTES :
1. Si l'utilisateur mentionne "ajoute à la liste de courses", "ajouter aux courses", "liste de courses", etc., tu DOIS extraire TOUS les éléments mentionnés.
2. Décompose la phrase en éléments individuels. Par exemple :
   - "lait, fromage, oeufs, sel" → 4 éléments séparés
   - "du sucre, du miel, du lait" → 3 éléments séparés
   - "ajoute à la liste de courses les éléments suivants : lait, fromage, oeufs... et puis du sel aussi" → 4 éléments séparés
3. Pour chaque élément, crée un objet avec :
   - "title": Le nom de l'élément (ex: "Lait", "Fromage", "Oeufs", "Sel")
   - "description": Optionnel, peut être vide
   - "dueDate": null (pas de date d'échéance pour les courses)
   - "reminder": null (pas de rappel par défaut pour les courses)
4. Nettoie les noms d'éléments : enlève les articles ("du", "de la", "des", "le", "la", "les") et garde uniquement le nom de l'élément.
5. Si plusieurs éléments sont mentionnés, retourne TOUS les éléments dans un tableau.

EXEMPLES :
- "ajoute à la liste de courses : lait, fromage, oeufs" → 
  [
    {"title": "Lait", "description": "", "dueDate": null, "reminder": null},
    {"title": "Fromage", "description": "", "dueDate": null, "reminder": null},
    {"title": "Oeufs", "description": "", "dueDate": null, "reminder": null}
  ]

- "ajoute du sucre, du miel et du lait à la liste de courses" →
  [
    {"title": "Sucre", "description": "", "dueDate": null, "reminder": null},
    {"title": "Miel", "description": "", "dueDate": null, "reminder": null},
    {"title": "Lait", "description": "", "dueDate": null, "reminder": null}
  ]

- "ajoute à la liste de courses les éléments suivants : lait, fromage, oeufs... et puis du sel aussi" →
  [
    {"title": "Lait", "description": "", "dueDate": null, "reminder": null},
    {"title": "Fromage", "description": "", "dueDate": null, "reminder": null},
    {"title": "Oeufs", "description": "", "dueDate": null, "reminder": null},
    {"title": "Sel", "description": "", "dueDate": null, "reminder": null}
  ]

Réponds UNIQUEMENT avec un objet JSON contenant un tableau "items" respectant ce format :
{
  "items": [
    {"title": "...", "description": "...", "dueDate": null, "reminder": null},
    {"title": "...", "description": "...", "dueDate": null, "reminder": null},
    ...
  ]
}
''';

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      final jsonData = jsonDecode(content);
      
      // Le modèle retourne un objet JSON avec une clé "items" contenant le tableau
      List<dynamic> items;
      if (jsonData is Map && jsonData.containsKey('items')) {
        items = jsonData['items'] as List<dynamic>;
      } else if (jsonData is Map && jsonData.containsKey('todos')) {
        items = jsonData['todos'] as List<dynamic>;
      } else if (jsonData is List) {
        items = jsonData;
      } else {
        // Si c'est un objet avec des clés numériques, convertir en liste
        items = jsonData.values.toList();
      }
      
      return items.map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>?> _extractTodoFromText(
      String text, String apiKey) async {
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    
    // Formater la date actuelle de manière lisible en français
    final dayNames = ['dimanche', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'];
    final monthNames = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 
                        'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    // DateTime.weekday: 1=lundi, 2=mardi, ..., 7=dimanche
    // Pour notre tableau [dim, lun, mar, mer, jeu, ven, sam] (index 0-6)
    // weekday 1 (lundi) -> index 1, weekday 7 (dimanche) -> index 0
    final dayIndex = now.weekday == 7 ? 0 : now.weekday;
    final currentDayName = dayNames[dayIndex];
    final currentMonthName = monthNames[now.month - 1];
    final currentDateFormatted = '$currentDayName ${now.day} $currentMonthName ${now.year}';
    
    final prompt = '''
Tu es un assistant intelligent de gestion de tâches. Analyse le texte suivant pour extraire une tâche structurée.
Texte: "$text"

INFORMATIONS ACTUELLES :
- Date et jour actuels : $currentDateFormatted
- Date ISO actuelle (pour calculs) : $nowIso
- Jour de la semaine actuel : $currentDayName

Règles d'extraction :
1. "title": Le titre de la tâche. Utilise les mots exacts de l'utilisateur pour l'action principale. Ne reformule pas sauf si c'est incompréhensible.
2. "description": Les détails supplémentaires si présents.
3. "dueDate": La date d'échéance si mentionnée (format ISO 8601 YYYY-MM-DDTHH:MM:SS), sinon null.
4. "reminder": La date/heure de rappel si mentionnée (format ISO 8601 YYYY-MM-DDTHH:MM:SS), sinon null. 
   IMPORTANT pour les rappels :
   - Si l'utilisateur dit "rappel", "rappelle-moi", "alarme", "notifie-moi", "souviens-toi", etc., tu DOIS extraire le rappel
   - Si une heure est mentionnée (ex: "à 9h", "à 14h30", "à 8 heures du matin"), c'est un rappel
   - Si une date et heure sont mentionnées pour un rappel (ex: "rappel le 15 octobre à 9h"), calcule la date complète
   - Si seulement une heure est mentionnée sans date (ex: "rappel à 9h"), utilise la date d'aujourd'hui avec cette heure (sauf si l'heure est passée, alors utilise demain)
   - Si une date relative est mentionnée pour un rappel (ex: "rappel demain à 14h"), calcule la date absolue
   - Le format doit être ISO 8601 complet : YYYY-MM-DDTHH:MM:SS (ex: "2024-03-22T09:00:00")
5. "project": Le nom du projet UNIQUEMENT si explicitement mentionné par l'utilisateur (ex: "dans le projet Travail", "catégorie Maison"). Si aucun projet n'est mentionné, tu DOIS retourner null. Ne devine pas ou n'invente pas de projet.
6. Si une date est relative (ex: "demain", "lundi", "jeudi prochain", "dans 3 jours"), calcule la date absolue en te basant sur la date actuelle ($currentDateFormatted). 
   - "demain" = jour suivant
   - "après-demain" = dans 2 jours
   - "lundi", "mardi", etc. = prochain jour de la semaine mentionné (si c'est déjà passé cette semaine, prends celui de la semaine prochaine)
   - "lundi prochain" = lundi de la semaine prochaine
   - "dans X jours" = date actuelle + X jours

EXEMPLES de rappels :
- "rappel à 9h" → reminder: "2024-03-22T09:00:00" (aujourd'hui à 9h, ou demain si l'heure est passée)
- "rappel demain à 14h30" → reminder: "2024-03-23T14:30:00"
- "rappel le 15 octobre à 9h" → reminder: "2024-10-15T09:00:00"
- "rappel jeudi à 8h" → reminder: date du prochain jeudi à 8h

Réponds UNIQUEMENT avec un objet JSON valide respectant ce format :
{
  "title": "...",
  "description": "...",
  "dueDate": "..." or null,
  "reminder": "..." or null,
  "project": "..." or null
}
''';

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      return jsonDecode(content);
    }
    return null;
  }

  void _showVoiceProcessingOverlay(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.1), // Plus transparent
      builder: (context) => Builder(
        builder: (context) {
          final brightness = Theme.of(context).brightness;
          final surfaceColor = DSColor.getSurface(brightness).withOpacity(0.85); // Plus transparent
          final headingColor = DSColor.getHeading(brightness);
          final mutedColor = DSColor.getMuted(brightness);
          
          return PopScope(
            canPop: false,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: DSRadius.round,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          DSColor.primary.withOpacity(0.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: TextStyle(
                        color: headingColor.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        decoration: TextDecoration.none, // Enlever tout surlignement
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _updateVoiceProcessingOverlay(String message) {
    Navigator.of(context).pop(); // Fermer l'ancien overlay
    _showVoiceProcessingOverlay(message); // Afficher le nouveau
  }

  Future<void> _addTodoByVoice() async {
    if (_openAiApiKeys.trim().isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clé API manquante'),
          content: const Text('Veuillez renseigner votre clé API OpenAI dans les paramètres.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final path = await _recordAudio();
    if (path == null) return;

    final apiKey = _openAiApiKeys.split(',').first.trim();
    
    // Afficher le loader avec le premier message
    _showVoiceProcessingOverlay('Transcription de l\'audio...');
    
    String? transcription;
    try {
      transcription = await _transcribeAudio(path, apiKey);
      if (transcription == null) {
        if (mounted) {
          Navigator.of(context).pop(); // Fermer le loader
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur lors de la transcription'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Fermer le loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la transcription: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Vérifier si c'est une demande de liste de courses
    final isShoppingListRequest = PreferencesService().shoppingListEnabled && 
                                    _isShoppingListRequest(transcription);
    
    if (isShoppingListRequest) {
      // Mode liste de courses : décomposer en plusieurs tâches
      if (mounted) {
        _updateVoiceProcessingOverlay('Analyse de la liste de courses...');
      }

      List<Map<String, dynamic>> shoppingItems;
      try {
        shoppingItems = await _extractShoppingListItemsFromText(transcription, apiKey);
        if (shoppingItems.isEmpty) {
          if (mounted) {
            Navigator.of(context).pop(); // Fermer le loader
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Aucun élément de courses détecté'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Fermer le loader
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de l\'extraction des éléments: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Obtenir le projet "Courses"
      final shoppingListProject = ProjectService().getShoppingListProject();
      if (shoppingListProject == null) {
        // Créer le projet s'il n'existe pas
        await ProjectService().getOrCreateShoppingListProject();
      }
      final shoppingListProjectId = ProjectService.SHOPPING_LIST_PROJECT_ID;

      // Mettre à jour le message
      if (mounted) {
        _updateVoiceProcessingOverlay('Création de ${shoppingItems.length} élément${shoppingItems.length > 1 ? 's' : ''}...');
      }

      // Créer toutes les tâches
      final newTodos = <TodoItem>[];
      int baseId = DateTime.now().millisecondsSinceEpoch;
      
      for (int i = 0; i < shoppingItems.length; i++) {
        final item = shoppingItems[i];
        final newTodo = TodoItem(
          id: baseId + i, // IDs séquentiels pour éviter les collisions
          title: item['title']?.toString().trim() ?? 'Sans titre',
          description: item['description']?.toString().trim() ?? '',
          priority: Priority.medium,
          projectId: shoppingListProjectId, // Toujours le projet "Courses"
          isCompleted: false,
          dueDate: null, // Pas de date d'échéance pour les courses
          reminder: null, // Pas de rappel par défaut pour les courses
        );
        newTodos.add(newTodo);
      }

      setState(() {
        _todos.addAll(newTodos);
      });
      await _saveData();

      // Fermer le loader et afficher la confirmation
      if (mounted) {
        Navigator.of(context).pop(); // Fermer le loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${newTodos.length} élément${newTodos.length > 1 ? 's' : ''} ajouté${newTodos.length > 1 ? 's' : ''} à la liste de courses'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      return; // Sortir de la fonction après avoir traité la liste de courses
    }

    // Mode normal : traitement d'une seule tâche
    // Mettre à jour le message
    if (mounted) {
      _updateVoiceProcessingOverlay('Analyse de la tâche...');
    }

    Map<String, dynamic>? todoMap;
    try {
      todoMap = await _extractTodoFromText(transcription, apiKey);
      if (todoMap == null) {
        if (mounted) {
          Navigator.of(context).pop(); // Fermer le loader
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur lors de l\'extraction de la tâche'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Fermer le loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'extraction: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Mettre à jour le message
    if (mounted) {
      _updateVoiceProcessingOverlay('Création de la tâche...');
    }

    DateTime? dueDate;
    if (todoMap['dueDate'] != null) {
      try {
        dueDate = DateTime.parse(todoMap['dueDate']);
      } catch (e) {
        debugPrint('Erreur parsing dueDate: $e');
      }
    }

    DateTime? reminder;
    if (todoMap['reminder'] != null && todoMap['reminder'].toString().trim().isNotEmpty) {
      try {
        final reminderStr = todoMap['reminder'].toString().trim();
        debugPrint('🔔 [VOIX] Rappel extrait du modèle: "$reminderStr"');
        reminder = DateTime.parse(reminderStr);
        debugPrint('✅ [VOIX] Rappel parsé avec succès: ${reminder.toString()}');
        
        // Vérifier que le rappel est dans le futur
        if (reminder.isBefore(DateTime.now())) {
          debugPrint('⚠️ [VOIX] Rappel dans le passé, ajustement à demain à la même heure');
          reminder = DateTime(
            reminder.year,
            reminder.month,
            reminder.day + 1,
            reminder.hour,
            reminder.minute,
          );
        }
      } catch (e) {
        debugPrint('❌ [VOIX] Erreur parsing reminder: $e');
        debugPrint('❌ [VOIX] Valeur reçue: ${todoMap['reminder']}');
        reminder = null;
      }
    } else {
      debugPrint('ℹ️ [VOIX] Aucun rappel mentionné, reminder = null');
    }

    // Gestion du projet
    int? projectId;
    if (todoMap['project'] != null && todoMap['project'].toString().trim().isNotEmpty) {
      final projectName = todoMap['project'].toString().toLowerCase().trim();
      debugPrint('🔍 [VOIX] Projet mentionné: "$projectName"');
      try {
        // Recherche exacte d'abord, puis partielle
        final project = _projects.firstWhere(
          (p) => p.name.toLowerCase().trim() == projectName || 
                 (projectName.length > 2 && p.name.toLowerCase().trim().contains(projectName)),
        );
        projectId = project.id;
        debugPrint('✅ [VOIX] Projet trouvé: "${project.name}" (ID: ${project.id})');
      } catch (e) {
        debugPrint('❌ [VOIX] Projet vocal non trouvé: "$projectName"');
        projectId = null; // Aucun projet par défaut si non trouvé
      }
    } else {
      debugPrint('ℹ️ [VOIX] Aucun projet mentionné, projectId = null');
      projectId = null; // Aucun projet par défaut si non précisé
    }

    final newTodo = TodoItem(
      id: DateTime.now().millisecondsSinceEpoch,
      title: todoMap['title'] ?? 'Sans titre',
      description: todoMap['description'] ?? '',
      priority: Priority.medium,
      projectId: projectId,
      isCompleted: false,
      dueDate: dueDate,
      reminder: reminder,
    );

    setState(() {
      _todos.add(newTodo);
    });
    await _saveData();
    
    // Planifier la notification si un rappel est défini
    if (newTodo.reminder != null) {
      debugPrint('🔔 [VOIX] Programmation de la notification pour le rappel: ${newTodo.reminder}');
      try {
        await NotificationService.scheduleNotification(newTodo);
        debugPrint('✅ [VOIX] Notification programmée avec succès');
      } catch (e) {
        debugPrint('❌ [VOIX] Erreur lors de la programmation de la notification: $e');
      }
    } else {
      debugPrint('ℹ️ [VOIX] Aucune notification à programmer (pas de rappel)');
    }

    // Fermer le loader et afficher la confirmation
    if (mounted) {
      Navigator.of(context).pop(); // Fermer le loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Tâche "${newTodo.title}" ajoutée avec succès'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _openEditModal(TodoItem todo) {
    debugPrint('🟢 [_openEditModal] Ouverture du modal pour: ${todo.title} (niveau ${todo.level})');
    final subTasks = _getVisibleSubTasks(todo.id);
    debugPrint('🟢 [_openEditModal] Sous-tâches trouvées: ${subTasks.length}');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Transparent pour laisser le fond blanc du container
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white, // Force white fill color
          ),
        ),
        child: EditTodoModal(
        todo: todo,
        projects: _projects,
        subTasks: subTasks,
        onAddSubTask: (subTask) {
          debugPrint('🟢 [_openEditModal] onAddSubTask appelé pour: ${subTask.title}');
          setState(() {
            _todos.add(subTask);
          });
          debugPrint('🟢 [_openEditModal] Sous-tâche ajoutée à la liste principale');
        },
        onToggleSubTask: (id) {
          debugPrint('🟢 [_openEditModal] onToggleSubTask appelé pour ID: $id');
          setState(() {
            final index = _todos.indexWhere((t) => t.id == id);
            if (index != -1) {
              _todos[index].isCompleted = !_todos[index].isCompleted;
              debugPrint('🟢 [_openEditModal] État de la tâche $id changé: ${_todos[index].isCompleted}');
            }
          });
        },
        onDeleteTodo: (id) {
          debugPrint('🟢 [_openEditModal] onDeleteTodo appelé pour ID: $id');
          _deleteTodo(id);
        },
        onEditSubTask: (subTask) {
          debugPrint('🟢 [_openEditModal] onEditSubTask appelé pour: ${subTask.title}');
          // Fonction récursive pour ouvrir le modal d'édition de n'importe quelle tâche
          _openEditModal(subTask);
        },
        homeState: this,
        ),
      ),
    ).then((result) async {
      debugPrint('🟢 [_openEditModal] Modal fermé, résultat: ${result != null ? 'avec données' : 'sans données'}');
      
      if (result != null && result['todo'] != null) {
        debugPrint('🟢 [_openEditModal] Mise à jour de la tâche principale...');
        setState(() {
          final index = _todos.indexWhere((t) => t.id == todo.id);
          if (index != -1) {
            _todos[index] = result['todo'] as TodoItem;
            debugPrint('🟢 [_openEditModal] Tâche principale mise à jour');
          }
        });
        
        // Sauvegarder les données
        await _saveData();
        final updatedTodo = result['todo'] as TodoItem;
        
        // Annuler l'ancienne notification avant d'en programmer une nouvelle
        await NotificationService.cancelTaskNotification(updatedTodo.id);
        
        // Planifier la nouvelle notification si besoin
        if (updatedTodo.reminder != null && updatedTodo.reminder!.isAfter(DateTime.now())) {
          await NotificationService.scheduleTaskReminder(
            taskId: updatedTodo.id,
            title: updatedTodo.title,
            body: updatedTodo.description.isNotEmpty ? updatedTodo.description : 'Rappel de tâche',
            scheduledDate: updatedTodo.reminder!,
          );
        }
      }
      
      debugPrint('🟢 [_openEditModal] Traitement terminé');
    });
  }

  void _editTodo(TodoItem todo) {
    _openEditModal(todo);
  }

  /// Navigue vers une tâche spécifique depuis une notification
  void _navigateToTask(int taskId) {
    debugPrint('🔔 Navigation vers la tâche ID: $taskId');
    
    // Trouver la tâche par son ID
    final task = _todos.firstWhere(
      (todo) => todo.id == taskId,
      orElse: () => throw Exception('Tâche non trouvée: $taskId'),
    );
    
    // Ouvrir le modal d'édition de la tâche
    _openEditModal(task);
    
    // Optionnel: Afficher un message de confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ouverture de la tâche: ${task.title}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addProject() {
    showDialog(
      context: context,
      builder: (context) => AddProjectDialog(),
    ).then((newProject) async {
      if (newProject != null) {
        setState(() {
          _projects.add(newProject);
        });
        
        // Sauvegarder les données
        await _saveData();
      }
    });
  }

  void _deleteProject(Project project) async {
    debugPrint('🔄 _deleteProject(): Début de la suppression du projet: ${project.name} (ID: ${project.id})');

    // Compter les tâches dans ce projet
    final projectTodos = _todos.where((todo) => todo.projectId == project.id).length;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le projet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Êtes-vous sûr de vouloir supprimer le projet "${project.name}" ?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (projectTodos > 0) ...[
              Text(
                'Ce projet contient $projectTodos tâche${projectTodos > 1 ? 's' : ''}.',
                style: const TextStyle(color: Colors.orange),
              ),
              const SizedBox(height: 4),
              const Text(
                'Toutes les tâches seront supprimées définitivement.',
                style: TextStyle(color: Colors.red),
              ),
            ] else ...[
              const Text(
                'Ce projet ne contient aucune tâche.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              debugPrint('🔄 _deleteProject(): Bouton de suppression cliqué');
              try {
                // Utiliser le service pour supprimer le projet
                debugPrint('🔄 _deleteProject(): Appel du service de suppression...');
                final localStorageService = LocalStorageService();
                final success = await localStorageService.deleteProject(project.id);
                debugPrint('🔄 _deleteProject(): Résultat de la suppression: $success');
                
                if (success) {
                  debugPrint('✅ _deleteProject(): Suppression réussie, rechargement des données...');
                  // Recharger les données depuis le service
                  setState(() {
                    _projects = List<Project>.from(localStorageService.projects);
                    _todos = List<TodoItem>.from(localStorageService.todos);
                    debugPrint('🔄 _deleteProject(): ${_projects.length} projets rechargés');
                    debugPrint('🔄 _deleteProject(): ${_todos.length} tâches rechargées');
                    
                    // Si le projet supprimé était sélectionné, sélectionner le projet par défaut
                    if (_selectedProject?.id == project.id) {
                      debugPrint('🔄 _deleteProject(): Projet supprimé était sélectionné, changement de sélection...');
                      _selectedProject = _projects.isNotEmpty ? _projects.first : null;
                      debugPrint('🔄 _deleteProject(): Nouveau projet sélectionné: ${_selectedProject?.name ?? 'Aucun'}');
                    }
                  });
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Projet "${project.name}" supprimé avec succès'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  debugPrint('✅ _deleteProject(): Suppression terminée avec succès');
                } else {
                  debugPrint('❌ _deleteProject(): Échec de la suppression');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Erreur lors de la suppression du projet'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                debugPrint('❌ _deleteProject(): Exception lors de la suppression: $e');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur lors de la suppression: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _editProject(Project project) {
    debugPrint('✏️ _editProject(): Modification du projet: ${project.name} (ID: ${project.id})');
    
    showDialog(
      context: context,
      builder: (context) => EditProjectDialog(
        project: project,
        onProjectUpdated: (updatedProject) async {
          debugPrint('🔄 _editProject(): Projet mis à jour, rechargement des données...');
          final localStorageService = LocalStorageService();
          
          // Recharger les données depuis le service
          setState(() {
            _projects = List<Project>.from(localStorageService.projects);
            debugPrint('🔄 _editProject(): ${_projects.length} projets rechargés');
            
            // Mettre à jour le projet sélectionné si c'était celui-ci
            if (_selectedProject?.id == project.id) {
              _selectedProject = _projects.firstWhere((p) => p.id == project.id);
              debugPrint('🔄 _editProject(): Projet sélectionné mis à jour: ${_selectedProject?.name}');
            }
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Projet "${updatedProject.name}" modifié avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          debugPrint('✅ _editProject(): Modification terminée avec succès');
        },
      ),
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Builder(
        builder: (context) {
          final brightness = Theme.of(context).brightness;
          final surfaceColor = DSColor.getSurface(brightness);
          final headingColor = DSColor.getHeading(brightness);
          final bodyColor = DSColor.getBody(brightness);
          
          return AlertDialog(
            backgroundColor: surfaceColor,
            title: Text(
              'Trier les tâches',
              style: DSTypo.h2.copyWith(color: headingColor),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSortOption(ctx, SortType.dueDate, 'Date d\'échéance', Icons.schedule),
                _buildSortOption(ctx, SortType.name, 'Nom', Icons.sort_by_alpha),
                _buildSortOption(ctx, SortType.dateAdded, 'Date d\'ajout', Icons.add_circle),
                _buildSortOption(ctx, SortType.priority, 'Priorité', Icons.priority_high),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortOption(BuildContext context, SortType sortType, String title, IconData icon) {
    final isSelected = _currentSort == sortType;
    final brightness = Theme.of(context).brightness;
    final headingColor = DSColor.getHeading(brightness);
    final bodyColor = DSColor.getBody(brightness);
    final primaryColor = DSColor.primary;
    
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? primaryColor : DSColor.getMuted(brightness),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? primaryColor : bodyColor, // Couleur adaptative au thème
        ),
      ),
      trailing: isSelected ? Icon(Icons.check, color: Colors.green) : null,
      onTap: () {
        setState(() {
          _currentSort = sortType;
        });
        Navigator.pop(context);
      },
    );
  }

  void _toggleTodo(int id) async {
    final todo = _todos.firstWhere((todo) => todo.id == id);
    final wasCompleted = todo.isCompleted;
    final isNowCompleted = !wasCompleted;
    
    // Pour l'undo
    TodoItem? previousState;
    if (!wasCompleted) {
      previousState = todo.copyWith(isCompleted: wasCompleted);
    }

    // Mettre à jour l'état immédiatement pour déclencher l'animation
    setState(() {
      try {
        todo.isCompleted = isNowCompleted;
        
        // Si la tâche est marquée comme terminée et qu'elle est récurrente, créer une nouvelle occurrence
        if (todo.isCompleted && todo.isRecurring && todo.recurrenceTime != null) {
          final nextOccurrence = todo.getNextOccurrence();
          if (nextOccurrence != null) {
            final newTodo = TodoItem(
              id: DateTime.now().millisecondsSinceEpoch,
              title: todo.title,
              description: todo.description,
              dueDate: nextOccurrence,
              priority: todo.priority,
              projectId: todo.projectId,
              isCompleted: false,
              parentId: todo.parentId,
              level: todo.level,
              reminder: nextOccurrence,
              estimatedMinutes: todo.estimatedMinutes,
              elapsedMinutes: 0,
              elapsedSeconds: 0,
              recurrenceType: todo.recurrenceType,
              recurrenceDayOfWeek: todo.recurrenceDayOfWeek,
              recurrenceDayOfMonth: todo.recurrenceDayOfMonth,
              recurrenceTime: todo.recurrenceTime,
            );
            
            _todos.add(newTodo);
            debugPrint('✅ Nouvelle occurrence créée pour la tâche récurrente "${todo.title}" à ${nextOccurrence}');
            
            // Programmer la notification pour la nouvelle occurrence
            NotificationService.scheduleTaskReminder(
              taskId: newTodo.id,
              title: newTodo.title,
              body: 'Tâche récurrente: ${newTodo.recurrenceText}',
              scheduledDate: nextOccurrence,
            ).then((_) {
              debugPrint('✅ Notification programmée pour la nouvelle occurrence');
            }).catchError((e) {
              debugPrint('❌ Erreur programmation notification nouvelle occurrence: $e');
            });
          }
        }
      } catch (e) {
        debugPrint('❌ Tâche non trouvée pour toggle: $id');
        return;
      }
    });
    
    // Sauvegarder les données
    await _saveData();

    // SnackBar avec action d'annulation uniquement quand on marque comme terminé
    if (isNowCompleted && previousState != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tâche "${todo.title}" marquée comme terminée'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Annuler',
            onPressed: () async {
              final index = _todos.indexWhere((t) => t.id == todo.id);
              if (index != -1) {
                setState(() {
                  _todos[index] = previousState!;
                });
                await _saveData();
              }
            },
          ),
        ),
      );
    }
  }

  void _deleteTodo(int id) async {
    debugPrint('🗑️ Suppression de la tâche $id');
    
    // Annuler les notifications de la tâche et de ses sous-tâches
    await NotificationService.cancelTaskNotification(id);
    
    // Récupérer toutes les sous-tâches pour annuler leurs notifications
    final subTasks = _getAllSubTasks(id);
    for (final subTask in subTasks) {
      await NotificationService.cancelTaskNotification(subTask.id);
    }
    
    setState(() {
      // Supprimer la tâche et toutes ses sous-tâches
      final beforeCount = _todos.length;
      _todos.removeWhere((todo) => todo.id == id || todo.parentId == id);
      final afterCount = _todos.length;
      debugPrint('🗑️ Tâches supprimées: $beforeCount -> $afterCount (${beforeCount - afterCount} supprimées)');
    });
    
    // Sauvegarder les données
    await _saveData();
    debugPrint('🗑️ Suppression terminée pour la tâche $id');
  }

  // Méthodes utilitaires pour les sous-tâches
  List<TodoItem> _getSubTasks(int parentId) {
    return _todos.where((todo) => todo.parentId == parentId).toList();
  }

  // Sous-tâches à afficher selon les préférences
  List<TodoItem> _getVisibleSubTasks(int parentId) {
    final subTasks = _getSubTasks(parentId);
    List<TodoItem> result;

    if (_showCompletedTasks) {
      // En mode "Tâches achevées", n'afficher que les sous-tâches terminées
      result = subTasks.where((t) => t.isCompleted).toList();
    } else if (_showCompletedTasksInProjects) {
      // Option activée : afficher toutes les sous-tâches
      result = subTasks;
    } else {
      // Option désactivée : masquer les sous-tâches terminées
      result = subTasks.where((t) => !t.isCompleted).toList();
    }

    // Toujours placer les sous-tâches terminées en bas
    result.sort((a, b) {
      if (a.isCompleted == b.isCompleted) return 0;
      return a.isCompleted ? 1 : -1; // Terminées en bas
    });

    return result;
  }

  List<TodoItem> _getAllSubTasks(int parentId) {
    List<TodoItem> allSubTasks = [];
    List<int> toProcess = [parentId];
    
    while (toProcess.isNotEmpty) {
      int currentId = toProcess.removeAt(0);
      List<TodoItem> directSubTasks = _todos.where((todo) => todo.parentId == currentId).toList();
      allSubTasks.addAll(directSubTasks);
      toProcess.addAll(directSubTasks.map((todo) => todo.id));
    }
    
    return allSubTasks;
  }

  bool _hasSubTasks(int parentId) {
    return _todos.any((todo) => todo.parentId == parentId);
  }

  void _addSubTask(TodoItem parentTask, TodoItem subTask) {
    if (!parentTask.canHaveSubTasks) {
      throw Exception('Impossible d\'ajouter une sous-tâche au-delà du niveau 3');
    }

    setState(() {
      _todos.add(subTask);
    });
  }

  // Vérifie si taskId est un descendant de potentialAncestorId
  bool _isDescendant(int potentialAncestorId, int taskId) {
    TodoItem? current;
    try {
      current = _todos.firstWhere((t) => t.id == taskId);
    } catch (_) {
      return false;
    }
    while (current?.parentId != null) {
      if (current!.parentId == potentialAncestorId) return true;
      try {
        current = _todos.firstWhere((t) => t.id == current!.parentId);
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  // Récupère le niveau le plus profond d'une tâche et de ses descendants
  int _getDeepestLevel(int taskId) {
    int deepest = _todos.firstWhere((t) => t.id == taskId).level;
    for (final sub in _getAllSubTasks(taskId)) {
      if (sub.level > deepest) deepest = sub.level;
    }
    return deepest;
  }

  // Déplace une tâche sous une autre en mettant à jour le niveau de toutes les sous-tâches
  void _moveTaskToParent(int taskId, int newParentId) {
    final taskIndex = _todos.indexWhere((t) => t.id == taskId);
    final parentIndex = _todos.indexWhere((t) => t.id == newParentId);
    if (taskIndex == -1 || parentIndex == -1) return;

    final task = _todos[taskIndex];
    final newParent = _todos[parentIndex];

    final deepestLevel = _getDeepestLevel(taskId);
    final relativeDepth = deepestLevel - task.level;
    final newLevel = newParent.level + 1;

    if (newLevel + relativeDepth > 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Niveau maximum de sous-tâches atteint')),
      );
      return;
    }

    final levelDiff = newLevel - task.level;

    setState(() {
      _todos[taskIndex] = task.copyWith(parentId: newParent.id, level: newLevel);

      for (final sub in _getAllSubTasks(taskId)) {
        final idx = _todos.indexWhere((t) => t.id == sub.id);
        if (idx != -1) {
          _todos[idx] = sub.copyWith(level: sub.level + levelDiff);
        }
      }
    });

    _saveData();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tâche déplacée comme sous-tâche'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Remonte une tâche au niveau supérieur (supprime le parent)
  void _moveTaskToRoot(int taskId) {
    final taskIndex = _todos.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;

    final task = _todos[taskIndex];
    if (task.parentId == null) return; // Déjà au niveau racine

    debugPrint('🔍 === REMONTÉE TÂCHE AU RACINE ===');
    debugPrint('🔍 Tâche à remonter: ${task.title} (ID: $taskId)');
    debugPrint('🔍 Ancien parentId: ${task.parentId}');
    debugPrint('🔍 Ancien niveau: ${task.level}');
  
    final currentLevel = task.level;
    final levelDiff = currentLevel - 0; // Remonter au niveau 0
  
    setState(() {
      _todos[taskIndex] = task.copyWith(parentId: null, level: 0);
      debugPrint('✅ Tâche remontée: parentId = null, level = 0');
  
      // Remonter toutes les sous-tâches et ajuster leur niveau (on conserve la hiérarchie)
      for (final sub in _getAllSubTasks(taskId)) {
        final idx = _todos.indexWhere((t) => t.id == sub.id);
        if (idx != -1) {
          _todos[idx] = sub.copyWith(level: sub.level - levelDiff);
          debugPrint('✅ Sous-tâche ${sub.title} niveau ajusté: ${sub.level} -> ${sub.level - levelDiff}');
        }
      }
    });

    debugPrint('🔍 === FIN REMONTÉE ===');
    _saveData();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tâche remontée au niveau principal'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Widget utilisé comme aperçu lors du déplacement d'une tâche
  Widget _buildDragFeedback(TodoItem todo) {
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 250),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              todo.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
  
  // Méthode pour construire un élément de sous-tâche indenté
  Widget _buildSubTaskItem(TodoItem subTask, int parentId) {
    final hasNestedSubTasks = _getVisibleSubTasks(subTask.id).isNotEmpty;
    final isExpanded = _expandedTasks.contains(subTask.id);
    final nestedSubTasks = isExpanded ? _getVisibleSubTasks(subTask.id) : [];
    
    Widget itemContent = Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: EdgeInsets.only(
            left: 32.0 * subTask.level, // Indentation basée sur le niveau
            right: 16.0,
            top: 2.0,
            bottom: 2.0,
          ),
          child: AnimatedOpacity(
            opacity: subTask.isCompleted ? 0.6 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: Card(
              elevation: subTask.isCompleted ? 1 : 2,
          child: InkWell(
            onTap: () => _editTodo(subTask),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                            leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: subTask.isCompleted,
                                    onChanged: (_) => _toggleTodo(subTask.id),
                                  ),
                                  if (subTask.isRecurring)
                                    Icon(
                                      Icons.repeat,
                                      size: 16,
                                      color: Colors.purple,
                                    ),
                                ],
                              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre sur la première ligne avec icône de description
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          subTask.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            decoration: subTask.isCompleted ? TextDecoration.lineThrough : null,
                            color: subTask.isCompleted ? Colors.grey : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                          maxLines: 3, // Permettre jusqu'à 3 lignes
                          overflow: TextOverflow.visible, // Ne pas tronquer
                        ),
                      ),
                      if (subTask.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 2),
                          child: Icon(
                            Icons.description,
                            size: 16,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                    ],
                  ),
                  // Dates et récurrence sur la deuxième ligne
                  if (subTask.dueDate != null || subTask.reminder != null || subTask.isRecurring)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          if (subTask.dueDate != null) ...[
                            Icon(Icons.calendar_today, size: 14),
                            const SizedBox(width: 2),
                            Text(
                              '${subTask.dueDate!.day}/${subTask.dueDate!.month}/${subTask.dueDate!.year}',
                              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                            ),
                          ],
                          if (subTask.dueDate != null && (subTask.reminder != null || subTask.isRecurring))
                            const SizedBox(width: 12),
                          if (subTask.reminder != null) ...[
                            Icon(Icons.alarm, size: 14),
                            const SizedBox(width: 2),
                            Text(
                              '${subTask.reminder!.day}/${subTask.reminder!.month}/${subTask.reminder!.year} à ${subTask.reminder!.hour.toString().padLeft(2, '0')}:${subTask.reminder!.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                            ),
                          ],
                          if (subTask.reminder != null && subTask.isRecurring)
                            const SizedBox(width: 12),
                          if (subTask.isRecurring) ...[
                            Icon(Icons.repeat, size: 14, color: Colors.purple),
                            const SizedBox(width: 2),
                            Text(
                              '${subTask.recurrenceText}${subTask.recurrenceTimeText.isNotEmpty ? ' à ${subTask.recurrenceTimeText}' : ''}',
                              style: TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description (si activée dans les paramètres)
                    if (_showDescriptions && subTask.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          subTask.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: subTask.isCompleted ? Colors.grey : Theme.of(context).hintColor,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    // Informations de temps et sous-tâches
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 2,
                      children: [
                        if (subTask.estimatedMinutes != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer, size: 15),
                              const SizedBox(width: 2),
                              Text('Estimé : ${subTask.estimatedTimeText}', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ...(TimerService().isTaskRunning(subTask.id)
                          ? [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.play_circle, size: 15, color: Colors.green),
                                  const SizedBox(width: 2),
                                  Text(
                                    _formatElapsedTime(subTask.elapsedSeconds + TimerService().elapsedSeconds),
                                    style: const TextStyle(fontSize: 13, color: Colors.green),
                                  ),
                                ],
                              )
                            ]
                          : subTask.elapsedSeconds > 0
                            ? [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.timelapse, size: 15),
                                    const SizedBox(width: 2),
                                    Text('Passé : ${_formatElapsedTime(subTask.elapsedSeconds)}', style: const TextStyle(fontSize: 12)),
                                  ],
                                )
                              ]
                            : []),
                        if (hasNestedSubTasks)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_getVisibleSubTasks(subTask.id).length} sous-tâches',
                              style: TextStyle(fontSize: 12, color: Colors.purple),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(TimerService().isTaskRunning(subTask.id) ? Icons.pause : Icons.play_arrow),
                    tooltip: TimerService().isTaskRunning(subTask.id)
                        ? 'Mettre en pause le suivi du temps'
                        : 'Démarrer le suivi du temps',
                    onPressed: () => _handlePlayPause(subTask),
                  ),
                  if (hasNestedSubTasks)
                    IconButton(
                      iconSize: 24,
                      icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.purple),
                      onPressed: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedTasks.remove(subTask.id);
                          } else {
                            _expandedTasks.add(subTask.id);
                          }
                        });
                      },
                      tooltip: isExpanded ? 'Masquer les sous-tâches' : 'Afficher les sous-tâches',
                    ),
                ],
              ),
            ),
          ),
        ),
        ),
        ),
        // Afficher les sous-tâches imbriquées si la tâche est dépliée
        if (isExpanded && nestedSubTasks.isNotEmpty)
          ...nestedSubTasks.map((nestedSubTask) => _buildSubTaskItem(nestedSubTask, subTask.id)),
      ],
    );

    return Column(
      children: [
        // Zone de drop pour remonter une tâche au niveau supérieur
        if (subTask.parentId != null)
          DragTarget<TodoItem>(
            onWillAccept: (dragged) {
              if (dragged == null) return false;
              return dragged.id != subTask.id && !_isDescendant(dragged.id, subTask.id);
            },
            onAccept: (dragged) => _moveTaskToRoot(dragged.id),
            builder: (context, candidate, rejected) {
              return Container(
                height: 16,
                margin: EdgeInsets.only(
                  left: 32.0 * subTask.level + 16,
                  right: 16,
                ),
                decoration: BoxDecoration(
                  color: candidate.isNotEmpty 
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                    : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: candidate.isNotEmpty
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      )
                    : null,
                ),
                child: candidate.isNotEmpty
                  ? Center(
                      child: Text(
                        'Remonter au niveau supérieur',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
              );
            },
          ),
        // Zone de drop pour déplacer une tâche sous cette sous-tâche
        DragTarget<TodoItem>(
          onWillAccept: (dragged) {
            if (dragged == null) return false;
            return dragged.id != subTask.id && !_isDescendant(dragged.id, subTask.id) && subTask.canHaveSubTasks && (subTask.level + 1 + (_getDeepestLevel(dragged.id) - dragged.level) <= 3);
          },
          onAccept: (dragged) => _moveTaskToParent(dragged.id, subTask.id),
          builder: (context, candidate, rejected) {
            return LongPressDraggable<TodoItem>(
              data: subTask,
              feedback: _buildDragFeedback(subTask),
              childWhenDragging: Opacity(opacity: 0.5, child: itemContent),
              child: Container(
                decoration: BoxDecoration(
                  border: candidate.isNotEmpty
                    ? Border.all(
                        color: Theme.of(context).colorScheme.secondary,
                        width: 2,
                      )
                    : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: itemContent,
              ),
            );
          },
        ),
      ],
    );
  }

  void _showThemeSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Personnaliser le thème',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            // Section Couleurs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Couleur des éléments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildColorOption('Bleu', 'blue', const Color(0xFF2563EB)),
                      _buildColorOption('Vert', 'green', const Color(0xFF059669)),
                      _buildColorOption('Violet', 'purple', const Color(0xFF7C3AED)),
                      _buildColorOption('Orange', 'orange', const Color(0xFFEA580C)),
                      _buildColorOption('Rose', 'pink', const Color(0xFFEC4899)),
                      _buildColorOption('Teal', 'teal', const Color(0xFF0D9488)),
                      _buildColorOption('Indigo', 'indigo', const Color(0xFF4F46E5)),
                      _buildColorOption('Rouge', 'red', const Color(0xFFDC2626)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Section Mode
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mode d\'affichage',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildModeOption('Clair', false, Icons.wb_sunny),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildModeOption('Sombre', true, Icons.nightlight_round),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        child: SettingsScreen(
          onThemeChanged: widget.onThemeChanged,
          onThemeChangedLegacy: widget.onThemeChangedLegacy,
          onSettingsChanged: () {
            _loadSettings();
            _loadData();
          },
          onDataReload: _loadData,
          autoThemeMode: widget.autoThemeMode,
          onAutoThemeModeChanged: widget.onAutoThemeModeChanged,
        ),
      ),
    );
  }

  Widget _buildColorOption(String name, String colorName, Color color) {
    final isSelected = _selectedColor == colorName;
    
    return InkWell(
      onTap: () {
        widget.onThemeChanged(colorName, _isDarkMode);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.2),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ).animate().scale(
        duration: 150.ms,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Widget _buildModeOption(String name, bool isDark, IconData icon) {
    final isSelected = _isDarkMode == isDark;
    
    return InkWell(
      onTap: () {
        widget.onThemeChanged(_selectedColor, isDark);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              isSelected 
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
              isSelected 
                ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
                : Colors.grey.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2.5 : 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected 
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: TextStyle(
                color: isSelected 
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ).animate().scale(
        duration: 150.ms,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Widget _buildModernThemeOption(String name, ThemeData theme, Color color) {
    return InkWell(
      onTap: () {
        widget.onThemeChangedLegacy(theme);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          name,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.3,
          ),
        ),
      ).animate().scale(
        duration: 150.ms,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.low:
        return Colors.green;
      case Priority.medium:
        return Colors.orange;
      case Priority.high:
        return Colors.red;
    }
  }

  String _getPriorityText(Priority priority) {
    switch (priority) {
      case Priority.low:
        return 'Basse';
      case Priority.medium:
        return 'Moyenne';
      case Priority.high:
        return 'Haute';
    }
  }

  int _getPriorityValue(Priority priority) {
    switch (priority) {
      case Priority.low:
        return 1;
      case Priority.medium:
        return 2;
      case Priority.high:
        return 3;
    }
  }

  /// Compte uniquement les tâches actives (non terminées) selon le contexte actuel
  int _getActiveTasksCount() {
    if (_showCompletedTasks) {
      // Mode "Tâches achevées" - retourner 0 car on ne compte que les actives
      return 0;
    } else if (_showNoProjectTasks) {
      // Vue "Tâches sans projet" - compter uniquement les tâches actives sans projet
      return _todos.where((todo) => !todo.isCompleted && todo.projectId == null && todo.isRootTask).length;
    } else if (_selectedProject == null) {
      // Vue "Toutes les tâches" - compter uniquement les tâches actives (non terminées)
      return _todos.where((todo) => !todo.isCompleted && todo.isRootTask).length;
    } else {
      // Vue projet spécifique - compter uniquement les tâches actives du projet
      return _todos.where((todo) => !todo.isCompleted && todo.projectId == _selectedProject!.id && todo.isRootTask).length;
    }
  }

  List<TodoItem> get _filteredTodos {
    List<TodoItem> filtered;
    if (_showShoppingList) {
      // Mode "Courses" - afficher uniquement les tâches du projet "courses"
      final shoppingListProjectId = ProjectService.SHOPPING_LIST_PROJECT_ID;
      filtered = _todos.where((todo) => todo.projectId == shoppingListProjectId && (_showCompletedTasksInProjects || !todo.isCompleted) && todo.isRootTask).toList();
    } else if (_showCompletedTasks) {
      // Mode "Tâches achevées" - afficher seulement les tâches terminées
      filtered = _todos.where((todo) => todo.isCompleted && todo.isRootTask).toList();
    } else if (_showNoProjectTasks) {
      // Vue "Tâches sans projet" - afficher les tâches sans projet (non terminées ou toutes si l'option est activée)
      filtered = _todos.where((todo) => todo.projectId == null && (_showCompletedTasksInProjects || !todo.isCompleted) && todo.isRootTask).toList();
    } else if (_selectedProject == null) {
      // Vue "Toutes les tâches" - afficher les tâches non terminées (ou toutes si l'option est activée)
      // Exclure les tâches du projet "courses" de la vue principale
      final shoppingListProjectId = ProjectService.SHOPPING_LIST_PROJECT_ID;
      filtered = _todos.where((todo) => todo.projectId != shoppingListProjectId && (_showCompletedTasksInProjects || !todo.isCompleted) && todo.isRootTask).toList();
    } else {
      // Vue projet spécifique - afficher les tâches du projet (non terminées ou toutes si l'option est activée)
      filtered = _todos.where((todo) => todo.projectId == _selectedProject!.id && (_showCompletedTasksInProjects || !todo.isCompleted) && todo.isRootTask).toList();
    }
    
    // Séparer les tâches terminées et non terminées AVANT le tri
    final completedTasks = filtered.where((t) => t.isCompleted).toList();
    final activeTasks = filtered.where((t) => !t.isCompleted).toList();
    
    // Appliquer le tri uniquement sur les tâches actives
    switch (_currentSort) {
      case SortType.dueDate:
        activeTasks.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
        break;
      case SortType.name:
        activeTasks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortType.dateAdded:
        activeTasks.sort((a, b) {
          // Pour chaque tâche, trouver la date la plus récente (tâche elle-même ou ses sous-tâches)
          int getMostRecentId(TodoItem task) {
            final subTasks = _getAllSubTasks(task.id);
            if (subTasks.isEmpty) {
              return task.id;
            }
            // Trouver l'ID le plus récent parmi la tâche et ses sous-tâches
            int maxId = task.id;
            for (final subTask in subTasks) {
              if (subTask.id > maxId) {
                maxId = subTask.id;
              }
            }
            return maxId;
          }
          
          final aMostRecent = getMostRecentId(a);
          final bMostRecent = getMostRecentId(b);
          return bMostRecent.compareTo(aMostRecent); // Plus récent en premier
        });
        break;
      case SortType.priority:
        activeTasks.sort((a, b) => _getPriorityValue(b.priority).compareTo(_getPriorityValue(a.priority)));
        break;
    }
    
    // Trier aussi les tâches terminées par date d'ajout (plus récentes en premier)
    completedTasks.sort((a, b) => b.id.compareTo(a.id));
    
    // Recombiner : tâches actives d'abord, puis tâches terminées
    filtered = [...activeTasks, ...completedTasks];
    
    // Appliquer le filtre de recherche si un terme de recherche est saisi
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        filtered = filtered.where((todo) {
          final titleMatch = todo.title.toLowerCase().contains(query);
          final descriptionMatch = todo.description?.toLowerCase().contains(query) ?? false;
          return titleMatch || descriptionMatch;
        }).toList();
      }
    
    return filtered;
  }

  String _getSortDisplayName() {
    switch (_currentSort) {
      case SortType.dueDate:
        return 'Échéance';
      case SortType.name:
        return 'Nom';
      case SortType.dateAdded:
        return 'Ajout';
      case SortType.priority:
        return 'Priorité';
    }
  }

  String _getAppBarTitle() {
    if (_showCompletedTasks) {
      return 'Tâches achevées';
    } else if (_showNoProjectTasks) {
      return 'Tâches sans projet';
    } else if (_selectedProject == null) {
      return 'Toutes les tâches';
    } else {
      return _selectedProject!.name;
    }
  }

  // Helper pour construire les items du drawer avec Design System
  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
    Color? iconColor,
    int? count,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return Builder(
      builder: (context) {
        final brightness = Theme.of(context).brightness;
        final mutedColor = DSColor.getMuted(brightness);
        final bodyColor = DSColor.getBody(brightness);
        final surfaceTintColor = DSColor.getSurfaceTint(brightness);
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected ? DSColor.primary.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: Icon(
              icon,
              color: iconColor ?? (isSelected ? DSColor.primary : mutedColor),
              size: 22,
            ),
            title: Text(
              label,
              style: isSelected
                  ? DSTypo.body.copyWith(color: DSColor.primary, fontWeight: FontWeight.w700)
                  : DSTypo.body.copyWith(color: bodyColor),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (count != null && count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? DSColor.primary : surfaceTintColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : DSColor.primary,
                      ),
                    ),
                  ),
                if (onEdit != null || onDelete != null)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 18, color: mutedColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (value) {
                      if (value == 'edit' && onEdit != null) onEdit();
                      if (value == 'delete' && onDelete != null) onDelete();
                    },
                    itemBuilder: (context) => [
                      if (onEdit != null)
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit, size: 18, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text('Modifier', style: DSTypo.bodyOf(context)),
                            ],
                          ),
                        ),
                      if (onDelete != null)
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete, size: 18, color: Colors.red),
                              const SizedBox(width: 8),
                              Text('Supprimer', style: DSTypo.bodyOf(context)),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            onTap: onTap,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: Builder(
        builder: (context) {
          final brightness = Theme.of(context).brightness;
          final surfaceColor = DSColor.getSurface(brightness);
          
          return Drawer(
            backgroundColor: surfaceColor,
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header avec dégradé harmonisé avec le fond principal
            Builder(
              builder: (context) {
                final brightness = Theme.of(context).brightness;
                final gradient = DSColor.getBackdropGradient(brightness);
                final surfaceColor = DSColor.getSurface(brightness);
                final headingColor = DSColor.getHeading(brightness);
                final bodyColor = DSColor.getBody(brightness);
                
                return Container(
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: surfaceColor.withOpacity(0.6),
                          shape: BoxShape.circle,
                          boxShadow: brightness == Brightness.dark
                              ? []
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Icon(Icons.person, size: 32, color: headingColor),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Mes Tâches',
                        style: TextStyle(
                          color: headingColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_todos.where((t) => !t.isCompleted).length} tâches en cours',
                        style: TextStyle(
                          color: bodyColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            
            // Liste des options
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _buildDrawerItem(
                    icon: Icons.list,
                    label: 'Toutes les tâches',
                    isSelected: _selectedProject == null && !_showCompletedTasks && !_showNoProjectTasks && !_showShoppingList && _currentView == ViewMode.list,
                    onTap: () {
                      setState(() {
                        _selectedProject = null;
                        _showCompletedTasks = false;
                        _showNoProjectTasks = false;
                        _showShoppingList = false;
                        _currentView = ViewMode.list;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.calendar_month,
                    label: 'Calendrier',
                    isSelected: _currentView == ViewMode.calendar,
                    onTap: () {
                      setState(() {
                        _currentView = ViewMode.calendar;
                        _showShoppingList = false;
                        _showCompletedTasks = false;
                        _showNoProjectTasks = false;
                        _selectedProject = null;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  // Élément "Courses" (conditionnel selon les préférences)
                  if (PreferencesService().shoppingListEnabled)
                    _buildDrawerItem(
                      icon: Icons.shopping_cart,
                      label: 'Courses',
                      count: _todos.where((t) => t.projectId == ProjectService.SHOPPING_LIST_PROJECT_ID && !t.isCompleted).length,
                      isSelected: _showShoppingList,
                      onTap: () {
                        setState(() {
                          _showShoppingList = true;
                          _showCompletedTasks = false;
                          _showNoProjectTasks = false;
                          _selectedProject = null;
                          _currentView = ViewMode.list;
                        });
                        Navigator.pop(context);
                      },
                    ),
                  _buildDrawerItem(
                    icon: Icons.check_circle_outline,
                    label: 'Tâches achevées',
                    isSelected: _showCompletedTasks,
                    onTap: () {
                      setState(() {
                        _showCompletedTasks = true;
                        _showNoProjectTasks = false;
                        _selectedProject = null;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Builder(
                      builder: (context) => Text('PROJETS', style: DSTypo.captionOf(context)),
                    ),
                  ),
                  
                  _buildDrawerItem(
                    icon: Icons.folder_off_outlined,
                    label: 'Tâches sans projet',
                    count: _todos.where((t) => t.projectId == null && !t.isCompleted).length,
                    isSelected: _showNoProjectTasks,
                    onTap: () {
                      setState(() {
                        _showNoProjectTasks = true;
                        _showCompletedTasks = false;
                        _showShoppingList = false;
                        _selectedProject = null;
                        _currentView = ViewMode.list;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  
                  ..._projects.where((project) => project.id != ProjectService.SHOPPING_LIST_PROJECT_ID).map((project) {
                    final count = _todos.where((t) => t.projectId == project.id && !t.isCompleted).length;
                    return _buildDrawerItem(
                      icon: project.icon,
                      iconColor: project.color,
                      label: project.name,
                      count: count,
                      isSelected: _selectedProject?.id == project.id,
                      onTap: () {
                        setState(() {
                          _selectedProject = project;
                          _showNoProjectTasks = false;
                          _showCompletedTasks = false;
                          _showShoppingList = false;
                          _currentView = ViewMode.list;
                        });
                        Navigator.pop(context);
                      },
                      onEdit: () => _editProject(project),
                      onDelete: () => _deleteProject(project),
                    );
                  }),
                  
                  Builder(
                    builder: (context) {
                      final brightness = Theme.of(context).brightness;
                      final borderColor = DSColor.getSurfaceTint(brightness);
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _addProject();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: borderColor, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, size: 20, color: DSColor.primary),
                                SizedBox(width: 8),
                                Text(
                                  'Nouveau projet',
                                  style: TextStyle(
                                    color: DSColor.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Footer
            _buildDrawerItem(
              icon: Icons.settings_outlined,
              label: 'Paramètres',
              onTap: () {
                Navigator.pop(context);
                _showSettings();
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16), // Padding pour la barre de navigation Android
          ],
            ),
          );
        },
      ),
      body: DSBackdrop(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- HEADER ---
              Builder(
                builder: (context) {
                  final brightness = Theme.of(context).brightness;
                  final headingColor = DSColor.getHeading(brightness);
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.menu, color: headingColor),
                          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                        ),
                        Expanded(
                          child: Text(
                            _getAppBarTitle(),
                            style: DSTypo.h1.copyWith(color: headingColor),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                _isSearchActive ? Icons.close : Icons.search,
                                color: headingColor,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isSearchActive = !_isSearchActive;
                                  if (!_isSearchActive) {
                                    _searchQuery = '';
                                  }
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.mic, color: headingColor),
                              onPressed: _addTodoByVoice,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              // --- SEARCH FIELD ---
              if (_isSearchActive)
                Builder(
                  builder: (context) {
                    final brightness = Theme.of(context).brightness;
                    final surfaceColor = DSColor.getSurface(brightness);
                    final headingColor = DSColor.getHeading(brightness);
                    final mutedColor = DSColor.getMuted(brightness);
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: brightness == Brightness.dark
                              ? []
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: TextField(
                          autofocus: true,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                          style: DSTypo.body.copyWith(color: headingColor),
                          decoration: InputDecoration(
                            hintText: 'Rechercher une tâche...',
                            hintStyle: DSTypo.body.copyWith(color: mutedColor),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            filled: true,
                            fillColor: surfaceColor,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: DSColor.primary, width: 1.5),
                            ),
                            prefixIcon: const Icon(Icons.search, color: DSColor.primary, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18, color: DSColor.muted),
                                    onPressed: () {
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // --- SORT & STATS ---
              Builder(
                builder: (context) {
                  final brightness = Theme.of(context).brightness;
                  final surfaceColor = DSColor.getSurface(brightness);
                  final bodyColor = DSColor.getBody(brightness);
                  final mutedColor = DSColor.getMuted(brightness);
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: _showSortDialog,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: surfaceColor.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sort, size: 16, color: bodyColor),
                                const SizedBox(width: 6),
                                Text(_getSortDisplayName(), style: DSTypo.caption.copyWith(color: mutedColor)),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text('${_getActiveTasksCount()} tâches', style: DSTypo.caption.copyWith(color: mutedColor)),
                      ],
                    ),
                  );
                },
              ),
          // Zone de drop générale pour remettre une tâche au niveau racine
          DragTarget<TodoItem>(
            onWillAccept: (dragged) {
              if (dragged == null) return false;
              return dragged.parentId != null; // Seulement si la tâche a un parent
            },
            onAccept: (dragged) => _moveTaskToRoot(dragged.id),
            builder: (context, candidate, rejected) {
              return Container(
                height: candidate.isNotEmpty ? 40 : 0,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: candidate.isNotEmpty 
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                    : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: candidate.isNotEmpty
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      )
                    : null,
                ),
                child: candidate.isNotEmpty
                  ? Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_up,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Remettre au niveau principal',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : null,
              );
            },
          ),
          // --- TASK LIST ---
          Expanded(
            child: _currentView == ViewMode.calendar
                ? _buildCalendarView()
                : _buildListView(),
          ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [DSColor.primary, DSColor.accent],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: DSShadow.floating(DSColor.primary),
          ),
          child: FloatingActionButton(
            onPressed: _addTodo,
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildDraggableTaskRow(TodoItem todo) {
    final hasSubTasks = _getVisibleSubTasks(todo.id).isNotEmpty;
    final isExpanded = _expandedTasks.contains(todo.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DragTarget<TodoItem>(
          onWillAccept: (dragged) {
            if (dragged == null) return false;
            if (dragged.id == todo.id) return false;
            if (_isDescendant(dragged.id, todo.id)) return false;

            final newLevel = todo.level + 1;
            final deepestDragged = _getDeepestLevel(dragged.id);
            final relativeDepth = deepestDragged - dragged.level;
            final willFit = newLevel + relativeDepth <= 3;

            return todo.canHaveSubTasks && willFit;
          },
          onAccept: (dragged) {
            _moveTaskToParent(dragged.id, todo.id);
            setState(() {
              _expandedTasks.add(todo.id);
            });
          },
          builder: (context, candidate, rejected) {
            final card = _buildDSTaskItem(todo, enableLongPressEdit: false);
            return LongPressDraggable<TodoItem>(
              data: todo,
              feedback: _buildDragFeedback(todo),
              childWhenDragging: Opacity(opacity: 0.5, child: card),
              child: Container(
                margin: EdgeInsets.only(left: 32.0 * todo.level),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: candidate.isNotEmpty
                      ? Border.all(
                          color: Theme.of(context).colorScheme.secondary,
                          width: 2,
                        )
                      : null,
                ),
                child: card,
              ),
            );
          },
        ),
        if (isExpanded && hasSubTasks)
          ..._getVisibleSubTasks(todo.id).map((subTask) => _buildDraggableTaskRow(subTask)),
      ],
    );
  }

  Widget _buildRootDropZone() {
    return DragTarget<TodoItem>(
      onWillAccept: (dragged) {
        if (dragged == null) return false;
        return dragged.parentId != null; // seulement si la tâche est déjà une sous-tâche
      },
      onAccept: (dragged) => _moveTaskToRoot(dragged.id),
      builder: (context, candidate, rejected) {
        final isActive = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: isActive ? 32 : 12,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: isActive
              ? Center(
                  child: Text(
                    'Déposer ici pour remonter au niveau principal',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildListView() {
    if (_filteredTodos.isEmpty) {
      return Center(child: Builder(
        builder: (context) => Text('Aucune tâche', style: DSTypo.bodyOf(context)),
      ));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 100),
      itemCount: _filteredTodos.length,
      itemBuilder: (context, index) {
        final todo = _filteredTodos[index];
        final children = <Widget>[
          _buildRootDropZone(),
          _buildDraggableTaskRow(todo),
        ];
        if (index == _filteredTodos.length - 1) {
          children.add(_buildRootDropZone());
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }

  Widget _buildCalendarView() {
    final today = DateTime.now();
    final dates = List.generate(61, (index) => today.subtract(const Duration(days: 30)).add(Duration(days: index)));
    
    // 1. Priorités de la semaine
    final weeklyPriorities = _todos.where((t) {
      if (!t.isWeeklyPriority) return false;
      if (t.isCompleted) return false;
      
      // Si pas de date, on garde (persistant)
      if (t.dueDate == null && t.reminder == null) return true;
      
      // Si date, doit être dans la même semaine que la date sélectionnée
      final date = t.dueDate ?? t.reminder!;
      return _isSameWeek(date, _calendarSelectedDate);
    }).toList();

    // 2. Filtrer les tâches pour la date sélectionnée (Liste principale)
    final tasksForDate = _todos.where((t) {
      if (t.isWeeklyPriority) return false; // Exclure les priorités déjà affichées en haut
      if (t.isCompleted) return false;
      
      final hasDueDate = t.dueDate != null && _isSameDay(t.dueDate!, _calendarSelectedDate);
      final hasReminder = t.reminder != null && _isSameDay(t.reminder!, _calendarSelectedDate);
      return hasDueDate || hasReminder;
    }).toList();

    tasksForDate.sort((a, b) {
      final timeA = a.dueDate ?? a.reminder ?? DateTime(2100);
      final timeB = b.dueDate ?? b.reminder ?? DateTime(2100);
      return timeA.compareTo(timeB);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        // Section Priorités de la semaine
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Priorités de la semaine',
                    style: DSTypo.h2Of(context).copyWith(fontSize: 14),
                  ),
                  InkWell(
                    onTap: _openAddWeeklyPriorityModal,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(Icons.add, size: 20, color: DSColor.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (weeklyPriorities.isEmpty)
                Text(
                  'Aucune priorité définie',
                  style: DSTypo.captionOf(context).copyWith(fontStyle: FontStyle.italic),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: weeklyPriorities.map((t) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: DSColor.getSurfaceTint(Theme.of(context).brightness),
                        borderRadius: DSRadius.soft,
                        border: Border.all(color: DSColor.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => _toggleTodo(t.id),
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: DSColor.primary, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _editTodo(t),
                            child: Text(
                              t.title,
                              style: DSTypo.bodyOf(context).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        // Timeline horizontale
        SizedBox(
          height: 108,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            // On essaie de centrer sur la date sélectionnée au démarrage (approximatif sans ScrollController complexe)
            // Pour l'instant simple
            controller: ScrollController(initialScrollOffset: 30 * 74.0), // 30 jours * largeur approx (64+10)
            itemCount: dates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final date = dates[index];
              final isSelected = _isSameDay(date, _calendarSelectedDate);
              return GestureDetector(
                onTap: () => setState(() => _calendarSelectedDate = date),
                child: DSDatePill(
                  month: _getMonthName(date.month),
                  day: date.day.toString(),
                  week: _getWeekDayName(date.weekday),
                  selected: isSelected,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Liste des tâches pour le jour
        Expanded(
          child: tasksForDate.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 48, color: DSColor.muted.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune tâche prévue',
                        style: DSTypo.bodyOf(context).copyWith(color: DSColor.muted),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 100),
                  itemCount: tasksForDate.length,
                  itemBuilder: (context, index) {
                    final todo = tasksForDate[index];
                    return _buildDSTaskItem(todo);
                  },
                ),
        ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSameWeek(DateTime a, DateTime b) {
    final aStart = a.subtract(Duration(days: a.weekday - 1));
    final aEnd = aStart.add(const Duration(days: 6));
    
    final bStart = b.subtract(Duration(days: b.weekday - 1));
    final bEnd = bStart.add(const Duration(days: 6));
    
    // Comparer simplement les dates de début de semaine (en ignorant l'heure)
    return aStart.year == bStart.year && aStart.month == bStart.month && aStart.day == bStart.day;
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
    return months[month - 1];
  }

  String _getWeekDayName(int weekday) {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return days[weekday - 1];
  }

  void _openAddWeeklyPriorityModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        child: AddTodoModal(
          projects: _projects,
          selectedProject: null, // Aucun projet par défaut
          isWeeklyPriority: true,
        ),
      ),
    ).then(_handleTodoResult);
  }

  Widget _buildDSTaskItem(TodoItem todo, {bool enableLongPressEdit = true}) {
    // Determine status
    Widget statusWidget;
    if (todo.isCompleted) {
      statusWidget = const DSStatusTag.done();
    } else if (_timerService.isTaskRunning(todo.id)) {
      statusWidget = const DSStatusTag.inProgress();
    } else {
      statusWidget = const DSStatusTag.todo();
    }

    // Determine Project info
    final project = todo.projectId != null
        ? _projects.firstWhere(
            (p) => p.id == todo.projectId,
            orElse: () => Project(id: -1, name: 'Général', color: Colors.grey, icon: Icons.list),
          )
        : Project(id: -1, name: 'Aucun projet', color: Colors.grey, icon: Icons.folder_off);

    final hasSubTasks = _getVisibleSubTasks(todo.id).isNotEmpty;
    final isExpanded = _expandedTasks.contains(todo.id);

    return GestureDetector(
      onTap: () => _editTodo(todo),
      onLongPress: enableLongPressEdit ? () => _editTodo(todo) : null,
      child: DSTaskCard(
        categoryIcon: project.icon,
        categoryColor: project.color,
        category: project.name,
        title: todo.title,
        time: todo.dueDate != null 
             ? "${todo.dueDate!.day}/${todo.dueDate!.month}/${todo.dueDate!.year}"
             : "",
        reminder: todo.reminder,
        status: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasSubTasks)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 18,
                icon: Icon(
                  isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  color: DSColor.muted,
                ),
                onPressed: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedTasks.remove(todo.id);
                    } else {
                      _expandedTasks.add(todo.id);
                    }
                  });
                },
                tooltip: isExpanded ? 'Masquer les sous-tâches' : 'Afficher les sous-tâches',
              ),
            if (hasSubTasks) const SizedBox(width: 6),
            statusWidget,
          ],
        ),
        isCompleted: todo.isCompleted,
        onToggleCompletion: () => _toggleTodo(todo.id),
      ),
    );
  }

  Widget _buildProjectItem(Project project, {bool isAllTasks = false}) {
    final isSelected = _selectedProject?.id == project.id || (isAllTasks && _selectedProject == null);
    final todoCount = isAllTasks 
        ? _todos.where((todo) => todo.isRootTask).length
        : _todos.where((todo) => todo.projectId == project.id).length;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isAllTasks) {
              _selectedProject = null;
            } else {
              _selectedProject = project;
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected 
                ? project.color.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? project.color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: project.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  project.name,
                  style: TextStyle(
                    color: isSelected ? project.color : Theme.of(context).colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? project.color : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$todoCount',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Bouton de suppression (seulement si le projet est sélectionné et n'est pas le projet par défaut)
              if (isSelected)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                    onPressed: () => _deleteProject(project),
                    tooltip: 'Supprimer ce projet',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddTodoModal extends StatefulWidget {
  final List<Project> projects;
  final Project? selectedProject; // Projet sélectionné par défaut
  final bool isWeeklyPriority;
  
  const AddTodoModal({
    super.key, 
    required this.projects,
    this.selectedProject, // Projet sélectionné par défaut
    this.isWeeklyPriority = false,
  });

  @override
  State<AddTodoModal> createState() => _AddTodoModalState();
}

class _AddTodoModalState extends State<AddTodoModal> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _estimatedTimeController = TextEditingController();
  DateTime? _selectedDate;
  DateTime? _selectedReminder;
  Priority _selectedPriority = Priority.medium;
  Project? _selectedProject;

  // Ajout pour la gestion des sous-tâches
  final TextEditingController _subTaskController = TextEditingController();
  List<TodoItem> _subTasks = [];

  @override
  void initState() {
    super.initState();
    // Utiliser le projet sélectionné par défaut, sinon "Aucun projet" (null)
    _selectedProject = widget.selectedProject;
  }

  void _addSubTask() {
    if (_subTaskController.text.trim().isNotEmpty) {
      setState(() {
        final subTask = TodoItem(
          id: DateTime.now().millisecondsSinceEpoch + _subTasks.length, // ID unique
          title: _subTaskController.text.trim(),
          description: '',
          priority: Priority.medium,
          projectId: _selectedProject?.id,
          isCompleted: false,
          parentId: null, // Sera mis à jour quand la tâche parente sera créée
          level: 1, // Sous-tâche de niveau 1
          estimatedMinutes: null,
          elapsedMinutes: 0,
          elapsedSeconds: 0,
        );
        _subTasks.add(subTask);
        _subTaskController.clear();

        // Afficher un toast de confirmation
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sous-tâche "${subTask.title}" ajoutée'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    return Padding(
      padding: EdgeInsets.only(
        bottom: keyboardHeight,
      ),
      child: Builder(
        builder: (context) {
          final brightness = Theme.of(context).brightness;
          final surfaceSoftColor = DSColor.getSurfaceSoft(brightness);
          final surfaceColor = DSColor.getSurface(brightness);
          final headingColor = DSColor.getHeading(brightness);
          final mutedColor = DSColor.getMuted(brightness);
          
          return SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 24 + bottomPadding + 16, // Padding supplémentaire pour la barre de navigation Android
              ),
              decoration: BoxDecoration(
                color: surfaceSoftColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Nouvelle Tâche', style: DSTypo.h1Of(context)),
                  IconButton(
                    icon: Icon(Icons.close, color: headingColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Projet
              Text('Projet', style: DSTypo.body.copyWith(fontWeight: FontWeight.w600, color: headingColor)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: DSRadius.soft,
                  boxShadow: [
                    BoxShadow(
                      color: brightness == Brightness.dark 
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Project?>(
                    value: _selectedProject,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: DSColor.primary),
                    items: [
                      DropdownMenuItem<Project?>(
                        value: null,
                        child: Builder(
                          builder: (context) {
                            final brightness = Theme.of(context).brightness;
                            final mutedColor = DSColor.getMuted(brightness);
                            return Row(
                              children: [
                                Icon(Icons.folder_off, color: mutedColor, size: 20),
                                const SizedBox(width: 8),
                                Text('Aucun projet', style: DSTypo.bodyOf(context)),
                              ],
                            );
                          },
                        ),
                      ),
                      ...widget.projects.map((project) {
                        return DropdownMenuItem<Project?>(
                          value: project,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: project.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(project.name, style: DSTypo.body),
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedProject = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Titre
              DSTextField(
                label: 'Titre *',
                controller: _titleController,
                hint: 'Qu\'avez-vous à faire ?',
                helperText: '${_titleController.text.length}/200 caractères',
                errorText: _titleController.text.length > 200 
                  ? 'Le titre ne peut pas dépasser 200 caractères'
                  : null,
                onChanged: (value) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Description
              DSTextField(
                label: 'Description',
                controller: _descriptionController,
                hint: 'Détails supplémentaires (optionnel)',
                maxLines: 10, // Maximum de 10 lignes visibles
                minLines: 4, // Hauteur minimale de 4 lignes pour une meilleure visibilité
              ),
              const SizedBox(height: 16),

              // Date & Rappel Row
              Row(
                children: [
                  Expanded(
                    child: DSTextField(
                      label: 'Échéance',
                      readOnly: true,
                      controller: TextEditingController(
                        text: _selectedDate != null
                            ? '${_selectedDate!.day}/${_selectedDate!.month}'
                            : '',
                      ),
                      hint: 'Date',
                      prefixIcon: const Icon(Icons.calendar_today, size: 18, color: DSColor.primary),
                      suffixIcon: _selectedDate != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: DSColor.muted),
                              onPressed: () => setState(() => _selectedDate = null),
                            )
                          : null,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() => _selectedDate = date);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DSTextField(
                      label: 'Rappel',
                      readOnly: true,
                      controller: TextEditingController(
                        text: _selectedReminder != null
                            ? '${_selectedReminder!.hour}:${_selectedReminder!.minute.toString().padLeft(2, '0')}'
                            : '',
                      ),
                      hint: 'Heure',
                      prefixIcon: const Icon(Icons.alarm, size: 18, color: DSColor.primary),
                      suffixIcon: _selectedReminder != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: DSColor.muted),
                              onPressed: () => setState(() => _selectedReminder = null),
                            )
                          : null,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedReminder ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) {
                            setState(() {
                              _selectedReminder = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Priorité & Temps Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Priorité', style: DSTypo.body.copyWith(fontWeight: FontWeight.w600, color: headingColor)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: DSRadius.soft,
                            boxShadow: [
                              BoxShadow(
                                color: brightness == Brightness.dark 
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.black.withOpacity(0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Priority>(
                              value: _selectedPriority,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down, color: DSColor.primary),
                              items: Priority.values.map((priority) {
                                return DropdownMenuItem(
                                  value: priority,
                                  child: Text(getPriorityText(priority), style: DSTypo.body),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) setState(() => _selectedPriority = value);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DSTextField(
                      label: 'Durée (min)',
                      controller: _estimatedTimeController,
                      hint: '30',
                      prefixIcon: const Icon(Icons.timer, size: 18, color: DSColor.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Sous-tâches
              Text('Sous-tâches', style: DSTypo.h2Of(context)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DSTextField(
                      label: '',
                      controller: _subTaskController,
                      hint: 'Ajouter une étape...',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 24), // Align with input
                    child: IconButton(
                      onPressed: _addSubTask,
                      icon: const Icon(Icons.add_circle, color: DSColor.primary, size: 32),
                    ),
                  ),
                ],
              ),
              if (_subTasks.isNotEmpty) ...[
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _subTasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final subTask = _subTasks[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: surfaceSoftColor,
                          borderRadius: DSRadius.soft,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 16, color: mutedColor),
                            const SizedBox(width: 8),
                            Expanded(child: Text(subTask.title, style: DSTypo.bodyOf(context))),
                            IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Colors.red),
                            onPressed: () => setState(() => _subTasks.removeAt(index)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 32),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: DSButton.secondary(
                      label: 'Annuler',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DSButton(
                      label: 'Créer',
                      onPressed: _titleController.text.trim().isEmpty || _titleController.text.length > 200
                          ? null
                          : () {
                              // Validation logic identical to before...
                              if (_titleController.text.length > 200) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Le titre ne peut pas dépasser 200 caractères')),
                                );
                                return;
                              }
                              
                              int? estimatedMinutes;
                              if (_estimatedTimeController.text.trim().isNotEmpty) {
                                try {
                                  estimatedMinutes = int.parse(_estimatedTimeController.text.trim());
                                  if (estimatedMinutes <= 0) throw Exception();
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Temps estimé invalide')),
                                  );
                                  return;
                                }
                              }

                              final newTodo = TodoItem(
                                id: DateTime.now().millisecondsSinceEpoch,
                                title: _titleController.text.trim(),
                                description: _descriptionController.text.trim(),
                                dueDate: _selectedDate,
                                priority: _selectedPriority,
                                projectId: _selectedProject?.id,
                                isCompleted: false,
                                parentId: null,
                                level: 0,
                                reminder: _selectedReminder,
                                estimatedMinutes: estimatedMinutes,
                                elapsedMinutes: 0,
                                elapsedSeconds: 0,
                                isWeeklyPriority: widget.isWeeklyPriority,
                              );
                              Navigator.pop(context, {
                                'todo': newTodo,
                                'subTasks': _subTasks,
                              });
                            },
                    ),
                  ),
                ],
              ),
            ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subTaskController.dispose();
    super.dispose();
  }
}

class EditTodoModal extends StatefulWidget {
  final TodoItem todo;
  final List<Project> projects;
  final List<TodoItem> subTasks;
  final Function(TodoItem) onAddSubTask;
  final Function(int) onToggleSubTask;
  final Function(int) onDeleteTodo; // Callback pour supprimer une tâche
  final Function(TodoItem)? onEditSubTask; // Callback pour éditer une sous-tâche
  final _TodoHomePageState homeState; // Référence directe au homeState
  
  const EditTodoModal({
    super.key, 
    required this.todo,
    required this.projects,
    required this.subTasks,
    required this.onAddSubTask,
    required this.onToggleSubTask,
    required this.onDeleteTodo,
    this.onEditSubTask,
    required this.homeState,
  });

  @override
  State<EditTodoModal> createState() => _EditTodoModalState();
}

class _EditTodoModalState extends State<EditTodoModal> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _estimatedTimeController;
  late DateTime? _selectedDate;
  late DateTime? _selectedReminder;
  late Priority _selectedPriority;
  late Project? _selectedProject;

  // Ajout pour la gestion des sous-tâches
  final TextEditingController _subTaskController = TextEditingController();
  late List<TodoItem> _subTasks;

  // Variables pour la récurrence
  late RecurrenceType _selectedRecurrenceType;
  late int? _selectedRecurrenceDayOfWeek;
  late int? _selectedRecurrenceDayOfMonth;
  late TimeOfDay? _selectedRecurrenceTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo.title);
    _descriptionController = TextEditingController(text: widget.todo.description);
    _estimatedTimeController = TextEditingController(text: widget.todo.estimatedMinutes?.toString() ?? '');
    _selectedDate = widget.todo.dueDate;
    _selectedReminder = widget.todo.reminder;
    _selectedPriority = widget.todo.priority;
    _selectedProject = widget.projects.isEmpty 
        ? null 
        : widget.projects.firstWhere(
            (project) => project.id == widget.todo.projectId,
            orElse: () => widget.projects.first,
          );
    _subTasks = widget.subTasks;
    
    // Initialisation des variables de récurrence
    _selectedRecurrenceType = widget.todo.recurrenceType;
    _selectedRecurrenceDayOfWeek = widget.todo.recurrenceDayOfWeek;
    _selectedRecurrenceDayOfMonth = widget.todo.recurrenceDayOfMonth;
    _selectedRecurrenceTime = widget.todo.recurrenceTime;
  }

  String _getRecurrenceTypeText(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.none:
        return 'Non récurrente';
      case RecurrenceType.daily:
        return 'Quotidienne';
      case RecurrenceType.weekly:
        return 'Hebdomadaire';
      case RecurrenceType.monthly:
        return 'Mensuelle';
    }
  }

  void _addSubTask() {
    if (_subTaskController.text.trim().isNotEmpty) {
      try {
        final subTask = widget.todo.createSubTask(
          title: _subTaskController.text.trim(),
          description: '',
          estimatedMinutes: null,
        );
        
        // Ajouter la sous-tâche à la liste principale
        widget.onAddSubTask(subTask);
        
        // Mettre à jour la liste locale
        setState(() {
          _subTasks = List.from(_subTasks)..add(subTask);
        });
        
        // Sauvegarder immédiatement
        widget.homeState._saveData();

        _subTaskController.clear();
        debugPrint('✅ _addSubTask(): Sous-tâche "${subTask.title}" ajoutée et sauvegardée');

        // Afficher un toast de confirmation
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sous-tâche "${subTask.title}" ajoutée'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ _addSubTask(): Erreur lors de l\'ajout de la sous-tâche: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    return DSBackdrop(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: keyboardHeight,
          top: MediaQuery.of(context).padding.top + 16,
        ),
        child: Builder(
          builder: (context) {
            final brightness = Theme.of(context).brightness;
            final surfaceSoftColor = DSColor.getSurfaceSoft(brightness);
            final surfaceColor = DSColor.getSurface(brightness);
            final headingColor = DSColor.getHeading(brightness);
            final mutedColor = DSColor.getMuted(brightness);
            
            return SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: 24 + bottomPadding + 16, // Padding supplémentaire pour la barre de navigation Android
                ),
                decoration: BoxDecoration(
                  color: surfaceSoftColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Modifier la Tâche', style: DSTypo.h1Of(context)),
                  IconButton(
                    icon: Icon(Icons.close, color: headingColor),
                    onPressed: () {
                      debugPrint('🔄 [EditTodoModal] Bouton fermer (X) cliqué');
                      _saveChanges();
                      widget.homeState.setState(() {
                        debugPrint('🔄 [EditTodoModal] setState() appelé après clic sur X');
                      });
                      debugPrint('🔄 [EditTodoModal] Fermeture du modal...');
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Projet
              Text('Projet', style: DSTypo.body.copyWith(fontWeight: FontWeight.w600, color: headingColor)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: DSRadius.soft,
                  boxShadow: [
                    BoxShadow(
                      color: brightness == Brightness.dark 
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Project?>(
                    value: _selectedProject,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: DSColor.primary),
                    items: [
                      DropdownMenuItem<Project?>(
                        value: null,
                        child: Builder(
                          builder: (context) {
                            final brightness = Theme.of(context).brightness;
                            final mutedColor = DSColor.getMuted(brightness);
                            return Row(
                              children: [
                                Icon(Icons.folder_off, color: mutedColor, size: 20),
                                const SizedBox(width: 8),
                                Text('Aucun projet', style: DSTypo.bodyOf(context)),
                              ],
                            );
                          },
                        ),
                      ),
                      ...widget.projects.map((project) {
                        return DropdownMenuItem<Project?>(
                          value: project,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: project.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(project.name, style: DSTypo.body),
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedProject = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Titre
              DSTextField(
                label: 'Titre *',
                controller: _titleController,
                hint: 'Qu\'avez-vous à faire ?',
                helperText: '${_titleController.text.length}/200 caractères',
                errorText: _titleController.text.length > 200
                    ? 'Le titre ne peut pas dépasser 200 caractères'
                    : null,
                onChanged: (value) => setState(() {}),
              ),
              const SizedBox(height: 16),
              
              // Description
              DSTextField(
                label: 'Description',
                controller: _descriptionController,
                hint: 'Détails supplémentaires (optionnel)',
                maxLines: 10, // Maximum de 10 lignes visibles
                minLines: 4, // Hauteur minimale de 4 lignes pour une meilleure visibilité
              ),
              const SizedBox(height: 16),
              
              // Date d'échéance
              DSTextField(
                label: 'Date d\'échéance',
                readOnly: true,
                controller: TextEditingController(
                  text: _selectedDate != null
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : '',
                ),
                hint: 'Date',
                prefixIcon: const Icon(Icons.calendar_today, size: 18, color: DSColor.primary),
                suffixIcon: _selectedDate != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: DSColor.muted),
                        onPressed: () => setState(() => _selectedDate = null),
                      )
                    : null,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // Rappel
              DSTextField(
                label: 'Rappel',
                readOnly: true,
                controller: TextEditingController(
                  text: _selectedReminder != null
                      ? '${_selectedReminder!.day}/${_selectedReminder!.month}/${_selectedReminder!.year} à ${_selectedReminder!.hour.toString().padLeft(2, '0')}:${_selectedReminder!.minute.toString().padLeft(2, '0')}'
                      : '',
                ),
                hint: 'Heure',
                prefixIcon: const Icon(Icons.alarm, size: 18, color: DSColor.primary),
                suffixIcon: _selectedReminder != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: DSColor.muted),
                        onPressed: () => setState(() => _selectedReminder = null),
                      )
                    : null,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedReminder ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _selectedReminder != null
                          ? TimeOfDay(hour: _selectedReminder!.hour, minute: _selectedReminder!.minute)
                          : TimeOfDay.now(),
                    );
                    if (time != null) {
                      setState(() {
                        _selectedReminder = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // Priorité & Temps Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Priorité', style: DSTypo.body.copyWith(fontWeight: FontWeight.w600, color: headingColor)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: DSRadius.soft,
                            boxShadow: [
                              BoxShadow(
                                color: brightness == Brightness.dark 
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.black.withOpacity(0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Priority>(
                              value: _selectedPriority,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down, color: DSColor.primary),
                              items: Priority.values.map((priority) {
                                return DropdownMenuItem(
                                  value: priority,
                                  child: Text(getPriorityText(priority), style: DSTypo.body),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) setState(() => _selectedPriority = value);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DSTextField(
                      label: 'Durée (min)',
                      controller: _estimatedTimeController,
                      hint: '30',
                      prefixIcon: const Icon(Icons.timer, size: 18, color: DSColor.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Section Récurrence
              Text('Récurrence', style: DSTypo.h2Of(context)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: DSRadius.soft,
                  boxShadow: [
                    BoxShadow(
                      color: brightness == Brightness.dark 
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<RecurrenceType>(
                    value: _selectedRecurrenceType,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: DSColor.primary),
                    items: RecurrenceType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_getRecurrenceTypeText(type), style: DSTypo.body),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedRecurrenceType = value;
                          if (value == RecurrenceType.none) {
                            _selectedRecurrenceDayOfWeek = null;
                            _selectedRecurrenceDayOfMonth = null;
                            _selectedRecurrenceTime = null;
                          }
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // Paramètres spécifiques selon le type de récurrence
              if (_selectedRecurrenceType != RecurrenceType.none) ...[
                DSTextField(
                  label: 'Heure de récurrence *',
                  readOnly: true,
                  controller: TextEditingController(
                    text: _selectedRecurrenceTime != null
                        ? '${_selectedRecurrenceTime!.hour.toString().padLeft(2, '0')}:${_selectedRecurrenceTime!.minute.toString().padLeft(2, '0')}'
                        : '',
                  ),
                  hint: 'Heure',
                  prefixIcon: const Icon(Icons.access_time, size: 18, color: DSColor.primary),
                  suffixIcon: _selectedRecurrenceTime != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: DSColor.muted),
                          onPressed: () => setState(() => _selectedRecurrenceTime = null),
                        )
                      : null,
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _selectedRecurrenceTime ?? TimeOfDay.now(),
                    );
                    if (time != null) {
                      setState(() {
                        _selectedRecurrenceTime = time;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                
                // Paramètres spécifiques pour hebdomadaire
                if (_selectedRecurrenceType == RecurrenceType.weekly) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Jour de la semaine *', style: DSTypo.body.copyWith(fontWeight: FontWeight.w600, color: headingColor)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: DSRadius.soft,
                              boxShadow: [
                            BoxShadow(
                              color: brightness == Brightness.dark 
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedRecurrenceDayOfWeek,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, color: DSColor.primary),
                            items: [
                              DropdownMenuItem(value: 1, child: Builder(
                                builder: (context) => Text('Lundi', style: DSTypo.bodyOf(context)),
                              )),
                              DropdownMenuItem(value: 2, child: Builder(
                                builder: (context) => Text('Mardi', style: DSTypo.bodyOf(context)),
                              )),
                              DropdownMenuItem(value: 3, child: Builder(
                                builder: (context) => Text('Mercredi', style: DSTypo.bodyOf(context)),
                              )),
                              DropdownMenuItem(value: 4, child: Builder(
                                builder: (context) => Text('Jeudi', style: DSTypo.bodyOf(context)),
                              )),
                              DropdownMenuItem(value: 5, child: Builder(
                                builder: (context) => Text('Vendredi', style: DSTypo.bodyOf(context)),
                              )),
                              DropdownMenuItem(value: 6, child: Builder(
                                builder: (context) => Text('Samedi', style: DSTypo.bodyOf(context)),
                              )),
                              DropdownMenuItem(value: 7, child: Builder(
                                builder: (context) => Text('Dimanche', style: DSTypo.bodyOf(context)),
                              )),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedRecurrenceDayOfWeek = value);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                
                // Paramètres spécifiques pour mensuel
                if (_selectedRecurrenceType == RecurrenceType.monthly) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Jour du mois *', style: DSTypo.body.copyWith(fontWeight: FontWeight.w600, color: headingColor)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: DSRadius.soft,
                              boxShadow: [
                            BoxShadow(
                              color: brightness == Brightness.dark 
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedRecurrenceDayOfMonth,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, color: DSColor.primary),
                            items: List.generate(31, (index) {
                              return DropdownMenuItem(
                                value: index + 1,
                                child: Text('${index + 1}', style: DSTypo.body),
                              );
                            }),
                            onChanged: (value) {
                              setState(() => _selectedRecurrenceDayOfMonth = value);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              
              const SizedBox(height: 24),
              
              // Section Sous-tâches
              if (widget.todo.canHaveSubTasks) ...[
                Text('Sous-tâches', style: DSTypo.h2Of(context)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DSTextField(
                        label: '',
                        controller: _subTaskController,
                        hint: 'Ajouter une étape...',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: IconButton(
                        onPressed: _addSubTask,
                        icon: const Icon(Icons.add_circle, color: DSColor.primary, size: 32),
                      ),
                    ),
                  ],
                ),
                if (_subTasks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      // Trier les sous-tâches : non terminées en premier, terminées en dernier
                      final sortedSubTasks = List<TodoItem>.from(_subTasks)
                        ..sort((a, b) {
                          if (a.isCompleted == b.isCompleted) return 0;
                          return a.isCompleted ? 1 : -1; // Non terminées en premier
                        });
                      
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sortedSubTasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final subTask = sortedSubTasks[index];
                          // Trouver l'index original pour la suppression
                          final originalIndex = _subTasks.indexWhere((t) => t.id == subTask.id);
                      final brightness = Theme.of(context).brightness;
                      final surfaceSoftColor = DSColor.getSurfaceSoft(brightness);
                      final bodyColor = DSColor.getBody(brightness);
                      final mutedColor = DSColor.getMuted(brightness);
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: surfaceSoftColor,
                          borderRadius: DSRadius.soft,
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: subTask.isCompleted,
                              onChanged: (_) {
                                debugPrint('🟢 [EditTodoModal] Toggle checkbox sous-tâche: ${subTask.title} (ID: ${subTask.id})');
                                if (widget.onToggleSubTask != null) {
                                  widget.onToggleSubTask!(subTask.id);
                                }
                                setState(() {
                                  subTask.isCompleted = !subTask.isCompleted;
                                });
                              },
                              activeColor: DSColor.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  debugPrint('🟢 [EditTodoModal] Clic sur sous-tâche: ${subTask.title} (ID: ${subTask.id})');
                                  if (widget.onEditSubTask != null) {
                                    widget.onEditSubTask!(subTask);
                                  } else {
                                    final homeState = context.findAncestorStateOfType<_TodoHomePageState>();
                                    if (homeState != null) {
                                      final subTasks = homeState._getVisibleSubTasks(subTask.id);
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        builder: (context) => EditTodoModal(
                                          todo: subTask,
                                          projects: homeState._projects,
                                          subTasks: subTasks,
                                          onAddSubTask: (newSubTask) {
                                            homeState.setState(() {
                                              homeState._todos.add(newSubTask);
                                            });
                                          },
                                          onToggleSubTask: (id) {
                                            homeState.setState(() {
                                              final index = homeState._todos.indexWhere((t) => t.id == id);
                                              if (index != -1) {
                                                homeState._todos[index].isCompleted = !homeState._todos[index].isCompleted;
                                              }
                                            });
                                          },
                                          onDeleteTodo: (id) {
                                            homeState._deleteTodo(id);
                                          },
                                          onEditSubTask: (nestedSubTask) {
                                            homeState._openEditModal(nestedSubTask);
                                          },
                                          homeState: homeState,
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: Text(
                                  subTask.title,
                                  style: DSTypo.body.copyWith(
                                    decoration: subTask.isCompleted ? TextDecoration.lineThrough : null,
                                    color: subTask.isCompleted ? mutedColor : bodyColor,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Colors.red),
                              onPressed: () {
                                debugPrint('🟢 [EditTodoModal] Suppression de sous-tâche: ${subTask.title} (ID: ${subTask.id})');
                                setState(() {
                                  if (originalIndex != -1) {
                                    _subTasks.removeAt(originalIndex);
                                  }
                                  final mainIndex = widget.homeState._todos.indexWhere((t) => t.id == subTask.id);
                                  if (mainIndex != -1) {
                                    widget.homeState._todos.removeAt(mainIndex);
                                    widget.homeState._saveData();
                                  }
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      );
                    },
                      );
                    },
                  ),
                ],
                const SizedBox(height: 32),
              ] else ...[
                const Text(
                  'Niveau maximum de sous-tâches atteint.',
                  style: TextStyle(color: DSColor.danger),
                ),
                const SizedBox(height: 24),
              ],
              
              // Temps passé
              Row(
                children: [
                  const Icon(Icons.timelapse, size: 18, color: DSColor.body),
                  const SizedBox(width: 8),
                  Text('Temps passé : ${_formatElapsedTime(widget.todo.elapsedSeconds)}', style: DSTypo.body),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20, color: DSColor.muted),
                    tooltip: 'Réinitialiser le temps',
                    onPressed: () {
                      setState(() {
                        widget.todo.elapsedSeconds = 0;
                        if (TimerService().isTaskRunning(widget.todo.id)) {
                          TimerService().pauseTimer();
                        }
                      });
                      widget.homeState._saveData();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Actions
              Row(
                children: [
                  Expanded(
                    child: DSButton.danger(
                      label: 'Supprimer',
                      onPressed: () async {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Supprimer la tâche'),
                            content: const Text('Êtes-vous sûr de vouloir supprimer cette tâche et toutes ses sous-tâches ?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Annuler'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  widget.homeState._deleteTodo(widget.todo.id);
                                  widget.homeState.setState(() {});
                                  Navigator.pop(context);
                                  Navigator.pop(context);
                                },
                                style: TextButton.styleFrom(foregroundColor: DSColor.danger),
                                child: const Text('Supprimer'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DSButton(
                      label: 'Marquer comme terminée',
                      onPressed: () {
                        debugPrint('🔵 [EditTodoModal] Bouton "Marquer comme terminée" cliqué');
                        void markCompleted(int id) {
                          final index = widget.homeState._todos.indexWhere((t) => t.id == id);
                          if (index != -1) {
                            widget.homeState._todos[index].isCompleted = true;
                          }
                          final subTasks = widget.homeState._getVisibleSubTasks(id);
                          for (final sub in subTasks) {
                            markCompleted(sub.id);
                          }
                        }
                        markCompleted(widget.todo.id);
                        widget.homeState._saveData();
                        widget.homeState.setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tâche et sous-tâches marquées comme terminées')),
                        );
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
              ],
              ),
            ),
          );
        },
      ),
      ),
    );
  }

  // Méthode pour sauvegarder automatiquement les modifications
  Future<void> _saveChanges() async {
    if (_titleController.text.trim().isEmpty) {
      debugPrint('❌ _saveChanges(): Titre vide, sauvegarde annulée');
      return; // Ne pas sauvegarder si le titre est vide
    }
    
    if (_titleController.text.length > 200) {
      debugPrint('❌ _saveChanges(): Titre trop long (${_titleController.text.length} caractères), sauvegarde annulée');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le titre ne peut pas dépasser 200 caractères')),
      );
      return; // Ne pas sauvegarder si le titre est trop long
    }
    
    // Validation des paramètres de récurrence
    if (_selectedRecurrenceType != RecurrenceType.none) {
      if (_selectedRecurrenceTime == null) {
        debugPrint('❌ _saveChanges(): Heure de récurrence manquante, sauvegarde annulée');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez spécifier une heure de récurrence')),
        );
        return;
      }
      
      if (_selectedRecurrenceType == RecurrenceType.weekly && _selectedRecurrenceDayOfWeek == null) {
        debugPrint('❌ _saveChanges(): Jour de la semaine manquant, sauvegarde annulée');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez spécifier un jour de la semaine')),
        );
        return;
      }
      
      if (_selectedRecurrenceType == RecurrenceType.monthly && _selectedRecurrenceDayOfMonth == null) {
        debugPrint('❌ _saveChanges(): Jour du mois manquant, sauvegarde annulée');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez spécifier un jour du mois')),
        );
        return;
      }
    }
    
    int? estimatedMinutes;
    if (_estimatedTimeController.text.trim().isNotEmpty) {
      try {
        estimatedMinutes = int.parse(_estimatedTimeController.text.trim());
        if (estimatedMinutes <= 0) {
          debugPrint('❌ _saveChanges(): Temps estimé invalide, sauvegarde annulée');
          return; // Ne pas sauvegarder si le temps estimé n'est pas valide
        }
      } catch (e) {
        debugPrint('❌ _saveChanges(): Erreur parsing temps estimé, sauvegarde annulée');
        return; // Ne pas sauvegarder si le temps estimé n'est pas un nombre valide
      }
    }
    
    final updatedTodo = TodoItem(
      id: widget.todo.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      dueDate: _selectedDate,
      priority: _selectedPriority,
      projectId: _selectedProject?.id, // Permettre null pour les tâches sans projet
      isCompleted: widget.todo.isCompleted,
      parentId: widget.todo.parentId,
      level: widget.todo.level,
      reminder: _selectedReminder,
      estimatedMinutes: estimatedMinutes,
      elapsedMinutes: widget.todo.elapsedMinutes,
      elapsedSeconds: widget.todo.elapsedSeconds,
      recurrenceType: _selectedRecurrenceType,
      recurrenceDayOfWeek: _selectedRecurrenceDayOfWeek,
      recurrenceDayOfMonth: _selectedRecurrenceDayOfMonth,
      recurrenceTime: _selectedRecurrenceTime,
    );
    
    debugPrint('🔄 _saveChanges(): Mise à jour de la tâche "${updatedTodo.title}"');
    debugPrint('🔄 _saveChanges(): Sous-tâches dans le modal: ${_subTasks.length}');
    
    // Mettre à jour la tâche dans la liste
    final index = widget.homeState._todos.indexWhere((t) => t.id == widget.todo.id);
    if (index != -1) {
      widget.homeState._todos[index] = updatedTodo;
      
      // S'assurer que toutes les sous-tâches sont dans la liste principale
      for (final subTask in _subTasks) {
        final subTaskIndex = widget.homeState._todos.indexWhere((t) => t.id == subTask.id);
        if (subTaskIndex == -1) {
          // Sous-tâche pas encore dans la liste principale, l'ajouter
          widget.homeState._todos.add(subTask);
          debugPrint('🔄 _saveChanges(): Sous-tâche "${subTask.title}" ajoutée à la liste principale');
        } else {
          // Mettre à jour la sous-tâche existante
          widget.homeState._todos[subTaskIndex] = subTask;
          debugPrint('🔄 _saveChanges(): Sous-tâche "${subTask.title}" mise à jour');
        }
      }
      
      // Sauvegarder et forcer le rafraîchissement
      widget.homeState._saveData().then((_) async {
        debugPrint('✅ _saveChanges(): Tâche et sous-tâches sauvegardées avec succès');
        
        // Forcer un rafraîchissement complet de la vue
        widget.homeState.setState(() {
          debugPrint('🔄 _saveChanges(): setState() appelé pour rafraîchir la vue');
        });
        
        // Forcer le rafraîchissement de la sidebar
        widget.homeState._refreshSidebarCounts();
        
        // Annuler l'ancienne notification avant d'en programmer une nouvelle
        await NotificationService.cancelTaskNotification(updatedTodo.id);
        
        // Reprogrammer la notification si nécessaire
        if (updatedTodo.reminder != null && updatedTodo.reminder!.isAfter(DateTime.now())) {
          NotificationService.scheduleTaskReminder(
            taskId: updatedTodo.id,
            title: updatedTodo.title,
            body: updatedTodo.description.isNotEmpty ? updatedTodo.description : 'Rappel de tâche',
            scheduledDate: updatedTodo.reminder!,
          ).then((_) {
            debugPrint('✅ _saveChanges(): Notification reprogrammée pour "${updatedTodo.title}"');
          }).catchError((e) {
            debugPrint('❌ _saveChanges(): Erreur reprogrammation notification: $e');
          });
        }
        
        // Programmer les rappels de récurrence si la tâche est récurrente
        if (updatedTodo.isRecurring && updatedTodo.recurrenceTime != null) {
          final nextOccurrence = updatedTodo.getNextOccurrence();
          if (nextOccurrence != null && nextOccurrence.isAfter(DateTime.now())) {
            NotificationService.scheduleTaskReminder(
              taskId: updatedTodo.id,
              title: updatedTodo.title,
              body: 'Tâche récurrente: ${updatedTodo.recurrenceText}',
              scheduledDate: nextOccurrence,
            ).then((_) {
              debugPrint('✅ _saveChanges(): Rappel de récurrence programmé pour "${updatedTodo.title}" à ${nextOccurrence}');
            }).catchError((e) {
              debugPrint('❌ _saveChanges(): Erreur programmation rappel de récurrence: $e');
            });
          }
        }
        
        // Reprogrammer les notifications pour les sous-tâches
        for (final subTask in _subTasks) {
          // Annuler l'ancienne notification avant d'en programmer une nouvelle
          await NotificationService.cancelTaskNotification(subTask.id);
          
          if (subTask.reminder != null && subTask.reminder!.isAfter(DateTime.now())) {
            NotificationService.scheduleTaskReminder(
              taskId: subTask.id,
              title: subTask.title,
              body: subTask.description.isNotEmpty ? subTask.description : 'Rappel de sous-tâche',
              scheduledDate: subTask.reminder!,
            ).then((_) {
              debugPrint('✅ _saveChanges(): Notification reprogrammée pour sous-tâche "${subTask.title}"');
            }).catchError((e) {
              debugPrint('❌ _saveChanges(): Erreur reprogrammation notification sous-tâche: $e');
            });
          }
        }
      }).catchError((e) {
        debugPrint('❌ _saveChanges(): Erreur lors de la sauvegarde: $e');
      });
    } else {
      debugPrint('❌ _saveChanges(): Tâche non trouvée dans la liste');
    }
  }

  @override
  void dispose() {
    debugPrint('🔄 [EditTodoModal] dispose() appelé - Sauvegarde automatique...');
    
    // Sauvegarder automatiquement les modifications avant de fermer
    _saveChanges();
    
    debugPrint('🔄 [EditTodoModal] Nettoyage des contrôleurs...');
    _titleController.dispose();
    _descriptionController.dispose();
    _estimatedTimeController.dispose();
    _subTaskController.dispose();
    
    debugPrint('✅ [EditTodoModal] dispose() terminé');
    super.dispose();
  }
}

class AddProjectDialog extends StatefulWidget {
  @override
  State<AddProjectDialog> createState() => _AddProjectDialogState();
}

class _AddProjectDialogState extends State<AddProjectDialog> {
  final TextEditingController _nameController = TextEditingController();
  Color _selectedColor = Colors.blue;
  
  final List<Color> _availableColors = [
    Colors.blue, Colors.green, Colors.purple, Colors.orange,
    Colors.red, Colors.pink, Colors.indigo, Colors.teal,
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: DSColor.surfaceSoft,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Nouveau Projet', style: DSTypo.h1Of(context)),
                  IconButton(
                    icon: const Icon(Icons.close, color: DSColor.heading),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              DSTextField(
                label: 'Nom du projet',
                controller: _nameController,
                hint: 'Ex: Personnel, Travail...',
                onChanged: (val) => setState(() {}),
              ),
              const SizedBox(height: 16),
              
              Text('Couleur', style: DSTypo.body.copyWith(fontWeight: FontWeight.w600, color: DSColor.heading)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _availableColors.map((color) {
                  final isSelected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: isSelected 
                        ? const Icon(Icons.check, color: Colors.white, size: 24)
                        : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              
              DSButton(
                label: 'Créer le projet',
                onPressed: _nameController.text.trim().isNotEmpty
                  ? () {
                      final newProject = Project(
                        id: DateTime.now().millisecondsSinceEpoch,
                        name: _nameController.text.trim(),
                        color: _selectedColor,
                      );
                      Navigator.pop(context, newProject);
                    }
                  : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditProjectDialog extends StatefulWidget {
  final Project project;
  final Function(Project) onProjectUpdated;
  
  const EditProjectDialog({
    super.key,
    required this.project,
    required this.onProjectUpdated,
  });

  @override
  State<EditProjectDialog> createState() => _EditProjectDialogState();
}

class _EditProjectDialogState extends State<EditProjectDialog> {
  late final TextEditingController _nameController;
  late Color _selectedColor;
  
  final List<Color> _availableColors = [
    Colors.blue, Colors.green, Colors.purple, Colors.orange,
    Colors.red, Colors.pink, Colors.indigo, Colors.teal,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project.name);
    _selectedColor = widget.project.color;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: DSColor.surfaceSoft,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Modifier le Projet', style: DSTypo.h1Of(context)),
                  IconButton(
                    icon: const Icon(Icons.close, color: DSColor.heading),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              DSTextField(
                label: 'Nom du projet',
                controller: _nameController,
                onChanged: (val) => setState(() {}),
              ),
              const SizedBox(height: 16),
              
              Text('Couleur', style: DSTypo.body.copyWith(fontWeight: FontWeight.w600, color: DSColor.heading)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _availableColors.map((color) {
                  final isSelected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: isSelected 
                        ? const Icon(Icons.check, color: Colors.white, size: 24)
                        : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              
              DSButton(
                label: 'Enregistrer',
                onPressed: _nameController.text.trim().isNotEmpty
                  ? () async {
                      try {
                        final localStorageService = LocalStorageService();
                        final updatedProject = await localStorageService.updateProject(
                          widget.project.id,
                          {
                            'name': _nameController.text.trim(),
                            'color': _selectedColor,
                          },
                        );
                        
                        if (updatedProject != null) {
                          widget.onProjectUpdated(updatedProject);
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur: $e')),
                        );
                      }
                    }
                  : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String getPriorityText(Priority priority) {
  switch (priority) {
    case Priority.low:
      return 'Basse';
    case Priority.medium:
      return 'Moyenne';
    case Priority.high:
      return 'Haute';
  }
}

String _formatElapsedTime(int totalSeconds) {
  final min = totalSeconds ~/ 60;
  final sec = totalSeconds % 60;
  if (min == 0) return '${sec}s';
  if (sec == 0) return '${min}min';
  return '${min}min ${sec}s';
}

class SettingsScreen extends StatefulWidget {
  final Function(String, bool) onThemeChanged;
  final Function(ThemeData) onThemeChangedLegacy;
  final Function() onSettingsChanged;
  final Function() onDataReload;
  final bool autoThemeMode;
  final Function(bool) onAutoThemeModeChanged;
  
  const SettingsScreen({
    super.key, 
    required this.onThemeChanged,
    required this.onThemeChangedLegacy,
    required this.onSettingsChanged,
    required this.onDataReload,
    this.autoThemeMode = false,
    required this.onAutoThemeModeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showDescriptions = false;
  bool _showCompletedTasksInProjects = false;
  bool _shoppingListEnabled = false;
  String _selectedColor = 'blue';
  bool _isDarkMode = false;
  String _openAiApiKeys = '';
  final TextEditingController _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadThemePreferences();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final preferencesService = PreferencesService();
    setState(() {
      _showDescriptions = prefs.getBool('show_descriptions') ?? false;
      _showCompletedTasksInProjects = prefs.getBool('show_completed_tasks') ?? false;
      _shoppingListEnabled = preferencesService.shoppingListEnabled;
      _openAiApiKeys = prefs.getString('openai_api_keys') ?? '';
      _apiKeyController.text = _openAiApiKeys;
    });
    debugPrint('📋 [SettingsScreen] Préférences chargées: show_descriptions = $_showDescriptions, show_completed_tasks = $_showCompletedTasksInProjects, shopping_list_enabled = $_shoppingListEnabled');
  }

  Future<void> _loadThemePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedColor = prefs.getString('selected_color') ?? 'blue';
      _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    });
  }

  Future<void> _saveShowDescriptions(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_descriptions', value);
    setState(() {
      _showDescriptions = value;
    });
    widget.onSettingsChanged();
  }

  Future<void> _saveShowCompletedTasks(bool value) async {
    debugPrint('🔧 [SettingsScreen] Sauvegarde show_completed_tasks: $value');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_completed_tasks', value);
    setState(() {
      _showCompletedTasksInProjects = value;
    });
    debugPrint('✅ [SettingsScreen] Préférence sauvegardée: show_completed_tasks = $value');
    widget.onSettingsChanged();
    
    // Forcer la mise à jour de la variable dans la classe principale
    widget.onDataReload();
    
    // Forcer la mise à jour de l'interface
    widget.onSettingsChanged();
  }

  Future<void> _saveShoppingListEnabled(bool value) async {
    debugPrint('🔧 [SettingsScreen] Sauvegarde shopping_list_enabled: $value');
    final preferencesService = PreferencesService();
    await preferencesService.setShoppingListEnabled(value);
    setState(() {
      _shoppingListEnabled = value;
    });
    
    // Si activé, créer le projet "courses"
    if (value) {
      final projectService = ProjectService();
      try {
        await projectService.getOrCreateShoppingListProject();
        debugPrint('✅ [SettingsScreen] Projet "courses" créé');
      } catch (e) {
        debugPrint('⚠️ [SettingsScreen] Erreur lors de la création du projet courses: $e');
      }
    }
    
    debugPrint('✅ [SettingsScreen] Préférence sauvegardée: shopping_list_enabled = $value');
    widget.onSettingsChanged();
    widget.onDataReload();
  }

  Future<void> _saveOpenAiApiKeys(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('openai_api_keys', value);
    setState(() {
      _openAiApiKeys = value;
    });
    widget.onSettingsChanged();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }



      void _deleteProjectFromSettings(Project project) {
        // Tous les projets peuvent être supprimés
        _deleteProject(project);
      }

      void _deleteProject(Project project) async {
        debugPrint('🔄 _deleteProject(): Début de la suppression du projet: ${project.name} (ID: ${project.id})');

        // Compter les tâches dans ce projet
        final localStorageService = LocalStorageService();
        final projectTodos = localStorageService.getTodosByProject(project.id);
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Supprimer le projet'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Êtes-vous sûr de vouloir supprimer le projet "${project.name}" ?',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (projectTodos.isNotEmpty) ...[
                  Text(
                    'Ce projet contient ${projectTodos.length} tâche${projectTodos.length > 1 ? 's' : ''}.',
                    style: const TextStyle(color: Colors.orange),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Toutes les tâches seront supprimées définitivement.',
                    style: TextStyle(color: Colors.red),
                  ),
                ] else ...[
                  const Text(
                    'Ce projet ne contient aucune tâche.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    final success = await localStorageService.deleteProject(project.id);
                    
                    if (success) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Projet "${project.name}" supprimé avec succès'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      // Recharger les données
                      widget.onDataReload();
                    } else {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Erreur lors de la suppression du projet'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erreur lors de la suppression: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        );
      }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final brightness = Theme.of(context).brightness;
    final surfaceSoftColor = DSColor.getSurfaceSoft(brightness);
    final surfaceColor = DSColor.getSurface(brightness);
    final headingColor = DSColor.getHeading(brightness);
    final mutedColor = DSColor.getMuted(brightness);
    
    return Container(
      padding: EdgeInsets.only(
        bottom: bottomPadding + 16, // Padding pour la barre de navigation Android
      ),
      decoration: BoxDecoration(
        color: surfaceSoftColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: mutedColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Paramètres', style: DSTypo.h1Of(context)),
                  IconButton(
                    icon: Icon(Icons.close, color: headingColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Section Thème
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: DSRadius.round,
                      boxShadow: DSShadow.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.palette, color: DSColor.primary, size: 24),
                            const SizedBox(width: 12),
                            Text('Thème', style: DSTypo.h2Of(context)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Section Couleurs
                        Text(
                          'Couleur des éléments',
                          style: DSTypo.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: headingColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildColorOptionSettings('Bleu', 'blue', const Color(0xFF2563EB)),
                            _buildColorOptionSettings('Vert', 'green', const Color(0xFF059669)),
                            _buildColorOptionSettings('Violet', 'purple', const Color(0xFF7C3AED)),
                            _buildColorOptionSettings('Orange', 'orange', const Color(0xFFEA580C)),
                            _buildColorOptionSettings('Rose', 'pink', const Color(0xFFEC4899)),
                            _buildColorOptionSettings('Teal', 'teal', const Color(0xFF0D9488)),
                            _buildColorOptionSettings('Indigo', 'indigo', const Color(0xFF4F46E5)),
                            _buildColorOptionSettings('Rouge', 'red', const Color(0xFFDC2626)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Section Mode
                        Text(
                          'Mode d\'affichage',
                          style: DSTypo.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: headingColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildModeOptionSettings('Clair', false, Icons.wb_sunny),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildModeOptionSettings('Sombre', true, Icons.nightlight_round),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildModeOptionSettings('Auto', null, Icons.brightness_auto),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Builder(
                          builder: (context) {
                            final brightness = Theme.of(context).brightness;
                            final bodyColor = DSColor.getBody(brightness);
                            final mutedColor = DSColor.getMuted(brightness);
                            
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: DSColor.getSurfaceSoft(brightness),
                                borderRadius: DSRadius.soft,
                                border: Border.all(
                                  color: widget.autoThemeMode ? DSColor.primary.withOpacity(0.3) : mutedColor.withOpacity(0.2),
                                  width: widget.autoThemeMode ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: widget.autoThemeMode ? DSColor.primary : mutedColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.autoThemeMode
                                          ? 'Mode automatique activé (21h-8h = sombre)'
                                          : 'Mode automatique désactivé',
                                      style: DSTypo.caption.copyWith(
                                        color: widget.autoThemeMode ? bodyColor : mutedColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Section Reconnaissance vocale
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: DSRadius.round,
                      boxShadow: DSShadow.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.mic, color: DSColor.primary, size: 24),
                            const SizedBox(width: 12),
                            Text('Reconnaissance vocale', style: DSTypo.h2Of(context)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Configurez l\'ajout de tâches par la voix via OpenAI Whisper et GPT',
                          style: DSTypo.body.copyWith(color: mutedColor),
                        ),
                        const SizedBox(height: 16),
                        DSTextField(
                          label: 'Clés API OpenAI',
                          controller: _apiKeyController,
                          hint: 'clé1, clé2, ...',
                          helperText: 'Entrez une ou plusieurs clés API OpenAI séparées par des virgules',
                          onChanged: _saveOpenAiApiKeys,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Section Affichage
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: DSRadius.round,
                      boxShadow: DSShadow.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.visibility, color: DSColor.primary, size: 24),
                            const SizedBox(width: 12),
                            Text('Affichage', style: DSTypo.h2Of(context)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: surfaceSoftColor,
                            borderRadius: DSRadius.soft,
                          ),
                          child: SwitchListTile(
                            title: Text('Afficher les descriptions', style: DSTypo.bodyOf(context)),
                            subtitle: Text(
                              'Afficher les descriptions des tâches dans la liste principale',
                              style: DSTypo.caption.copyWith(color: mutedColor),
                            ),
                            value: _showDescriptions,
                            onChanged: _saveShowDescriptions,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            activeColor: DSColor.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: surfaceSoftColor,
                            borderRadius: DSRadius.soft,
                          ),
                          child: SwitchListTile(
                            title: Text('Afficher les tâches terminées', style: DSTypo.bodyOf(context)),
                            subtitle: Text(
                              'Afficher les tâches terminées dans tous les projets',
                              style: DSTypo.caption.copyWith(color: mutedColor),
                            ),
                            value: _showCompletedTasksInProjects,
                            onChanged: _saveShowCompletedTasks,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            activeColor: DSColor.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: surfaceSoftColor,
                            borderRadius: DSRadius.soft,
                          ),
                          child: SwitchListTile(
                            title: Text('Activer la liste de courses', style: DSTypo.bodyOf(context)),
                            subtitle: Text(
                              'Afficher l\'élément "Courses" dans le menu latéral',
                              style: DSTypo.caption.copyWith(color: mutedColor),
                            ),
                            value: _shoppingListEnabled,
                            onChanged: _saveShoppingListEnabled,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            activeColor: DSColor.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Bouton Démo Design System
                        SizedBox(
                          width: double.infinity,
                          child: DSButton.secondary(
                            label: 'Voir la démo UI',
                            icon: Icons.design_services,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const DesignSystemDemoScreen()),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Section Données
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: DSRadius.round,
                      boxShadow: DSShadow.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.storage, color: DSColor.primary, size: 24),
                            const SizedBox(width: 12),
                            Text('Données', style: DSTypo.h2Of(context)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Sauvegardez ou restaurez toutes vos données (tâches, projets, préférences)',
                          style: DSTypo.body.copyWith(color: mutedColor),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: DSButton(
                                label: 'Sauvegarder',
                                icon: Icons.download,
                                onPressed: () async {
                                  try {
                                    // Afficher un indicateur de chargement
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );

                                    final exportService = DataExportImportService();
                                    final data = exportService.exportAllData();
                                    
                                    final fileService = FileService();
                                    final savedPath = await fileService.saveDataToFile(data);
                                    
                                    // Fermer l'indicateur de chargement
                                    Navigator.of(context).pop();
                                    
                                    if (savedPath != null) {
                                      debugPrint('✅ Export réussi: \\${data.length} clés -> \\${savedPath}');
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Sauvegarde réussie !\\nFichier: \\${savedPath.split('/').last}'),
                                          backgroundColor: Colors.green,
                                          duration: const Duration(seconds: 4),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Sauvegarde annulée'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    // Fermer l'indicateur de chargement en cas d'erreur
                                    if (Navigator.canPop(context)) {
                                      Navigator.of(context).pop();
                                    }
                                    debugPrint('❌ Erreur export: \\${e}');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Erreur lors de la sauvegarde: \\${e}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DSButton(
                                label: 'Restaurer',
                                icon: Icons.upload,
                                backgroundColor: DSColor.getSurfaceTint(brightness),
                                textColor: DSColor.primary,
                                onPressed: () async {
                                  BuildContext? dialogContext;
                                  try {
                                    debugPrint('🔄 Début de la restauration...');
                                    
                                    // Afficher un indicateur de chargement
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) {
                                        dialogContext = context;
                                        return const Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              CircularProgressIndicator(),
                                              SizedBox(height: 16),
                                              Text('Chargement du fichier...'),
                                            ],
                                          ),
                                        );
                                      },
                                    );

                                    debugPrint('📂 Sélection du fichier...');
                                    final fileService = FileService();
                                    final data = await fileService.loadDataFromFile();
                                    
                                    // Mettre à jour le dialog
                                    if (dialogContext != null && Navigator.canPop(dialogContext!)) {
                                      Navigator.of(dialogContext!).pop();
                                    }
                                    
                                    if (data == null) {
                                      debugPrint('⚠️ Aucun fichier sélectionné');
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Import annulé - Aucun fichier sélectionné'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }

                                    debugPrint('✅ Fichier chargé: ${data.keys.length} clés trouvées');
                                    
                                    // Afficher un nouveau dialog pour l'import
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) {
                                        dialogContext = context;
                                        return const Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              CircularProgressIndicator(),
                                              SizedBox(height: 16),
                                              Text('Import des données...'),
                                            ],
                                          ),
                                        );
                                      },
                                    );

                                    try {
                                      // Vérifier que le fichier est valide
                                      debugPrint('🔍 Validation du fichier...');
                                      if (!fileService.isValidBackupFile(data)) {
                                        if (dialogContext != null && Navigator.canPop(dialogContext!)) {
                                          Navigator.of(dialogContext!).pop();
                                        }
                                        debugPrint('❌ Fichier invalide. Clés: ${data.keys.toList()}');
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Fichier invalide.\\nClés trouvées: ${data.keys.take(5).join(", ")}...'),
                                            backgroundColor: Colors.red,
                                            duration: const Duration(seconds: 5),
                                          ),
                                        );
                                        return;
                                      }

                                      debugPrint('✅ Fichier valide, début de l\'import...');
                                      final exportService = DataExportImportService();
                                      await exportService.importAllData(data);
                                      
                                      debugPrint('✅ Import terminé avec succès');
                                      
                                      // Fermer le dialog
                                      if (dialogContext != null && Navigator.canPop(dialogContext!)) {
                                        Navigator.of(dialogContext!).pop();
                                      }
                                      
                                      // Forcer le rechargement des données
                                      debugPrint('🔄 Rechargement des données...');
                                      final localStorageService = LocalStorageService();
                                      await localStorageService.reloadData();
                                      
                                      // Recharger les données dans l'interface
                                      widget.onDataReload();
                                      
                                      debugPrint('✅ Données rechargées');
                                      
                                      // Afficher un message de succès avec les statistiques
                                      final stats = localStorageService.getDataStats();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Row(
                                                children: [
                                                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Restauration réussie !',
                                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${stats['todos']} tâches • ${stats['projects']} projets importés',
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: Colors.green,
                                          duration: const Duration(seconds: 5),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      
                                      // Rafraîchir l'interface
                                      widget.onSettingsChanged();
                                    } catch (e, stackTrace) {
                                      debugPrint('❌ Erreur lors de l\'import: $e');
                                      debugPrint('❌ Type: ${e.runtimeType}');
                                      debugPrint('❌ Stack trace: $stackTrace');
                                      
                                      // Fermer le dialog
                                      if (dialogContext != null && Navigator.canPop(dialogContext!)) {
                                        Navigator.of(dialogContext!).pop();
                                      }
                                      
                                        final errorMessage = e.toString();
                                        final displayMessage = errorMessage.length > 100 
                                            ? '${errorMessage.substring(0, 100)}...' 
                                            : errorMessage;
                                        
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('❌ Erreur lors de la restauration:\\n$displayMessage'),
                                            backgroundColor: Colors.red,
                                            duration: const Duration(seconds: 8),
                                          ),
                                        );
                                    }
                                  } catch (e, stackTrace) {
                                    debugPrint('❌ Erreur générale lors de la restauration: $e');
                                    debugPrint('❌ Stack trace: $stackTrace');
                                    
                                    // Fermer le dialog si ouvert
                                    if (dialogContext != null && Navigator.canPop(dialogContext!)) {
                                      Navigator.of(dialogContext!).pop();
                                    }
                                    
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('❌ Erreur: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 6),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DSButton.danger(
                          label: 'Supprimer toutes les données',
                          icon: Icons.delete_forever,
                          onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Confirmer la suppression'),
                                      content: const Text('Êtes-vous sûr de vouloir supprimer TOUTES les données ? Cette action est irréversible.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          child: const Text('Annuler'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () => Navigator.of(context).pop(true),
                                          child: const Text('Supprimer'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    try {
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (context) => const Center(child: CircularProgressIndicator()),
                                      );
                                      await DataExportImportService().clearAllData();
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Toutes les données ont été supprimées.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      widget.onSettingsChanged();
                                    } catch (e) {
                                      if (Navigator.canPop(context)) Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Erreur lors de la suppression: \\${e}'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOptionSettings(String name, String colorName, Color color) {
    final isSelected = _selectedColor == colorName;
    final brightness = Theme.of(context).brightness;
    
    return InkWell(
      onTap: () {
        widget.onThemeChanged(colorName, _isDarkMode);
        setState(() {
          _selectedColor = colorName;
        });
      },
      borderRadius: DSRadius.soft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : DSColor.getSurfaceSoft(brightness),
          borderRadius: DSRadius.soft,
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected ? Border.all(color: DSColor.primary, width: 2) : null,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: DSTypo.caption.copyWith(
                color: isSelected ? DSColor.getHeading(brightness) : DSColor.getBody(brightness),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOptionSettings(String name, bool? isDark, IconData icon) {
    final brightness = Theme.of(context).brightness;
    final isSelected = isDark == null 
        ? widget.autoThemeMode 
        : (!widget.autoThemeMode && _isDarkMode == isDark);
    
    return InkWell(
      onTap: () {
        if (isDark == null) {
          // Mode automatique
          widget.onAutoThemeModeChanged(!widget.autoThemeMode);
        } else {
          // Mode manuel (clair ou sombre)
          widget.onAutoThemeModeChanged(false);
          widget.onThemeChanged(_selectedColor, isDark);
          setState(() {
            _isDarkMode = isDark;
          });
        }
      },
      borderRadius: DSRadius.soft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? DSColor.primary.withOpacity(0.15) : DSColor.getSurfaceSoft(brightness),
          borderRadius: DSRadius.soft,
          border: Border.all(
            color: isSelected ? DSColor.primary : DSColor.getMuted(brightness).withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? DSColor.primary : DSColor.getMuted(brightness),
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: DSTypo.caption.copyWith(
                color: isSelected ? DSColor.getHeading(brightness) : DSColor.getBody(brightness),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(String name, ThemeData theme, Color color) {
    return InkWell(
      onTap: () {
        widget.onThemeChangedLegacy(theme);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Text(
          name,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.3,
          ),
        ),
      ).animate().scale(
        duration: 150.ms,
        curve: Curves.easeOutCubic,
      ),
    );
  }
}
