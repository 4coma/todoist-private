import 'todo_item.dart';
import 'project.dart';

class AppData {
  final String version;
  final DateTime exportDate;
  final List<TodoItem> todos;
  final List<Project> projects;
  final Map<String, dynamic> preferences;
  final Map<String, dynamic> timerData;

  AppData({
    required this.version,
    required this.exportDate,
    required this.todos,
    required this.projects,
    required this.preferences,
    required this.timerData,
  });

  // Créer depuis les données de l'application
  factory AppData.fromCurrentData({
    required List<TodoItem> todos,
    required List<Project> projects,
    required Map<String, dynamic> preferences,
    required Map<String, dynamic> timerData,
  }) {
    return AppData(
      version: '1.0.0',
      exportDate: DateTime.now(),
      todos: todos,
      projects: projects,
      preferences: preferences,
      timerData: timerData,
    );
  }

  // Convertir en JSON pour l'export
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'exportDate': exportDate.toIso8601String(),
      'todos': todos.map((todo) => todo.toJson()).toList(),
      'projects': projects.map((project) => project.toJson()).toList(),
      'preferences': preferences,
      'timerData': timerData,
    };
  }

  // Créer depuis JSON pour l'import
  factory AppData.fromJson(Map<String, dynamic> json) {
    return AppData(
      version: json['version'] as String,
      exportDate: DateTime.parse(json['exportDate'] as String),
      todos: (json['todos'] as List)
          .map((todoJson) => TodoItem.fromJson(todoJson as Map<String, dynamic>))
          .toList(),
      projects: (json['projects'] as List)
          .map((projectJson) => Project.fromJson(projectJson as Map<String, dynamic>))
          .toList(),
      preferences: Map<String, dynamic>.from(json['preferences'] as Map),
      timerData: Map<String, dynamic>.from(json['timerData'] as Map),
    );
  }

  // Valider les données importées
  bool isValid() {
    return version.isNotEmpty && 
           todos.isNotEmpty || projects.isNotEmpty;
  }

  // Obtenir des statistiques sur les données
  Map<String, int> getStats() {
    return {
      'todos': todos.length,
      'projects': projects.length,
      'completed_todos': todos.where((t) => t.isCompleted).length,
      'pending_todos': todos.where((t) => !t.isCompleted).length,
      'preferences_count': preferences.length,
      'timer_data_count': timerData.length,
    };
  }

  @override
  String toString() {
    final stats = getStats();
    return 'AppData{version: $version, exportDate: $exportDate, todos: ${stats['todos']}, projects: ${stats['projects']}}';
  }
} 