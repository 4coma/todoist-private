import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../models/todo_item.dart';
import '../models/project.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _todosKey = 'todos';
  static const String _projectsKey = 'projects';

  // Sauvegarder les tâches
  Future<void> saveTodos(List<TodoItem> todos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todosMaps = todos.map((todo) => todo.toMap()).toList();
      final todosJson = jsonEncode(todosMaps);
      await prefs.setString(_todosKey, todosJson);
      debugPrint('✅ Tâches sauvegardées: ${todos.length} tâches');
    } catch (e) {
      debugPrint('❌ Erreur lors de la sauvegarde des tâches: $e');
    }
  }

  // Charger les tâches
  Future<List<TodoItem>> loadTodos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todosJson = prefs.getString(_todosKey);
      if (todosJson != null) {
        final List<dynamic> todosList = jsonDecode(todosJson);
        final todos = todosList.map((map) => TodoItem.fromMap(map)).toList();
        debugPrint('✅ Tâches chargées: ${todos.length} tâches');
        return todos;
      }
    } catch (e) {
      debugPrint('❌ Erreur lors du chargement des tâches: $e');
    }
    return [];
  }

  // Sauvegarder les projets
  Future<void> saveProjects(List<Project> projects) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final projectsMaps = projects.map((project) => project.toMap()).toList();
      final projectsJson = jsonEncode(projectsMaps);
      await prefs.setString(_projectsKey, projectsJson);
      debugPrint('✅ Projets sauvegardés: ${projects.length} projets');
    } catch (e) {
      debugPrint('❌ Erreur lors de la sauvegarde des projets: $e');
    }
  }

  // Charger les projets
  Future<List<Project>> loadProjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final projectsJson = prefs.getString(_projectsKey);
      if (projectsJson != null) {
        final List<dynamic> projectsList = jsonDecode(projectsJson);
        final projects = projectsList.map((map) => Project.fromMap(map)).toList();
        debugPrint('✅ Projets chargés: ${projects.length} projets');
        return projects;
      }
    } catch (e) {
      debugPrint('❌ Erreur lors du chargement des projets: $e');
    }
    return [];
  }

  // Effacer toutes les données
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_todosKey);
      await prefs.remove(_projectsKey);
      debugPrint('✅ Toutes les données ont été effacées');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'effacement des données: $e');
    }
  }
} 