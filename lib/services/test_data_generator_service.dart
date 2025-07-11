import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/todo_item.dart';
import '../models/project.dart';
import '../models/app_data.dart';
import 'local_storage_service.dart';
import 'notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestDataGeneratorService {
  static const String _testDataKey = 'test_data_generated';
  
  /// Génère des données de test complètes pour les captures d'écran
  static Future<void> generateTestData() async {
    final localStorageService = LocalStorageService();
    
    // Vérifier si les données de test ont déjà été générées
    final testDataGenerated = await _getBool(_testDataKey) ?? false;
    if (testDataGenerated) {
      debugPrint('Test data already generated');
      return;
    }

    debugPrint('Generating comprehensive test data for screenshots...');

    // Créer des projets de test
    final projects = [
      Project(
        id: 1,
        name: 'Travail',
        color: Colors.blue,
        isDefault: false,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Project(
        id: 2,
        name: 'Personnel',
        color: Colors.green,
        isDefault: false,
        createdAt: DateTime.now().subtract(const Duration(days: 25)),
      ),
      Project(
        id: 3,
        name: 'Courses',
        color: Colors.orange,
        isDefault: false,
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
      ),
      Project(
        id: 4,
        name: 'Santé',
        color: Colors.red,
        isDefault: false,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
      Project(
        id: 5,
        name: 'Études',
        color: Colors.purple,
        isDefault: false,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    ];

    // Créer des tâches de test avec différents niveaux de complexité
    final todos = [
      // TÂCHES TRAVAIL
      TodoItem(
        id: 1,
        title: 'Préparer la présentation client',
        description: 'Créer les slides pour la réunion de demain avec le client ABC Corp. Inclure les chiffres Q4 et les projections.',
        priority: Priority.high,
        projectId: 1,
        dueDate: DateTime.now().add(const Duration(days: 1)),
        reminder: DateTime.now().add(const Duration(hours: 2)),
        estimatedMinutes: 120, // 2 heures
        elapsedMinutes: 90, // 1h30 déjà passée
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      
      TodoItem(
        id: 2,
        title: 'Collecter les données Q4',
        description: 'Récupérer les rapports de vente et les analyses',
        priority: Priority.medium,
        projectId: 1,
        estimatedMinutes: 45,
        elapsedMinutes: 30,
        isCompleted: true,
        parentId: 1,
        level: 1,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      
      TodoItem(
        id: 3,
        title: 'Créer les graphiques',
        description: 'Visualiser les tendances et les comparaisons',
        priority: Priority.medium,
        projectId: 1,
        estimatedMinutes: 60,
        elapsedMinutes: 45,
        isCompleted: false,
        parentId: 1,
        level: 1,
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
      ),
      
      TodoItem(
        id: 4,
        title: 'Graphique des ventes mensuelles',
        priority: Priority.low,
        projectId: 1,
        estimatedMinutes: 20,
        elapsedMinutes: 15,
        isCompleted: true,
        parentId: 3,
        level: 2,
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      
      TodoItem(
        id: 5,
        title: 'Comparaison avec l\'année précédente',
        priority: Priority.low,
        projectId: 1,
        estimatedMinutes: 25,
        elapsedMinutes: 0,
        isCompleted: false,
        parentId: 3,
        level: 2,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      
      TodoItem(
        id: 6,
        title: 'Rédiger le script de présentation',
        description: 'Préparer les points clés à aborder',
        priority: Priority.high,
        projectId: 1,
        estimatedMinutes: 30,
        elapsedMinutes: 15,
        isCompleted: false,
        parentId: 1,
        level: 1,
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      
      TodoItem(
        id: 7,
        title: 'Réviser le code de l\'API',
        description: 'Passer en revue le code de l\'API REST avant la mise en production',
        priority: Priority.medium,
        projectId: 1,
        dueDate: DateTime.now().add(const Duration(days: 3)),
        reminder: DateTime.now().add(const Duration(days: 1)),
        estimatedMinutes: 180,
        elapsedMinutes: 0,
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),

      // TÂCHES PERSONNELLES
      TodoItem(
        id: 8,
        title: 'Planifier les vacances d\'été',
        description: 'Organiser le voyage en famille pour juillet',
        priority: Priority.medium,
        projectId: 2,
        dueDate: DateTime.now().add(const Duration(days: 14)),
        reminder: DateTime.now().add(const Duration(days: 7)),
        estimatedMinutes: 240,
        elapsedMinutes: 60,
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),

      TodoItem(
        id: 9,
        title: 'Rechercher les destinations',
        priority: Priority.medium,
        projectId: 2,
        estimatedMinutes: 120,
        elapsedMinutes: 60,
        isCompleted: false,
        parentId: 8,
        level: 1,
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
      ),

      TodoItem(
        id: 10,
        title: 'Réserver les billets d\'avion',
        priority: Priority.high,
        projectId: 2,
        estimatedMinutes: 60,
        elapsedMinutes: 0,
        isCompleted: false,
        parentId: 8,
        level: 1,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),

      TodoItem(
        id: 11,
        title: 'Apprendre la guitare',
        description: 'Pratiquer 30 minutes par jour pour progresser',
        priority: Priority.low,
        projectId: 2,
        estimatedMinutes: 30,
        elapsedMinutes: 25,
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),

      // TÂCHES COURSES
      TodoItem(
        id: 12,
        title: 'Faire les courses de la semaine',
        description: 'Acheter les ingrédients pour les repas de la semaine',
        priority: Priority.high,
        projectId: 3,
        dueDate: DateTime.now().add(const Duration(days: 1)),
        reminder: DateTime.now().add(const Duration(hours: 4)),
        estimatedMinutes: 90,
        elapsedMinutes: 0,
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),

      TodoItem(
        id: 13,
        title: 'Fruits et légumes',
        priority: Priority.medium,
        projectId: 3,
        estimatedMinutes: 20,
        elapsedMinutes: 0,
        isCompleted: false,
        parentId: 12,
        level: 1,
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
      ),

      TodoItem(
        id: 14,
        title: 'Viandes et poissons',
        priority: Priority.medium,
        projectId: 3,
        estimatedMinutes: 25,
        elapsedMinutes: 0,
        isCompleted: false,
        parentId: 12,
        level: 1,
        createdAt: DateTime.now().subtract(const Duration(hours: 10)),
      ),

      TodoItem(
        id: 15,
        title: 'Produits d\'entretien',
        priority: Priority.low,
        projectId: 3,
        estimatedMinutes: 15,
        elapsedMinutes: 0,
        isCompleted: false,
        parentId: 12,
        level: 1,
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),

      // TÂCHES SANTÉ
      TodoItem(
        id: 16,
        title: 'Rendez-vous chez le dentiste',
        description: 'Contrôle annuel et détartrage',
        priority: Priority.medium,
        projectId: 4,
        dueDate: DateTime.now().add(const Duration(days: 5)),
        reminder: DateTime.now().add(const Duration(days: 1)),
        estimatedMinutes: 60,
        elapsedMinutes: 0,
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
      ),

      TodoItem(
        id: 17,
        title: 'Séance de sport',
        description: 'Cardio 45 minutes + musculation',
        priority: Priority.high,
        projectId: 4,
        estimatedMinutes: 75,
        elapsedMinutes: 0,
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),

      // TÂCHES ÉTUDES
      TodoItem(
        id: 18,
        title: 'Réviser Flutter et Dart',
        description: 'Préparer l\'examen de certification Flutter',
        priority: Priority.high,
        projectId: 5,
        dueDate: DateTime.now().add(const Duration(days: 10)),
        reminder: DateTime.now().add(const Duration(days: 3)),
        estimatedMinutes: 300,
        elapsedMinutes: 120,
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
      ),

      TodoItem(
        id: 19,
        title: 'Lire la documentation officielle',
        priority: Priority.medium,
        projectId: 5,
        estimatedMinutes: 120,
        elapsedMinutes: 60,
        isCompleted: false,
        parentId: 18,
        level: 1,
        createdAt: DateTime.now().subtract(const Duration(days: 14)),
      ),

      TodoItem(
        id: 20,
        title: 'Pratiquer avec des projets',
        priority: Priority.high,
        projectId: 5,
        estimatedMinutes: 180,
        elapsedMinutes: 60,
        isCompleted: false,
        parentId: 18,
        level: 1,
        createdAt: DateTime.now().subtract(const Duration(days: 12)),
      ),

      // TÂCHES SANS PROJET (pour tester "Toutes les tâches")
      TodoItem(
        id: 21,
        title: 'Appeler maman',
        description: 'Prendre des nouvelles et organiser le repas de dimanche',
        priority: Priority.medium,
        projectId: null,
        dueDate: DateTime.now().add(const Duration(days: 2)),
        reminder: DateTime.now().add(const Duration(hours: 6)),
        estimatedMinutes: 30,
        elapsedMinutes: 0,
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),

      TodoItem(
        id: 22,
        title: 'Nettoyer le garage',
        description: 'Ranger et trier les affaires du garage',
        priority: Priority.low,
        projectId: null,
        estimatedMinutes: 180,
        elapsedMinutes: 0,
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),

      // TÂCHES TERMINÉES (pour tester l'affichage)
      TodoItem(
        id: 23,
        title: 'Payer les factures',
        description: 'Régler les factures d\'électricité et d\'internet',
        priority: Priority.high,
        projectId: 2,
        dueDate: DateTime.now().subtract(const Duration(days: 2)),
        estimatedMinutes: 45,
        elapsedMinutes: 30,
        isCompleted: true,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),

      TodoItem(
        id: 24,
        title: 'Réunion équipe',
        description: 'Point hebdomadaire avec l\'équipe de développement',
        priority: Priority.medium,
        projectId: 1,
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
        estimatedMinutes: 60,
        elapsedMinutes: 55,
        isCompleted: true,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];

    // Sauvegarder les projets
    for (final project in projects) {
      await localStorageService.addProject(project);
    }

    // Sauvegarder les tâches
    for (final todo in todos) {
      await localStorageService.addTodo(todo);
    }
    
    // Programmer les notifications de test
    await _scheduleTestNotifications(todos);
    
    // Marquer que les données de test ont été générées
    await _saveBool(_testDataKey, true);
    
    debugPrint('Test data generated successfully!');
    debugPrint('Generated ${todos.length} todos and ${projects.length} projects');
  }

  /// Programme les notifications de test
  static Future<void> _scheduleTestNotifications(List<TodoItem> todos) async {
    final notificationService = NotificationService();
    
    for (final todo in todos) {
      if (todo.reminder != null && !todo.isCompleted) {
        await notificationService.scheduleNotification(
          todo.id,
          todo.title,
          todo.description,
          todo.reminder!,
        );
      }
    }
    
    debugPrint('Test notifications scheduled');
  }

  /// Supprime les données de test
  static Future<void> clearTestData() async {
    await _saveBool(_testDataKey, false);
    debugPrint('Test data flag cleared');
  }

  /// Vérifie si les données de test sont générées
  static Future<bool> isTestDataGenerated() async {
    return await _getBool(_testDataKey) ?? false;
  }

  // Méthodes utilitaires pour SharedPreferences
  static Future<bool?> _getBool(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }

  static Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
} 