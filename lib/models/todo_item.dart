 

enum Priority { low, medium, high }

class TodoItem {
  final int id;
  final String title;
  final String description;
  final DateTime? dueDate;
  final Priority priority;
  final int? projectId;
  bool isCompleted;
  final int? parentId; // ID de la tâche parente (null pour les tâches racines)
  final int level; // Niveau de profondeur (0 = tâche racine, 1-3 = sous-tâches)
  final DateTime? reminder; // Date et heure du rappel
  final int? estimatedMinutes; // Temps estimé en minutes
  int elapsedMinutes; // Temps passé en minutes
  int elapsedSeconds; // Temps passé en secondes
  final DateTime createdAt;
  final DateTime updatedAt;

  TodoItem({
    required this.id,
    required this.title,
    required this.description,
    this.dueDate,
    required this.priority,
    this.projectId,
    required this.isCompleted,
    this.parentId,
    this.level = 0,
    this.reminder,
    this.estimatedMinutes,
    this.elapsedMinutes = 0,
    this.elapsedSeconds = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now();

  // Méthode pour créer une sous-tâche
  TodoItem createSubTask({
    required String title,
    required String description,
    DateTime? dueDate,
    Priority priority = Priority.medium,
    bool isCompleted = false,
    int? estimatedMinutes,
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
      estimatedMinutes: estimatedMinutes,
    );
  }

  // Méthode pour vérifier si c'est une tâche racine
  bool get isRootTask => parentId == null;

  // Méthode pour vérifier si c'est une sous-tâche
  bool get isSubTask => parentId != null;

  // Méthode pour vérifier si on peut ajouter des sous-tâches
  bool get canHaveSubTasks => level < 3;

  // Méthode pour formater le temps estimé
  String get estimatedTimeText {
    if (estimatedMinutes == null) return 'Non défini';
    final hours = estimatedMinutes! ~/ 60;
    final minutes = estimatedMinutes! % 60;
    if (hours > 0) {
      return '${hours}h${minutes > 0 ? ' ${minutes}min' : ''}';
    }
    return '${minutes}min';
  }

  // Méthode pour formater le temps passé
  String get elapsedTimeText {
    final hours = elapsedMinutes ~/ 60;
    final minutes = elapsedMinutes % 60;
    if (hours > 0) {
      return '${hours}h${minutes > 0 ? ' ${minutes}min' : ''}';
    }
    return '${minutes}min';
  }

  // Méthode pour calculer le pourcentage de progression
  double get progressPercentage {
    if (estimatedMinutes == null || estimatedMinutes == 0) return 0.0;
    return (elapsedMinutes / estimatedMinutes!).clamp(0.0, 1.0);
  }

  // Convertir en Map pour la sauvegarde (compatibilité avec l'ancien format)
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
      'estimatedMinutes': estimatedMinutes,
      'elapsedMinutes': elapsedMinutes,
      'elapsedSeconds': elapsedSeconds,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  // Créer depuis une Map (compatibilité avec l'ancien format)
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
      estimatedMinutes: map['estimatedMinutes'],
      elapsedMinutes: map['elapsedMinutes'] ?? 0,
      elapsedSeconds: (map['elapsedSeconds'] ?? ((map['elapsedMinutes'] ?? 0) * 60)) as int,
      createdAt: map['createdAt'] != null ? DateTime.fromMillisecondsSinceEpoch(map['createdAt']) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt']) : DateTime.now(),
    );
  }

  // Nouvelle méthode toJson() pour l'export/import
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'priority': priority.name,
      'projectId': projectId,
      'isCompleted': isCompleted,
      'parentId': parentId,
      'level': level,
      'reminder': reminder?.toIso8601String(),
      'estimatedMinutes': estimatedMinutes,
      'elapsedMinutes': elapsedMinutes,
      'elapsedSeconds': elapsedSeconds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Nouvelle méthode fromJson() pour l'export/import
  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
      priority: Priority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => Priority.medium,
      ),
      projectId: json['projectId'] as int?,
      isCompleted: json['isCompleted'] as bool,
      parentId: json['parentId'] as int?,
      level: json['level'] as int? ?? 0,
      reminder: json['reminder'] != null ? DateTime.parse(json['reminder'] as String) : null,
      estimatedMinutes: json['estimatedMinutes'] as int?,
      elapsedMinutes: json['elapsedMinutes'] as int? ?? 0,
      elapsedSeconds: json['elapsedSeconds'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  // Méthode pour créer une copie avec des modifications
  TodoItem copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? dueDate,
    Priority? priority,
    int? projectId,
    bool? isCompleted,
    int? parentId,
    int? level,
    DateTime? reminder,
    int? estimatedMinutes,
    int? elapsedMinutes,
    int? elapsedSeconds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      projectId: projectId ?? this.projectId,
      isCompleted: isCompleted ?? this.isCompleted,
      parentId: parentId ?? this.parentId,
      level: level ?? this.level,
      reminder: reminder ?? this.reminder,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      elapsedMinutes: elapsedMinutes ?? this.elapsedMinutes,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TodoItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'TodoItem{id: $id, title: $title, isCompleted: $isCompleted, projectId: $projectId}';
  }
} 