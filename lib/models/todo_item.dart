import 'package:flutter/material.dart';

enum Priority { low, medium, high }

enum RecurrenceType { none, daily, weekly, monthly }

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
  
  // Propriétés de récurrence
  final RecurrenceType recurrenceType;
  final int? recurrenceDayOfWeek; // 1-7 pour les tâches hebdomadaires (1 = lundi)
  final int? recurrenceDayOfMonth; // 1-31 pour les tâches mensuelles
  final TimeOfDay? recurrenceTime; // Heure de récurrence

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
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceDayOfWeek,
    this.recurrenceDayOfMonth,
    this.recurrenceTime,
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
      'recurrenceType': recurrenceType.index,
      'recurrenceDayOfWeek': recurrenceDayOfWeek,
      'recurrenceDayOfMonth': recurrenceDayOfMonth,
      'recurrenceTime': recurrenceTime != null ? '${recurrenceTime!.hour}:${recurrenceTime!.minute}' : null,
    };
  }

  // Créer depuis une Map (compatibilité avec l'ancien format)
  factory TodoItem.fromMap(Map<String, dynamic> map) {
    TimeOfDay? parseTimeOfDay(String? timeString) {
      if (timeString == null) return null;
      final parts = timeString.split(':');
      if (parts.length == 2) {
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      return null;
    }

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
      recurrenceType: map['recurrenceType'] != null ? RecurrenceType.values[map['recurrenceType']] : RecurrenceType.none,
      recurrenceDayOfWeek: map['recurrenceDayOfWeek'],
      recurrenceDayOfMonth: map['recurrenceDayOfMonth'],
      recurrenceTime: parseTimeOfDay(map['recurrenceTime']),
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
      'recurrenceType': recurrenceType.name,
      'recurrenceDayOfWeek': recurrenceDayOfWeek,
      'recurrenceDayOfMonth': recurrenceDayOfMonth,
      'recurrenceTime': recurrenceTime != null ? '${recurrenceTime!.hour.toString().padLeft(2, '0')}:${recurrenceTime!.minute.toString().padLeft(2, '0')}' : null,
    };
  }

  // Nouvelle méthode fromJson() pour l'export/import
  factory TodoItem.fromJson(Map<String, dynamic> json) {
    TimeOfDay? parseTimeOfDay(String? timeString) {
      if (timeString == null) return null;
      final parts = timeString.split(':');
      if (parts.length == 2) {
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      return null;
    }

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
      recurrenceType: json['recurrenceType'] != null 
          ? RecurrenceType.values.firstWhere(
              (e) => e.name == json['recurrenceType'],
              orElse: () => RecurrenceType.none,
            )
          : RecurrenceType.none,
      recurrenceDayOfWeek: json['recurrenceDayOfWeek'] as int?,
      recurrenceDayOfMonth: json['recurrenceDayOfMonth'] as int?,
      recurrenceTime: parseTimeOfDay(json['recurrenceTime'] as String?),
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
    RecurrenceType? recurrenceType,
    int? recurrenceDayOfWeek,
    int? recurrenceDayOfMonth,
    TimeOfDay? recurrenceTime,
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
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceDayOfWeek: recurrenceDayOfWeek ?? this.recurrenceDayOfWeek,
      recurrenceDayOfMonth: recurrenceDayOfMonth ?? this.recurrenceDayOfMonth,
      recurrenceTime: recurrenceTime ?? this.recurrenceTime,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TodoItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Méthodes pour la récurrence
  bool get isRecurring => recurrenceType != RecurrenceType.none;

  String get recurrenceText {
    switch (recurrenceType) {
      case RecurrenceType.none:
        return 'Non récurrente';
      case RecurrenceType.daily:
        return 'Quotidienne';
      case RecurrenceType.weekly:
        if (recurrenceDayOfWeek != null) {
          final days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
          return 'Hebdomadaire (${days[recurrenceDayOfWeek! - 1]})';
        }
        return 'Hebdomadaire';
      case RecurrenceType.monthly:
        if (recurrenceDayOfMonth != null) {
          return 'Mensuelle (jour $recurrenceDayOfMonth)';
        }
        return 'Mensuelle';
    }
  }

  String get recurrenceTimeText {
    if (recurrenceTime == null) return '';
    return '${recurrenceTime!.hour.toString().padLeft(2, '0')}:${recurrenceTime!.minute.toString().padLeft(2, '0')}';
  }

  // Méthode pour calculer la prochaine occurrence
  DateTime? getNextOccurrence() {
    if (!isRecurring || recurrenceTime == null) return null;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetTime = DateTime(
      today.year, 
      today.month, 
      today.day, 
      recurrenceTime!.hour, 
      recurrenceTime!.minute
    );

    switch (recurrenceType) {
      case RecurrenceType.none:
        return null;
      case RecurrenceType.daily:
        return targetTime.isBefore(now) ? targetTime.add(const Duration(days: 1)) : targetTime;
      case RecurrenceType.weekly:
        if (recurrenceDayOfWeek == null) return null;
        final currentWeekday = now.weekday;
        final daysUntilNext = (recurrenceDayOfWeek! - currentWeekday + 7) % 7;
        final nextDate = today.add(Duration(days: daysUntilNext));
        return DateTime(
          nextDate.year, 
          nextDate.month, 
          nextDate.day, 
          recurrenceTime!.hour, 
          recurrenceTime!.minute
        );
      case RecurrenceType.monthly:
        if (recurrenceDayOfMonth == null) return null;
        final currentDay = now.day;
        DateTime nextDate;
        if (currentDay <= recurrenceDayOfMonth!) {
          nextDate = DateTime(now.year, now.month, recurrenceDayOfMonth!);
        } else {
          nextDate = DateTime(now.year, now.month + 1, recurrenceDayOfMonth!);
        }
        return DateTime(
          nextDate.year, 
          nextDate.month, 
          nextDate.day, 
          recurrenceTime!.hour, 
          recurrenceTime!.minute
        );
    }
  }

  @override
  String toString() {
    return 'TodoItem{id: $id, title: $title, isCompleted: $isCompleted, projectId: $projectId}';
  }
} 