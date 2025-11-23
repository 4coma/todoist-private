import 'package:flutter/material.dart';
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
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'screens/design_system_demo.dart';
import 'design_system/tokens.dart';
import 'design_system/widgets.dart';
import 'design_system/forms.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser le service de stockage local
  final localStorageService = LocalStorageService();
  await localStorageService.initialize();
  
  // Initialiser le service de notifications
  await NotificationService.initialize();
  
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

  @override
  void initState() {
    super.initState();
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedColor = prefs.getString('selected_color') ?? 'blue';
      final isDarkMode = prefs.getBool('is_dark_mode') ?? false;
      
      setState(() {
        _selectedColor = selectedColor;
        _isDarkMode = isDarkMode;
        _currentTheme = AppThemes.getTheme(selectedColor, isDarkMode);
      });
      debugPrint('✅ Thème chargé: couleur=$selectedColor, dark=$isDarkMode');
    } catch (e) {
      debugPrint('❌ Erreur lors du chargement du thème: $e');
    }
  }

  void _changeTheme(String colorName, bool isDarkMode) async {
    setState(() {
      _selectedColor = colorName;
      _isDarkMode = isDarkMode;
      _currentTheme = AppThemes.getTheme(colorName, isDarkMode);
    });
    
    // Sauvegarder les préférences de thème
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_color', colorName);
      await prefs.setBool('is_dark_mode', isDarkMode);
      debugPrint('✅ Thème sauvegardé: couleur=$colorName, dark=$isDarkMode');
    } catch (e) {
      debugPrint('❌ Erreur lors de la sauvegarde du thème: $e');
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
      home: TodoHomePage(
        onThemeChanged: _changeTheme,
        onThemeChangedLegacy: _changeThemeLegacy,
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

class TodoHomePage extends StatefulWidget {
  final Function(String, bool) onThemeChanged;
  final Function(ThemeData) onThemeChangedLegacy;
  
  const TodoHomePage({
    super.key, 
    required this.onThemeChanged,
    required this.onThemeChangedLegacy,
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
  bool _isSidebarOpen = false;
  bool _showDescriptions = false;
  bool _showCompletedTasks = false; // Mode "Tâches achevées" (sidebar)
  bool _showCompletedTasksInProjects = false; // Option "Afficher les tâches terminées" (paramètres)

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
      setState(() {
        _showDescriptions = prefs.getBool('show_descriptions') ?? false;
        _showCompletedTasksInProjects = prefs.getBool('show_completed_tasks') ?? false;
        _openAiApiKeys = prefs.getString('openai_api_keys') ?? '';
      });
      debugPrint('✅ Paramètres chargés: show_descriptions = $_showDescriptions, show_completed_tasks_in_projects = $_showCompletedTasksInProjects, openai_keys_présents = ${_openAiApiKeys.isNotEmpty}');
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
      
      // Annuler toutes les notifications existantes
      await NotificationService.cancelAllReminders();
      debugPrint('🔄 _rescheduleNotifications(): Anciennes notifications annulées');
      
      // Reprogrammer les notifications pour les tâches avec rappel
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
      
      debugPrint('✅ _rescheduleNotifications(): $scheduledCount notifications reprogrammées avec succès');
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

  void _addTodo() {
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
        projects: _projects,
        selectedProject: _selectedProject, // Passer le projet sélectionné
        ),
      ),
    ).then((result) async {
      if (result != null && result['todo'] != null) {
        final newTodo = result['todo'] as TodoItem;
        final subTasks = result['subTasks'] as List<TodoItem>? ?? [];
        
        setState(() {
          _todos.add(newTodo);
          
          // Ajouter les sous-tâches avec le bon parentId
          for (final subTask in subTasks) {
            final updatedSubTask = TodoItem(
              id: subTask.id,
              title: subTask.title,
              description: subTask.description,
              dueDate: subTask.dueDate,
              priority: subTask.priority,
              projectId: subTask.projectId,
              isCompleted: subTask.isCompleted,
              parentId: newTodo.id, // Lier à la tâche parente
              level: subTask.level,
              reminder: subTask.reminder,
              estimatedMinutes: subTask.estimatedMinutes,
              elapsedMinutes: subTask.elapsedMinutes,
              elapsedSeconds: subTask.elapsedSeconds,
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
    });
  }

  Future<String?> _recordAudio() async {
    final recorder = AudioRecorder();
    if (!await recorder.hasPermission()) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) return null;
    }
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/todo_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await recorder.start(RecordConfig(encoder: AudioEncoder.aacLc), path: filePath);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: const AlertDialog(
          content: Text('Enregistrement en cours...\nTapez pour terminer'),
        ),
      ),
    );
    final path = await recorder.stop();
    await recorder.dispose();
    return path;
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

  Future<Map<String, dynamic>?> _extractTodoFromText(
      String text, String apiKey) async {
    final prompt = '''
Tu es un assistant qui transforme un texte en une tâche structurée.
Réponds uniquement avec un objet JSON {"title": "...", "description": "..."}.
Si l'utilisateur indique explicitement "titre" et "description", garde ces valeurs telles quelles.
Sinon, reformule au besoin pour proposer un titre concis et une description détaillée.
Texte: $text
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
    final transcription = await _transcribeAudio(path, apiKey);
    if (transcription == null) return;

    final todoMap = await _extractTodoFromText(transcription, apiKey);
    if (todoMap == null) return;

    final newTodo = TodoItem(
      id: DateTime.now().millisecondsSinceEpoch,
      title: todoMap['title'] ?? 'Sans titre',
      description: todoMap['description'] ?? '',
      priority: Priority.medium,
      projectId: _selectedProject?.id,
      isCompleted: false,
    );

    setState(() {
      _todos.add(newTodo);
    });
    await _saveData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tâche "${newTodo.title}" ajoutée'),
          duration: const Duration(seconds: 2),
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
        // Planifier la nouvelle notification si besoin
        if (updatedTodo.reminder != null) {
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
      builder: (context) => AlertDialog(
        title: const Text('Trier les tâches'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSortOption(SortType.dueDate, 'Date d\'échéance', Icons.schedule),
            _buildSortOption(SortType.name, 'Nom', Icons.sort_by_alpha),
            _buildSortOption(SortType.dateAdded, 'Date d\'ajout', Icons.add_circle),
            _buildSortOption(SortType.priority, 'Priorité', Icons.priority_high),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(SortType sortType, String title, IconData icon) {
    final isSelected = _currentSort == sortType;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Theme.of(context).primaryColor : null,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
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
    
    // Si on marque comme terminée, ajouter les effets spéciaux
    if (isNowCompleted) {
      // Afficher le toast avec bouton d'annulation
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        final snackBar = SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tâche "${todo.title}" marquée comme terminée',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          action: SnackBarAction(
            label: 'Annuler',
            textColor: Colors.white,
            onPressed: () {
              // Annuler l'action
              setState(() {
                todo.isCompleted = false;
              });
              _saveData();
              
              // Afficher un toast de confirmation d'annulation
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(
                        Icons.undo,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Action annulée pour "${todo.title}"',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
          ),
        );
        
        scaffoldMessenger.showSnackBar(snackBar);
      }
    }
    
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

      // Remonter toutes les sous-tâches et mettre à jour leur parentId
      for (final sub in _getAllSubTasks(taskId)) {
        final idx = _todos.indexWhere((t) => t.id == sub.id);
        if (idx != -1) {
          // Si la sous-tâche avait cette tâche comme parent, elle devient racine
          if (sub.parentId == taskId) {
            _todos[idx] = sub.copyWith(parentId: null, level: sub.level - levelDiff);
            debugPrint('✅ Sous-tâche ${sub.title} devient racine (parentId = null)');
          } else {
            // Sinon, juste ajuster le niveau
            _todos[idx] = sub.copyWith(level: sub.level - levelDiff);
            debugPrint('✅ Sous-tâche ${sub.title} niveau ajusté: ${sub.level} -> ${sub.level - levelDiff}');
          }
        }
      }
    });

    debugPrint('🔍 === FIN REMONTÉE ===');
    _saveData();
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

  List<TodoItem> get _filteredTodos {
    List<TodoItem> filtered;
    
    debugPrint('🔍 [FILTRAGE] _showCompletedTasksInProjects = $_showCompletedTasksInProjects');
    debugPrint('🔍 [FILTRAGE] _showCompletedTasks = $_showCompletedTasks');
    debugPrint('🔍 [FILTRAGE] _selectedProject = ${_selectedProject?.name ?? "null"}');
    
    if (_showCompletedTasks) {
      // Mode "Tâches achevées" - afficher seulement les tâches terminées
      filtered = _todos.where((todo) => todo.isCompleted && todo.isRootTask).toList();
      debugPrint('🔍 [FILTRAGE] Mode tâches achevées: ${filtered.length} tâches');
    } else if (_selectedProject == null) {
      // Vue "Toutes les tâches" - afficher les tâches non terminées (ou toutes si l'option est activée)
      filtered = _todos.where((todo) => (_showCompletedTasksInProjects || !todo.isCompleted) && todo.isRootTask).toList();
      debugPrint('🔍 [FILTRAGE] Vue toutes les tâches: ${filtered.length} tâches (showCompletedTasksInProjects: $_showCompletedTasksInProjects)');
    } else {
      // Vue projet spécifique - afficher les tâches du projet (non terminées ou toutes si l'option est activée)
      filtered = _todos.where((todo) => todo.projectId == _selectedProject!.id && (_showCompletedTasksInProjects || !todo.isCompleted) && todo.isRootTask).toList();
      debugPrint('🔍 [FILTRAGE] Vue projet ${_selectedProject!.name}: ${filtered.length} tâches (showCompletedTasksInProjects: $_showCompletedTasksInProjects)');
    }
    
    // Appliquer le tri
    switch (_currentSort) {
      case SortType.dueDate:
        filtered.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
        break;
      case SortType.name:
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortType.dateAdded:
        filtered.sort((a, b) => b.id.compareTo(a.id)); // Plus récent en premier
        break;
      case SortType.priority:
        filtered.sort((a, b) => _getPriorityValue(b.priority).compareTo(_getPriorityValue(a.priority)));
        break;
    }
    
    // Toujours placer les tâches terminées en bas
    filtered.sort((a, b) {
      if (a.isCompleted == b.isCompleted) return 0;
      return a.isCompleted ? 1 : -1; // Terminées en bas
    });
    
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
                    isSelected: _selectedProject == null && !_showCompletedTasks,
                    onTap: () {
                      setState(() {
                        _selectedProject = null;
                        _showCompletedTasks = false;
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
                  
                  ..._projects.map((project) {
                    final count = _todos.where((t) => t.projectId == project.id && !t.isCompleted).length;
                    return _buildDrawerItem(
                      icon: project.icon,
                      iconColor: project.color,
                      label: project.name,
                      count: count,
                      isSelected: _selectedProject?.id == project.id,
                      onTap: () {
                        setState(() => _selectedProject = project);
                        Navigator.pop(context);
                      },
                      onEdit: () => _editProject(project),
                      onDelete: () => _deleteProject(project),
                    );
                  }),
                  
                  Padding(
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
                          border: Border.all(color: DSColor.surfaceTint, width: 2),
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
                        IconButton(
                          icon: Icon(Icons.mic, color: headingColor),
                          onPressed: _addTodoByVoice,
                        ),
                      ],
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
                        Text('${_filteredTodos.length} tâches', style: DSTypo.caption.copyWith(color: mutedColor)),
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
            child: _filteredTodos.isEmpty
                ? Center(child: Builder(
                    builder: (context) => Text('Aucune tâche', style: DSTypo.bodyOf(context)),
                  ))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 100),
                    itemCount: _filteredTodos.length,
                    itemBuilder: (context, index) {
                      final todo = _filteredTodos[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildDSTaskItem(todo),
                          if (_expandedTasks.contains(todo.id))
                            ..._getVisibleSubTasks(todo.id).map((subTask) => 
                              Padding(
                                padding: const EdgeInsets.only(left: 32),
                                child: _buildDSTaskItem(subTask),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildDSTaskItem(TodoItem todo) {
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
    final project = _projects.firstWhere(
      (p) => p.id == todo.projectId,
      orElse: () => Project(id: -1, name: 'Général', color: Colors.grey, icon: Icons.list),
    );

    final hasSubTasks = _getVisibleSubTasks(todo.id).isNotEmpty;
    final isExpanded = _expandedTasks.contains(todo.id);

    return GestureDetector(
      onTap: () {
        if (hasSubTasks) {
          // Toggle expansion si la tâche a des sous-tâches
          setState(() {
            if (isExpanded) {
              _expandedTasks.remove(todo.id);
            } else {
              _expandedTasks.add(todo.id);
            }
          });
        } else {
          // Sinon, ouvrir le modal d'édition
          _editTodo(todo);
        }
      },
      onLongPress: () => _editTodo(todo), // Long press pour éditer même avec sous-tâches
      child: DSTaskCard(
        categoryIcon: project.icon,
        categoryColor: project.color,
        category: project.name,
        title: todo.title,
        time: todo.dueDate != null 
             ? "${todo.dueDate!.day}/${todo.dueDate!.month} ${todo.dueDate!.hour}:${todo.dueDate!.minute.toString().padLeft(2, '0')}"
             : "Pas de date",
        status: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasSubTasks)
              Icon(
                isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                size: 16,
                color: DSColor.muted,
              ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => _toggleTodo(todo.id),
              borderRadius: DSRadius.pill,
              child: statusWidget,
            ),
          ],
        ),
        isCompleted: todo.isCompleted,
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
  
  const AddTodoModal({
    super.key, 
    required this.projects,
    this.selectedProject, // Projet sélectionné par défaut
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
    // Utiliser le projet sélectionné par défaut, sinon le premier projet disponible
    _selectedProject = widget.selectedProject ?? (widget.projects.isNotEmpty ? widget.projects.first : null);
  }

  void _addSubTask() {
    if (_subTaskController.text.trim().isNotEmpty) {
      setState(() {
        final subTask = TodoItem(
          id: DateTime.now().millisecondsSinceEpoch + _subTasks.length, // ID unique
          title: _subTaskController.text.trim(),
          description: '',
          priority: Priority.medium,
          projectId: _selectedProject!.id,
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
                      color: Colors.black.withOpacity(0.03),
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
                maxLines: 3,
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
                                color: Colors.black.withOpacity(0.03),
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
    
    return Padding(
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
                      color: Colors.black.withOpacity(0.03),
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
                maxLines: 3,
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
                                color: Colors.black.withOpacity(0.03),
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
                  color: DSColor.surface,
                  borderRadius: DSRadius.soft,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
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
                              color: Colors.black.withOpacity(0.03),
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
                              color: Colors.black.withOpacity(0.03),
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
                          color: DSColor.surfaceSoft,
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
                                    color: subTask.isCompleted ? DSColor.muted : DSColor.body,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Colors.red),
                              onPressed: () {
                                debugPrint('🟢 [EditTodoModal] Suppression de sous-tâche: ${subTask.title} (ID: ${subTask.id})');
                                setState(() {
                                  _subTasks.removeAt(index);
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
    );
  }

  // Méthode pour sauvegarder automatiquement les modifications
  void _saveChanges() {
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
      widget.homeState._saveData().then((_) {
        debugPrint('✅ _saveChanges(): Tâche et sous-tâches sauvegardées avec succès');
        
        // Forcer un rafraîchissement complet de la vue
        widget.homeState.setState(() {
          debugPrint('🔄 _saveChanges(): setState() appelé pour rafraîchir la vue');
        });
        
        // Forcer le rafraîchissement de la sidebar
        widget.homeState._refreshSidebarCounts();
        
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
    
    // Forcer un rafraîchissement complet de la vue
    widget.homeState.setState(() {
      debugPrint('🔄 [EditTodoModal] setState() appelé dans dispose() pour rafraîchir la vue');
    });
    
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
  
  const SettingsScreen({
    super.key, 
    required this.onThemeChanged,
    required this.onThemeChangedLegacy,
    required this.onSettingsChanged,
    required this.onDataReload,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showDescriptions = false;
  bool _showCompletedTasksInProjects = false;
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
    setState(() {
      _showDescriptions = prefs.getBool('show_descriptions') ?? false;
      _showCompletedTasksInProjects = prefs.getBool('show_completed_tasks') ?? false;
      _openAiApiKeys = prefs.getString('openai_api_keys') ?? '';
      _apiKeyController.text = _openAiApiKeys;
    });
    debugPrint('📋 [SettingsScreen] Préférences chargées: show_descriptions = $_showDescriptions, show_completed_tasks = $_showCompletedTasksInProjects');
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
                          ],
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
                                  try {
                                    // Afficher un indicateur de chargement
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );

                                    final fileService = FileService();
                                    final data = await fileService.loadDataFromFile();
                                    
                                    // Fermer l'indicateur de chargement
                                    Navigator.of(context).pop();
                                    
                                    if (data != null) {
                                      // Vérifier que le fichier est valide
                                      if (!fileService.isValidBackupFile(data)) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Fichier invalide. Format de sauvegarde non reconnu.'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }

                                      final exportService = DataExportImportService();
                                      await exportService.importAllData(data);
                                      
                                      debugPrint('✅ Import réussi depuis fichier');
                                      
                                      // Forcer le rechargement des données dans main.dart
                                      final localStorageService = LocalStorageService();
                                      await localStorageService.reloadData();
                                      
                                      // Recharger les données dans l'interface
                                      widget.onDataReload();
                                      
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Restauration réussie !\\nDonnées importées avec succès'),
                                          backgroundColor: Colors.green,
                                          duration: const Duration(seconds: 4),
                                        ),
                                      );
                                      
                                      // Rafraîchir l'interface
                                      widget.onSettingsChanged();
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Import annulé'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    // Fermer l'indicateur de chargement en cas d'erreur
                                    if (Navigator.canPop(context)) {
                                      Navigator.of(context).pop();
                                    }
                                    debugPrint('❌ Erreur import: \\${e}');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Erreur lors de la restauration: \\${e}'),
                                        backgroundColor: Colors.red,
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

  Widget _buildModeOptionSettings(String name, bool isDark, IconData icon) {
    final isSelected = _isDarkMode == isDark;
    final brightness = Theme.of(context).brightness;
    
    return InkWell(
      onTap: () {
        widget.onThemeChanged(_selectedColor, isDark);
        setState(() {
          _isDarkMode = isDark;
        });
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
