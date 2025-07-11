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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser le service de stockage local
  final localStorageService = LocalStorageService();
  await localStorageService.initialize();
  
  // Initialiser le service de notifications
  await NotificationService.initialize();
  
  // Vérifier l'état des permissions
  await NotificationService.checkPermissions();
  
  runApp(const TodoApp());
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
    return MaterialApp(
      title: 'Todo App',
      theme: _currentTheme,
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
  List<Project> _projects = [
    Project(
      id: 1,
      name: 'Personnel',
      color: Colors.blue,
      isDefault: true,
    ),
  ];
  List<TodoItem> _todos = [];
  Project? _selectedProject;
  SortType _currentSort = SortType.dateAdded;
  bool _isSidebarOpen = false;
  bool _showDescriptions = false;
  bool _showCompletedTasks = false;
  
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
        if (_projects.isNotEmpty) {
          _selectedProject = _projects.first;
        }
      });
      debugPrint('✅ _loadData(): ${_projects.length} projets chargés');

      // Charger les tâches (créer une copie modifiable)
      setState(() {
        _todos = List<TodoItem>.from(localStorageService.todos);
      });
      debugPrint('✅ _loadData(): ${_todos.length} tâches chargées');

      // Reprogrammer les notifications pour les tâches avec rappel
      await _rescheduleNotifications();
      
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
      });
      debugPrint('✅ Paramètres chargés: show_descriptions = $_showDescriptions');
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
      debugPrint('✅ Paramètres sauvegardés: show_descriptions = $_showDescriptions');
    } catch (e) {
      debugPrint('❌ Erreur lors de la sauvegarde des paramètres: $e');
    }
  }

  // Reprogrammer les notifications pour toutes les tâches avec rappel
  Future<void> _rescheduleNotifications() async {
    try {
      for (final todo in _todos) {
        if (todo.reminder != null && todo.reminder!.isAfter(DateTime.now())) {
          await NotificationService.scheduleTaskReminder(
            taskId: todo.id,
            title: todo.title,
            body: todo.description.isNotEmpty ? todo.description : 'Rappel de tâche',
            scheduledDate: todo.reminder!,
          );
        }
      }
      
      debugPrint('✅ Rappels reprogrammés pour ${_todos.where((t) => t.reminder != null && t.reminder!.isAfter(DateTime.now())).length} tâches');
    } catch (e) {
      debugPrint('❌ Erreur lors de la reprogrammation des rappels: $e');
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
      
      debugPrint('✅ _saveData(): Données sauvegardées avec succès');
      debugPrint('✅ _saveData(): ${_projects.length} projets, ${_todos.length} tâches');
    } catch (e) {
      debugPrint('❌ _saveData(): Erreur lors de la sauvegarde: $e');
    }
  }

  void _addTodo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddTodoModal(projects: _projects),
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
      }
    });
  }

  void _openEditModal(TodoItem todo) {
    debugPrint('🟢 [_openEditModal] Ouverture du modal pour: ${todo.title} (niveau ${todo.level})');
    final subTasks = _getSubTasks(todo.id);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EditTodoModal(
        todo: todo,
        projects: _projects,
        subTasks: subTasks,
        onAddSubTask: (subTask) {
          setState(() {
            _todos.add(subTask);
          });
        },
        onToggleSubTask: (id) {
          setState(() {
            final index = _todos.indexWhere((t) => t.id == id);
            if (index != -1) {
              _todos[index].isCompleted = !_todos[index].isCompleted;
            }
          });
        },
        onDeleteTodo: (id) {
          _deleteTodo(id);
        },
        onEditSubTask: (subTask) {
          // Fonction récursive pour ouvrir le modal d'édition de n'importe quelle tâche
          _openEditModal(subTask);
        },
      ),
    ).then((result) async {
      if (result != null && result['todo'] != null) {
        setState(() {
          final index = _todos.indexWhere((t) => t.id == todo.id);
          if (index != -1) {
            _todos[index] = result['todo'] as TodoItem;
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
    });
  }

  void _editTodo(TodoItem todo) {
    _openEditModal(todo);
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

  void _deleteProject(Project project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le projet'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer le projet "${project.name}" ? '
          'Toutes les tâches associées seront également supprimées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              setState(() {
                _projects.remove(project);
                _todos.removeWhere((todo) => todo.projectId == project.id);
                if (_selectedProject?.id == project.id) {
                  _selectedProject = _projects.isNotEmpty ? _projects.first : null;
                }
              });
              
              // Sauvegarder les données
              await _saveData();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
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
    setState(() {
      final todo = _todos.firstWhere((todo) => todo.id == id);
      todo.isCompleted = !todo.isCompleted;
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
  
  // Méthode pour construire un élément de sous-tâche indenté
  Widget _buildSubTaskItem(TodoItem subTask, int parentId) {
    final hasNestedSubTasks = _hasSubTasks(subTask.id);
    final isExpanded = _expandedTasks.contains(subTask.id);
    final nestedSubTasks = isExpanded ? _getSubTasks(subTask.id) : [];
    
    return Column(
      children: [
        Card(
          margin: EdgeInsets.only(
            left: 32.0 * subTask.level, // Indentation basée sur le niveau
            right: 16.0,
            top: 2.0,
            bottom: 2.0,
          ),
          child: InkWell(
            onTap: () => _editTodo(subTask),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              leading: Checkbox(
                value: subTask.isCompleted,
                onChanged: (_) => _toggleTodo(subTask.id),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          subTask.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            decoration: subTask.isCompleted ? TextDecoration.lineThrough : null,
                            color: subTask.isCompleted ? Colors.grey : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (subTask.dueDate != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          '${subTask.dueDate!.day}/${subTask.dueDate!.month}/${subTask.dueDate!.year}',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                        ),
                      ],
                      if (subTask.reminder != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.alarm, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          '${subTask.reminder!.day}/${subTask.reminder!.month}/${subTask.reminder!.year} à ${subTask.reminder!.hour.toString().padLeft(2, '0')}:${subTask.reminder!.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                        ),
                      ],
                    ],
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
                              '${_getSubTasks(subTask.id).length} sous-tâches',
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
        // Afficher les sous-tâches imbriquées si la tâche est dépliée
        if (isExpanded && nestedSubTasks.isNotEmpty)
          ...nestedSubTasks.map((nestedSubTask) => _buildSubTaskItem(nestedSubTask, subTask.id)),
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
      builder: (context) => SettingsScreen(
        onThemeChanged: widget.onThemeChanged,
        onThemeChangedLegacy: widget.onThemeChangedLegacy,
        onSettingsChanged: () {
          _loadSettings();
          _loadData();
        },
        onDataReload: _loadData,
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
    
    if (_showCompletedTasks) {
      // Afficher seulement les tâches achevées
      filtered = _todos.where((todo) => todo.isCompleted && todo.isRootTask).toList();
    } else if (_selectedProject == null) {
      // Afficher toutes les tâches non achevées
      filtered = _todos.where((todo) => !todo.isCompleted && todo.isRootTask).toList();
    } else {
      // Afficher les tâches du projet sélectionné (non achevées)
      filtered = _todos.where((todo) => todo.projectId == _selectedProject!.id && !todo.isCompleted && todo.isRootTask).toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        automaticallyImplyLeading: true,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.folder,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Projets',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.list),
              title: Text('Toutes les tâches'),
              selected: _selectedProject == null && !_showCompletedTasks,
              onTap: () {
                setState(() {
                  _selectedProject = null;
                  _showCompletedTasks = false;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.check_circle),
              title: Text('Tâches achevées'),
              selected: _showCompletedTasks,
              onTap: () {
                setState(() {
                  _showCompletedTasks = true;
                });
                Navigator.pop(context);
              },
            ),
            Divider(),
            ..._projects.map((project) => ListTile(
              leading: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: project.color,
                  shape: BoxShape.circle,
                ),
              ),
              title: Text(project.name),
              subtitle: Text('${_todos.where((todo) => todo.projectId == project.id).length} tâches'),
              selected: _selectedProject?.id == project.id,
              onTap: () {
                setState(() {
                  _selectedProject = project;
                });
                Navigator.pop(context);
              },
            )),
            Divider(),
            ListTile(
              leading: Icon(Icons.add),
              title: Text('Nouveau projet'),
              onTap: () {
                Navigator.pop(context);
                _addProject();
              },
            ),
            Spacer(),
            Divider(),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Paramètres'),
              onTap: () {
                Navigator.pop(context);
                _showSettings();
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Contrôles de tri
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sort, size: 16),
                      const SizedBox(width: 6),
                      Text(_getSortDisplayName()),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.sort),
                  onPressed: _showSortDialog,
                ),
                const Spacer(),
                Text('${_filteredTodos.length} tâches'),
              ],
            ),
          ),
          // Liste des tâches
          Expanded(
            child: _filteredTodos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.task_alt, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _selectedProject != null
                              ? 'Aucune tâche dans "${_selectedProject!.name}"'
                              : 'Aucune tâche pour le moment',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredTodos.length,
                    itemBuilder: (context, index) {
                      final todo = _filteredTodos[index];
                      final isOverdue = todo.dueDate != null && 
                          todo.dueDate!.isBefore(DateTime.now()) && 
                          !todo.isCompleted;
                      
                      final hasSubTasks = _hasSubTasks(todo.id);
                      final isExpanded = _expandedTasks.contains(todo.id);
                      final subTasks = isExpanded ? _getSubTasks(todo.id) : [];
                      
                      return Column(
                        children: [
                          Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              leading: Checkbox(
                                value: todo.isCompleted,
                                onChanged: (_) => _toggleTodo(todo.id),
                              ),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          todo.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                                            color: todo.isCompleted ? Colors.grey : Theme.of(context).textTheme.bodyLarge?.color,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (todo.dueDate != null) ...[
                                        const SizedBox(width: 8),
                                        Icon(Icons.calendar_today, size: 14),
                                        const SizedBox(width: 2),
                                        Text(
                                          '${todo.dueDate!.day}/${todo.dueDate!.month}/${todo.dueDate!.year}',
                                          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                                        ),
                                      ],
                                      if (todo.reminder != null) ...[
                                        const SizedBox(width: 8),
                                        Icon(Icons.alarm, size: 14),
                                        const SizedBox(width: 2),
                                        Text(
                                          '${todo.reminder!.day}/${todo.reminder!.month}/${todo.reminder!.year} à ${todo.reminder!.hour.toString().padLeft(2, '0')}:${todo.reminder!.minute.toString().padLeft(2, '0')}',
                                          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Description (si activée dans les paramètres)
                                    if (_showDescriptions && todo.description.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          todo.description,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: todo.isCompleted ? Colors.grey : Theme.of(context).hintColor,
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
                                        if (todo.estimatedMinutes != null)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.timer, size: 15),
                                              const SizedBox(width: 2),
                                              Text('Estimé : ${todo.estimatedTimeText}', style: const TextStyle(fontSize: 12)),
                                            ],
                                          ),
                                        ...(TimerService().isTaskRunning(todo.id)
                                          ? [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.play_circle, size: 15, color: Colors.green),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    _formatElapsedTime(todo.elapsedSeconds + TimerService().elapsedSeconds),
                                                    style: const TextStyle(fontSize: 13, color: Colors.green),
                                                  ),
                                                ],
                                              )
                                            ]
                                          : todo.elapsedSeconds > 0
                                            ? [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.timelapse, size: 15),
                                                    const SizedBox(width: 2),
                                                    Text('Passé : ${_formatElapsedTime(todo.elapsedSeconds)}', style: const TextStyle(fontSize: 12)),
                                                  ],
                                                )
                                              ]
                                            : []),
                                        if (hasSubTasks)
                                          Container(
                                            margin: const EdgeInsets.only(left: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${_getSubTasks(todo.id).length} sous-tâches',
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
                                    icon: Icon(TimerService().isTaskRunning(todo.id) ? Icons.pause : Icons.play_arrow),
                                    tooltip: TimerService().isTaskRunning(todo.id)
                                        ? 'Mettre en pause le suivi du temps'
                                        : 'Démarrer le suivi du temps',
                                    onPressed: () => _handlePlayPause(todo),
                                  ),
                                  if (hasSubTasks)
                                    IconButton(
                                      icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                                      onPressed: () {
                                        setState(() {
                                          if (isExpanded) {
                                            _expandedTasks.remove(todo.id);
                                          } else {
                                            _expandedTasks.add(todo.id);
                                          }
                                        });
                                      },
                                    ),
                                ],
                              ),
                              onTap: () => _editTodo(todo),
                            ),
                          ),
                          if (isExpanded && subTasks.isNotEmpty)
                            ...subTasks.map((subTask) => _buildSubTaskItem(subTask, todo.id)),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTodo,
        child: const Icon(Icons.add),
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
            ],
          ),
        ),
      ),
    );
  }
}

