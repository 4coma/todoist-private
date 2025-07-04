import 'package:flutter/material.dart';
import 'themes.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser le service de notifications
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  runApp(const TodoApp());
}

class TodoApp extends StatefulWidget {
  const TodoApp({super.key});

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  ThemeData _currentTheme = AppThemes.blueTheme;

  void _changeTheme(ThemeData theme) {
    setState(() {
      _currentTheme = theme;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo App',
      theme: _currentTheme,
      home: TodoHomePage(onThemeChanged: _changeTheme),
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
  final Function(ThemeData) onThemeChanged;
  
  const TodoHomePage({super.key, required this.onThemeChanged});

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

  // Set pour suivre les tâches dépliées (affichant leurs sous-tâches)
  final Set<int> _expandedTasks = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Charger les données sauvegardées
  Future<void> _loadData() async {
    try {
      // Charger les projets
      final savedProjects = await StorageService().loadProjects();
      if (savedProjects.isNotEmpty) {
        setState(() {
          _projects = savedProjects;
          _selectedProject = _projects.first;
        });
      } else {
        _selectedProject = _projects.first;
      }

      // Charger les tâches
      final savedTodos = await StorageService().loadTodos();
      setState(() {
        _todos = savedTodos;
      });

      // Reprogrammer les notifications pour les tâches avec rappel
      await _rescheduleNotifications();
      
      debugPrint('✅ Données chargées: ${_projects.length} projets, ${_todos.length} tâches');
    } catch (e) {
      debugPrint('❌ Erreur lors du chargement des données: $e');
    }
  }

  // Reprogrammer les notifications pour toutes les tâches avec rappel
  Future<void> _rescheduleNotifications() async {
    try {
      final notificationService = NotificationService();
      
      for (final todo in _todos) {
        if (todo.reminder != null && todo.reminder!.isAfter(DateTime.now())) {
          await notificationService.scheduleTaskReminder(
            taskId: todo.id,
            title: todo.title,
            body: todo.description.isNotEmpty ? todo.description : 'Rappel de tâche',
            scheduledDate: todo.reminder!,
          );
        }
      }
      
      debugPrint('✅ Notifications reprogrammées pour ${_todos.where((t) => t.reminder != null && t.reminder!.isAfter(DateTime.now())).length} tâches');
    } catch (e) {
      debugPrint('❌ Erreur lors de la reprogrammation des notifications: $e');
    }
  }

  // Méthode pour sauvegarder les données
  Future<void> _saveData() async {
    try {
      await StorageService().saveProjects(_projects);
      await StorageService().saveTodos(_todos);
    } catch (e) {
      debugPrint('❌ Erreur lors de la sauvegarde: $e');
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
            );
            _todos.add(updatedSubTask);
          }
        });
        
        // Sauvegarder les données
        await _saveData();
        // Planifier la notification pour la tâche principale
        if (newTodo.reminder != null) {
          await NotificationService().scheduleTaskReminder(
            taskId: newTodo.id,
            title: newTodo.title,
            body: newTodo.description.isNotEmpty ? newTodo.description : 'Rappel de tâche',
            scheduledDate: newTodo.reminder!,
          );
        }
        // Planifier les notifications pour les sous-tâches
        for (final subTask in subTasks) {
          if (subTask.reminder != null) {
            await NotificationService().scheduleTaskReminder(
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

  void _editTodo(TodoItem todo) {
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
        // Note: Les notifications sont maintenant gérées avec des IDs séparés
        // Pas besoin d'annuler explicitement car scheduleTaskReminder le fait automatiquement
        // Planifier la nouvelle notification si besoin
        if (updatedTodo.reminder != null) {
          await NotificationService().scheduleTaskReminder(
            taskId: updatedTodo.id,
            title: updatedTodo.title,
            body: updatedTodo.description.isNotEmpty ? updatedTodo.description : 'Rappel de tâche',
            scheduledDate: updatedTodo.reminder!,
          );
        }
      }
    });
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
    // Annuler les notifications de la tâche et de ses sous-tâches
    await NotificationService().cancelTaskNotification(id);
    
    // Récupérer toutes les sous-tâches pour annuler leurs notifications
    final subTasks = _getAllSubTasks(id);
    for (final subTask in subTasks) {
      await NotificationService().cancelTaskNotification(subTask.id);
    }
    
    setState(() {
      // Supprimer la tâche et toutes ses sous-tâches
      _todos.removeWhere((todo) => todo.id == id || todo.parentId == id);
    });
    
    // Sauvegarder les données
    await _saveData();
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
              leading: Checkbox(
                value: subTask.isCompleted,
                onChanged: (_) => _toggleTodo(subTask.id),
              ),
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
                    style: TextStyle(
                      color: subTask.isCompleted ? Colors.grey : null,
                    ),
                  )
                : null,
              trailing: hasNestedSubTasks ? IconButton(
                iconSize: 24,
                icon: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.purple,
                ),
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
              ) : null,
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
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choisir un thème',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildThemeOption('Bleu', AppThemes.blueTheme, Colors.blue),
                _buildThemeOption('Vert', AppThemes.greenTheme, Colors.green),
                _buildThemeOption('Violet', AppThemes.purpleTheme, Colors.purple),
                _buildThemeOption('Orange', AppThemes.orangeTheme, Colors.orange),
                _buildThemeOption('Sombre', AppThemes.darkTheme, Colors.grey.shade800),
                _buildThemeOption('Minimal', AppThemes.minimalTheme, Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(String name, ThemeData theme, Color color) {
    return InkWell(
      onTap: () {
        widget.onThemeChanged(theme);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          name,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
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
    if (_selectedProject == null) return _todos.where((todo) => todo.isRootTask).toList();
    var filtered = _todos.where((todo) => todo.projectId == _selectedProject!.id && todo.isRootTask).toList();
    
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Ma Liste de Tâches'),
        centerTitle: true,
        actions: [
          // Indicateur de tri actuel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sort,
                  size: 16,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  _getSortDisplayName(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Bouton de tri
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortDialog,
            tooltip: 'Trier les tâches',
          ),
          IconButton(
            icon: const Icon(Icons.palette),
            onPressed: _showThemeSelector,
            tooltip: 'Changer le thème',
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () async {
              // Vérifier d'abord les permissions
              await NotificationService().checkPermissions();
              
              // Envoyer la notification de test
              await NotificationService().showTestNotification();
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notification de test envoyée ! Vérifiez les logs pour les permissions.'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            tooltip: 'Tester les notifications',
          ),
          IconButton(
            icon: const Icon(Icons.schedule),
            onPressed: () async {
              final pendingNotifications = await NotificationService().getPendingNotifications();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${pendingNotifications.length} notification(s) en attente'),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            tooltip: 'Voir les notifications en attente',
          ),
          IconButton(
            icon: const Icon(Icons.timer),
            onPressed: () async {
              await NotificationService().scheduleTestNotification();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notification de test programmée pour dans 1 minute ! Vérifiez les logs.'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            tooltip: 'Tester notification programmée (10s)',
          ),
        ],
      ),
      body: Column(
        children: [
          // Sélecteur de projets
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _projects.length,
                    itemBuilder: (context, index) {
                      final project = _projects[index];
                      final isSelected = _selectedProject?.id == project.id;
                      final todoCount = _todos.where((todo) => todo.projectId == project.id).length;
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedProject = project;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? project.color.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? project.color : Colors.grey.shade300,
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
                                    color: project.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  project.name,
                                  style: TextStyle(
                                    color: isSelected ? project.color : Colors.grey.shade700,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected ? project.color : Colors.grey.shade400,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$todoCount',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addProject,
                  tooltip: 'Ajouter un projet',
                ),
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
                        Icon(
                          Icons.task_alt,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedProject != null
                              ? 'Aucune tâche dans "${_selectedProject!.name}"'
                              : 'Aucune tâche pour le moment',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        const Text(
                          'Ajoutez votre première tâche !',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
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
                      
                      // Vérifier si cette tâche a des sous-tâches
                      final hasSubTasks = _hasSubTasks(todo.id);
                      final isExpanded = _expandedTasks.contains(todo.id);
                      final subTasks = isExpanded ? _getSubTasks(todo.id) : [];
                      
                      return Column(
                        children: [
                          Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: InkWell(
                          onTap: () => _editTodo(todo),
                          child: ListTile(
                            leading: Checkbox(
                              value: todo.isCompleted,
                              onChanged: (_) => _toggleTodo(todo.id),
                            ),
                            title: Text(
                              todo.title,
                              style: TextStyle(
                                decoration: todo.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: todo.isCompleted
                                    ? Colors.grey
                                    : null,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (todo.description.isNotEmpty)
                                  Text(
                                    todo.description,
                                    style: TextStyle(
                                      color: todo.isCompleted ? Colors.grey : null,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (todo.dueDate != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isOverdue 
                                              ? Colors.red.withOpacity(0.1)
                                              : Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${todo.dueDate!.day}/${todo.dueDate!.month}/${todo.dueDate!.year}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isOverdue ? Colors.red : Colors.blue,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getPriorityColor(todo.priority).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _getPriorityText(todo.priority),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _getPriorityColor(todo.priority),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                        if (hasSubTasks) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${_getSubTasks(todo.id).length} sous-tâches',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.purple,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                              trailing: hasSubTasks ? IconButton(
                iconSize: 24,
                icon: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.purple,
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
              ) : null,
                              ),
                            ),
                          ),
                          // Afficher les sous-tâches si la tâche est dépliée
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
            DropdownButtonFormField<Project>(
              value: _selectedProject,
              decoration: const InputDecoration(
                labelText: 'Projet',
                border: OutlineInputBorder(),
              ),
              items: widget.projects.map((project) {
                return DropdownMenuItem(
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
              }).toList(),
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
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() {
                          _selectedDate = date;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today),
                          const SizedBox(width: 8),
                          Text(
                            _selectedDate != null
                                ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                : 'Date d\'échéance (optionnel)',
                            style: TextStyle(
                              color: _selectedDate != null 
                                  ? Colors.black 
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_selectedDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _selectedDate = null;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Rappel
            Row(
              children: [
                Expanded(
                  child: InkWell(
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
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.alarm),
                          const SizedBox(width: 8),
                          Text(
                            _selectedReminder != null
                                ? '${_selectedReminder!.day}/${_selectedReminder!.month}/${_selectedReminder!.year} à ${_selectedReminder!.hour.toString().padLeft(2, '0')}:${_selectedReminder!.minute.toString().padLeft(2, '0')}'
                                : 'Rappel (optionnel)',
                            style: TextStyle(
                              color: _selectedReminder != null 
                                  ? Colors.black 
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_selectedReminder != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _selectedReminder = null;
                      });
                    },
                  ),
              ],
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
                      onPressed: () {
                        if (_titleController.text.trim().isEmpty || _selectedProject == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Veuillez entrer un titre et sélectionner un projet')),
                          );
                          return;
                        }
                                                        final newTodo = TodoItem(
                              id: DateTime.now().millisecondsSinceEpoch,
                              title: _titleController.text.trim(),
                              description: _descriptionController.text.trim(),
                              dueDate: _selectedDate,
                              priority: _selectedPriority,
                              projectId: _selectedProject!.id,
                              isCompleted: false,
                              parentId: null, // Tâche racine
                              level: 0,
                              reminder: _selectedReminder,
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
  
  const EditTodoModal({
    super.key, 
    required this.todo,
    required this.projects,
    required this.subTasks,
    required this.onAddSubTask,
    required this.onToggleSubTask,
  });

  @override
  State<EditTodoModal> createState() => _EditTodoModalState();
}

class _EditTodoModalState extends State<EditTodoModal> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
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
            DropdownButtonFormField<Project>(
              value: _selectedProject,
              decoration: const InputDecoration(
                labelText: 'Projet',
                border: OutlineInputBorder(),
              ),
              items: widget.projects.map((project) {
                return DropdownMenuItem(
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
              }).toList(),
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
            Row(
              children: [
                Expanded(
                  child: InkWell(
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
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today),
                          const SizedBox(width: 8),
                          Text(
                            _selectedDate != null
                                ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                : 'Date d\'échéance (optionnel)',
                            style: TextStyle(
                              color: _selectedDate != null 
                                  ? Colors.black 
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_selectedDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _selectedDate = null;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Rappel
            Row(
              children: [
                Expanded(
                  child: InkWell(
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
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.alarm),
                          const SizedBox(width: 8),
                          Text(
                            _selectedReminder != null
                                ? '${_selectedReminder!.day}/${_selectedReminder!.month}/${_selectedReminder!.year} à ${_selectedReminder!.hour.toString().padLeft(2, '0')}:${_selectedReminder!.minute.toString().padLeft(2, '0')}'
                                : 'Rappel (optionnel)',
                            style: TextStyle(
                              color: _selectedReminder != null 
                                  ? Colors.black 
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_selectedReminder != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _selectedReminder = null;
                      });
                    },
                  ),
              ],
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
                      return ListTile(
                        leading: const Icon(Icons.subdirectory_arrow_right),
                        title: Text(subTask.title),
                        subtitle: subTask.description.isNotEmpty ? Text(subTask.description) : null,
                        trailing: Checkbox(
                          value: subTask.isCompleted,
                          onChanged: (_) {
                            widget.onToggleSubTask(subTask.id);
                            setState(() {
                              final index = _subTasks.indexWhere((t) => t.id == subTask.id);
                              if (index != -1) {
                                _subTasks[index] = TodoItem(
                                  id: subTask.id,
                                  title: subTask.title,
                                  description: subTask.description,
                                  dueDate: subTask.dueDate,
                                  priority: subTask.priority,
                                  projectId: subTask.projectId,
                                  isCompleted: !subTask.isCompleted,
                                  parentId: subTask.parentId,
                                  level: subTask.level,
                                  reminder: subTask.reminder,
                                );
                              }
                            });
                          },
                        ),
                        // TODO: ouvrir la modale d'édition de la sous-tâche ici à l'étape suivante
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
                                                    final updatedTodo = TodoItem(
                          id: widget.todo.id,
                          title: _titleController.text.trim(),
                          description: _descriptionController.text.trim(),
                          dueDate: _selectedDate,
                          priority: _selectedPriority,
                          projectId: _selectedProject!.id,
                          isCompleted: widget.todo.isCompleted,
                          parentId: widget.todo.parentId, // Conserve le parent existant
                          level: widget.todo.level, // Conserve le niveau existant
                          reminder: _selectedReminder,
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
                            final homeState = context.findAncestorStateOfType<_TodoHomePageState>();
                            if (homeState != null) {
                              homeState._deleteTodo(widget.todo.id);
                            }
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
          onPressed: _nameController.text.trim().isEmpty
              ? null
              : () {
                  final newProject = Project(
                    id: DateTime.now().millisecondsSinceEpoch,
                    name: _nameController.text.trim(),
                    color: _selectedColor,
                    isDefault: false,
                  );
                  Navigator.pop(context, newProject);
                },
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

enum Priority { low, medium, high }

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

class Project {
  final int id;
  final String name;
  final Color color;
  final bool isDefault;

  Project({
    required this.id,
    required this.name,
    required this.color,
    required this.isDefault,
  });

  // Convertir en Map pour la sauvegarde
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color.value,
      'isDefault': isDefault,
    };
  }

  // Créer depuis une Map
  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'],
      name: map['name'],
      color: Color(map['color']),
      isDefault: map['isDefault'],
    );
  }
}

class TodoItem {
  final int id;
  final String title;
  final String description;
  final DateTime? dueDate;
  final Priority priority;
  final int projectId;
  bool isCompleted;
  final int? parentId; // ID de la tâche parente (null pour les tâches racines)
  final int level; // Niveau de profondeur (0 = tâche racine, 1-3 = sous-tâches)
  final DateTime? reminder; // Date et heure du rappel

  TodoItem({
    required this.id,
    required this.title,
    required this.description,
    this.dueDate,
    required this.priority,
    required this.projectId,
    required this.isCompleted,
    this.parentId,
    this.level = 0,
    this.reminder,
  });

  // Méthode pour créer une sous-tâche
  TodoItem createSubTask({
    required String title,
    required String description,
    DateTime? dueDate,
    Priority priority = Priority.medium,
    bool isCompleted = false,
  }) {
    if (level >= 3) {
      throw Exception('Impossible de créer une sous-tâche au-delà du niveau 3');
    }
    
    return TodoItem(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      projectId: this.projectId, // Hérite du projet parent
      isCompleted: isCompleted,
      parentId: this.id,
      level: this.level + 1,
    );
  }

  // Méthode pour vérifier si c'est une tâche racine
  bool get isRootTask => parentId == null;

  // Méthode pour vérifier si c'est une sous-tâche
  bool get isSubTask => parentId != null;

  // Méthode pour vérifier si on peut ajouter des sous-tâches
  bool get canHaveSubTasks => level < 3;

  // Convertir en Map pour la sauvegarde
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'priority': priority.index,
      'projectId': projectId,
      'isCompleted': isCompleted,
      'parentId': parentId,
      'level': level,
      'reminder': reminder?.millisecondsSinceEpoch,
    };
  }

  // Créer depuis une Map
  factory TodoItem.fromMap(Map<String, dynamic> map) {
    return TodoItem(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      dueDate: map['dueDate'] != null ? DateTime.fromMillisecondsSinceEpoch(map['dueDate']) : null,
      priority: Priority.values[map['priority']],
      projectId: map['projectId'],
      isCompleted: map['isCompleted'],
      parentId: map['parentId'],
      level: map['level'] ?? 0,
      reminder: map['reminder'] != null ? DateTime.fromMillisecondsSinceEpoch(map['reminder']) : null,
    );
  }
}