class AddTodoModal extends StatefulWidget {
  final List<Project> projects;
  
  const AddTodoModal({super.key, required this.projects});

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
    _selectedProject = widget.projects.isNotEmpty ? widget.projects.first : null;
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Nouvelle Tâche',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Projet
              DropdownButtonFormField<Project?>(
                value: _selectedProject,
                decoration: const InputDecoration(
                  labelText: 'Projet (optionnel)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<Project?>(
                    value: null,
                    child: Row(
                      children: [
                        Icon(Icons.folder_off, color: Colors.grey),
                        SizedBox(width: 8),
                        Text('Aucun projet'),
                      ],
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
                          Text(project.name),
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
              const SizedBox(height: 16),
              // Titre
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre de la tâche *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Description
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Date d'échéance
              TextField(
                readOnly: true,
                controller: TextEditingController(
                  text: _selectedDate != null
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : '',
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _selectedDate = date;
                    });
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Date d\'échéance (optionnel)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: _selectedDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _selectedDate = null;
                            });
                          },
                        )
                      : null,
                ),
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              // Rappel
              TextField(
                readOnly: true,
                controller: TextEditingController(
                  text: _selectedReminder != null
                      ? '${_selectedReminder!.day}/${_selectedReminder!.month}/${_selectedReminder!.year} à ${_selectedReminder!.hour.toString().padLeft(2, '0')}:${_selectedReminder!.minute.toString().padLeft(2, '0')}'
                      : '',
                ),
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
                decoration: InputDecoration(
                  labelText: 'Rappel (optionnel)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.alarm),
                  suffixIcon: _selectedReminder != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _selectedReminder = null;
                            });
                          },
                        )
                      : null,
                ),
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              // Priorité
              DropdownButtonFormField<Priority>(
                value: _selectedPriority,
                decoration: const InputDecoration(
                  labelText: 'Priorité',
                  border: OutlineInputBorder(),
                ),
                items: Priority.values.map((priority) {
                  return DropdownMenuItem(
                    value: priority,
                      child: Text(getPriorityText(priority)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPriority = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              // Temps estimé
              TextField(
                controller: _estimatedTimeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Temps estimé (en minutes, optionnel)',
                  border: OutlineInputBorder(),
                  hintText: 'Ex: 30 pour 30 minutes, 90 pour 1h30',
                  prefixIcon: Icon(Icons.timer),
                ),
              ),
              const SizedBox(height: 24),
                // Section Sous-tâches
                const Text(
                  'Sous-tâches (optionnel)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _subTaskController,
                        decoration: const InputDecoration(
                          labelText: 'Ajouter une sous-tâche',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addSubTask,
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_subTasks.isEmpty)
                  const Text('Aucune sous-tâche ajoutée.'),
                if (_subTasks.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _subTasks.length,
                    itemBuilder: (context, index) {
                      final subTask = _subTasks[index];
                      return ListTile(
                        leading: const Icon(Icons.subdirectory_arrow_right),
                        title: Text(subTask.title),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _subTasks.removeAt(index);
                            });
                          },
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),
              // Boutons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                        onPressed: _titleController.text.trim().isEmpty
                            ? null
                            : () {
                                // Parser le temps estimé
                                int? estimatedMinutes;
                                if (_estimatedTimeController.text.trim().isNotEmpty) {
                                  try {
                                    estimatedMinutes = int.parse(_estimatedTimeController.text.trim());
                                    if (estimatedMinutes <= 0) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Le temps estimé doit être un nombre positif')),
                                      );
                                      return;
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Veuillez entrer un nombre valide pour le temps estimé')),
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
                                  parentId: null, // Tâche racine
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
                        child: const Text('Ajouter'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
  
  const EditTodoModal({
    super.key, 
    required this.todo,
    required this.projects,
    required this.subTasks,
    required this.onAddSubTask,
    required this.onToggleSubTask,
    required this.onDeleteTodo,
    this.onEditSubTask,
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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo.title);
    _descriptionController = TextEditingController(text: widget.todo.description);
    _estimatedTimeController = TextEditingController(text: widget.todo.estimatedMinutes?.toString() ?? '');
    _selectedDate = widget.todo.dueDate;
    _selectedReminder = widget.todo.reminder;
    _selectedPriority = widget.todo.priority;
    _selectedProject = widget.projects.firstWhere(
      (project) => project.id == widget.todo.projectId,
      orElse: () => widget.projects.first,
    );
    _subTasks = widget.subTasks;
  }

  void _addSubTask() {
    if (_subTaskController.text.trim().isNotEmpty) {
      try {
        final subTask = widget.todo.createSubTask(
          title: _subTaskController.text.trim(),
          description: '',
          estimatedMinutes: null,
        );
        widget.onAddSubTask(subTask);
        _subTaskController.clear();
        setState(() {
          _subTasks = List.from(_subTasks)..add(subTask);
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Modifier la Tâche',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Projet
              DropdownButtonFormField<Project?>(
                value: _selectedProject,
                decoration: const InputDecoration(
                  labelText: 'Projet (optionnel)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<Project?>(
                    value: null,
                    child: Row(
                      children: [
                        Icon(Icons.folder_off, color: Colors.grey),
                        SizedBox(width: 8),
                        Text('Aucun projet'),
                      ],
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
                          Text(project.name),
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
              const SizedBox(height: 16),
              
              // Titre
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre de la tâche *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              // Description
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              // Date d'échéance
              TextField(
                readOnly: true,
                controller: TextEditingController(
                  text: _selectedDate != null
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : '',
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _selectedDate = date;
                    });
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Date d\'échéance (optionnel)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: _selectedDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _selectedDate = null;
                            });
                          },
                        )
                      : null,
                ),
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              // Rappel
              TextField(
                readOnly: true,
                controller: TextEditingController(
                  text: _selectedReminder != null
                      ? '${_selectedReminder!.day}/${_selectedReminder!.month}/${_selectedReminder!.year} à ${_selectedReminder!.hour.toString().padLeft(2, '0')}:${_selectedReminder!.minute.toString().padLeft(2, '0')}'
                      : '',
                ),
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
                decoration: InputDecoration(
                  labelText: 'Rappel (optionnel)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.alarm),
                  suffixIcon: _selectedReminder != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _selectedReminder = null;
                            });
                          },
                        )
                      : null,
                ),
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              // Priorité
              DropdownButtonFormField<Priority>(
                value: _selectedPriority,
                decoration: const InputDecoration(
                  labelText: 'Priorité',
                  border: OutlineInputBorder(),
                ),
                items: Priority.values.map((priority) {
                  return DropdownMenuItem(
                    value: priority,
                      child: Text(getPriorityText(priority)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPriority = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              // Temps estimé
              TextField(
                controller: _estimatedTimeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Temps estimé (en minutes, optionnel)',
                  border: OutlineInputBorder(),
                  hintText: 'Ex: 30 pour 30 minutes, 90 pour 1h30',
                  prefixIcon: Icon(Icons.timer),
                ),
              ),
              const SizedBox(height: 24),
                // Section Sous-tâches
                if (widget.todo.canHaveSubTasks) ...[
                  const Text(
                    'Sous-tâches',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _subTaskController,
                          decoration: const InputDecoration(
                            labelText: 'Ajouter une sous-tâche',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addSubTask,
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_subTasks.isEmpty)
                    const Text('Aucune sous-tâche.'),
                  if (_subTasks.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _subTasks.length,
                      itemBuilder: (context, index) {
                        final subTask = _subTasks[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          child: InkWell(
                            onTap: () {
                              debugPrint('🟢 [EditTodoModal] Clic sur sous-tâche: ${subTask.title} (ID: ${subTask.id})');
                              // Utiliser le callback si disponible, sinon essayer de trouver le homeState
                              if (widget.onEditSubTask != null) {
                                debugPrint('🟢 [EditTodoModal] Utilisation du callback onEditSubTask');
                                widget.onEditSubTask!(subTask);
                              } else {
                                debugPrint('🟢 [EditTodoModal] Tentative de récupération du homeState');
                                final homeState = context.findAncestorStateOfType<_TodoHomePageState>();
                                debugPrint('🟢 [EditTodoModal] homeState trouvé: ${homeState != null}');
                                if (homeState != null) {
                                  final subTasks = homeState._getSubTasks(subTask.id);
                                  debugPrint('🟢 [EditTodoModal] Sous-tâches trouvées: ${subTasks.length}');
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (context) => EditTodoModal(
                                      todo: subTask,
                                      projects: homeState._projects,
                                      subTasks: subTasks,
                                      onAddSubTask: (newSubTask) {
                                        debugPrint('🟢 [EditTodoModal] Ajout de sous-tâche: ${newSubTask.title}');
                                        homeState.setState(() {
                                          homeState._todos.add(newSubTask);
                                        });
                                      },
                                      onToggleSubTask: (id) {
                                        debugPrint('🟢 [EditTodoModal] Toggle sous-tâche: $id');
                                        homeState.setState(() {
                                          final index = homeState._todos.indexWhere((t) => t.id == id);
                                          if (index != -1) {
                                            homeState._todos[index].isCompleted = !homeState._todos[index].isCompleted;
                                          }
                                        });
                                      },
                                      onDeleteTodo: (id) {
                                        debugPrint('🟢 [EditTodoModal] Suppression de tâche: $id');
                                        homeState._deleteTodo(id);
                                      },
                                      onEditSubTask: (nestedSubTask) {
                                        // Appeler la même fonction récursive
                                        homeState._openEditModal(nestedSubTask);
                                      },
                                    ),
                                  );
                                  debugPrint('🟢 [EditTodoModal] Modal ouvert pour sous-tâche');
                                } else {
                                  debugPrint('🔴 [EditTodoModal] ERREUR: homeState non trouvé!');
                                }
                              }
                            },
                            child: ListTile(
                              leading: const Icon(Icons.subdirectory_arrow_right),
                              title: Text(
                                subTask.title,
                                style: TextStyle(
                                  decoration: subTask.isCompleted ? TextDecoration.lineThrough : null,
                                  color: subTask.isCompleted ? Colors.grey : null,
                                ),
                              ),
                              subtitle: subTask.description.isNotEmpty
                                  ? Text(
                                      subTask.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: subTask.isCompleted ? Colors.grey : Theme.of(context).hintColor,
                                      ),
                                    )
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (subTask.dueDate != null)
                                    Icon(Icons.calendar_today, size: 16, color: Theme.of(context).hintColor),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      debugPrint('🟢 [EditTodoModal] Suppression de sous-tâche: ${subTask.title}');
                                      setState(() {
                                        _subTasks.removeAt(index);
                                      });
                                    },
                                    tooltip: 'Supprimer cette sous-tâche',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                ] else ...[
                  const Text(
                    'Niveau maximum de sous-tâches atteint.',
                    style: TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 24),
                ],
              // Temps passé
              Row(
                children: [
                  const Icon(Icons.timelapse, size: 16),
                  const SizedBox(width: 4),
                  Text('Temps passé : ${_formatElapsedTime(widget.todo.elapsedSeconds)}', style: const TextStyle(fontSize: 14)),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: 'Réinitialiser le temps',
                    onPressed: () {
                      setState(() {
                        widget.todo.elapsedSeconds = 0;
                        if (TimerService().isTaskRunning(widget.todo.id)) {
                          TimerService().pauseTimer();
                        }
                      });
                      // Sauvegarder la tâche réinitialisée
                      final homeState = context.findAncestorStateOfType<_TodoHomePageState>();
                      if (homeState != null) {
                        homeState._saveData();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Boutons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                        onPressed: () {
                          if (_titleController.text.trim().isEmpty || _selectedProject == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Veuillez entrer un titre et sélectionner un projet')),
                            );
                            return;
                          }
                          int? estimatedMinutes;
                          if (_estimatedTimeController.text.trim().isNotEmpty) {
                            try {
                              estimatedMinutes = int.parse(_estimatedTimeController.text.trim());
                              if (estimatedMinutes <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Le temps estimé doit être un nombre positif')),
                                );
                                return;
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Veuillez entrer un nombre valide pour le temps estimé')),
                              );
                              return;
                            }
                          }
                          final updatedTodo = TodoItem(
                            id: widget.todo.id,
                            title: _titleController.text.trim(),
                            description: _descriptionController.text.trim(),
                            dueDate: _selectedDate,
                            priority: _selectedPriority,
                            projectId: _selectedProject!.id,
                            isCompleted: widget.todo.isCompleted,
                            parentId: widget.todo.parentId,
                            level: widget.todo.level,
                            reminder: _selectedReminder,
                            estimatedMinutes: estimatedMinutes,
                            elapsedMinutes: widget.todo.elapsedMinutes,
                            elapsedSeconds: widget.todo.elapsedSeconds,
                          );
                          Navigator.pop(context, {'todo': updatedTodo});
                            },
                      child: const Text('Sauvegarder'),
                    ),
                  ),
                ],
                ),
                const SizedBox(height: 24),
                // Bouton de suppression
                OutlinedButton.icon(
                  onPressed: () {
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
                            onPressed: () {
                              debugPrint('🗑️ Bouton suppression cliqué pour la tâche ${widget.todo.id}');
                              widget.onDeleteTodo(widget.todo.id);
                              Navigator.pop(context); // Fermer la boîte de dialogue
                              Navigator.pop(context); // Fermer la modale d'édition
                            },
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Supprimer'),
                          ),
                        ],
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  icon: const Icon(Icons.delete),
                  label: const Text('Supprimer cette tâche'),
                ),
              ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _estimatedTimeController.dispose();
    _subTaskController.dispose();
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
  bool _isNameValid = false;

  final List<Color> _availableColors = [
    Colors.blue,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.red,
    Colors.pink,
    Colors.indigo,
    Colors.teal,
  ];

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    setState(() {
      _isNameValid = _nameController.text.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau Projet'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom du projet',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Couleur du projet'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _availableColors.map((color) {
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedColor = color;
                  });
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _selectedColor == color ? Colors.black : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isNameValid
              ? () {
                  final newProject = Project(
                    id: DateTime.now().millisecondsSinceEpoch,
                    name: _nameController.text.trim(),
                    color: _selectedColor,
                    isDefault: false,
                  );
                  Navigator.pop(context, newProject);
                }
              : null,
          child: const Text('Créer'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
  String _selectedColor = 'blue';
  bool _isDarkMode = false;

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
    });
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

  @override
  Widget build(BuildContext context) {
    return Container(
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
              'Paramètres',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Section Thème
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.palette, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Text(
                            'Thème',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Section Couleurs
                      Text(
                        'Couleur des éléments',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
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
                      const SizedBox(height: 16),
                      // Section Mode
                      Text(
                        'Mode d\'affichage',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
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
                // Section Affichage
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.visibility, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Text(
                            'Affichage',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: Text('Afficher les descriptions'),
                        subtitle: Text('Afficher les descriptions des tâches dans la liste principale'),
                        value: _showDescriptions,
                        onChanged: _saveShowDescriptions,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Section Données
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.storage, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Text(
                            'Données',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sauvegardez ou restaurez toutes vos données (tâches, projets, préférences)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
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
                              icon: const Icon(Icons.download),
                              label: const Text('Sauvegarder'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
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
                              icon: const Icon(Icons.upload),
                              label: const Text('Restaurer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.secondary,
                                foregroundColor: Theme.of(context).colorScheme.onSecondary,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
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
                              icon: const Icon(Icons.delete_forever, color: Colors.red),
                              label: const Text('Supprimer toutes les données'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red, width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildColorOptionSettings(String name, String colorName, Color color) {
    final isSelected = _selectedColor == colorName;
    
    return InkWell(
      onTap: () {
        widget.onThemeChanged(colorName, _isDarkMode);
        setState(() {
          _selectedColor = colorName;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
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

  Widget _buildModeOptionSettings(String name, bool isDark, IconData icon) {
    final isSelected = _isDarkMode == isDark;
    
    return InkWell(
      onTap: () {
        widget.onThemeChanged(_selectedColor, isDark);
        setState(() {
          _isDarkMode = isDark;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected 
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              name,
              style: TextStyle(
                color: isSelected 
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
                fontWeight: FontWeight.w600,
                fontSize: 10,
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
