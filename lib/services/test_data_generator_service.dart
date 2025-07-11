import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/todo_item.dart';
import '../models/project.dart';
import '../models/app_data.dart';
import 'local_storage_service.dart';
import 'notification_service.dart';

class TestDataGeneratorService {
  static const String _testDataKey = 'test_data_generated';
  
  /// Génère des données de test complètes pour les captures d'écran
  static Future<void> generateTestData() async {
    final localStorageService = LocalStorageService();
    
    // Vérifier si les données de test ont déjà été générées
    final testDataGenerated = await localStorageService.getBool(_testDataKey) ?? false;
    if (testDataGenerated) {
      debugPrint('Test data already generated');
      return;
    }

    debugPrint('Generating comprehensive test data for screenshots...');

    // Créer des projets de test
    final projects = [
      Project(
        id: 'proj_work',
        name: 'Travail',
        color: 'blue',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Project(
        id: 'proj_personal',
        name: 'Personnel',
        color: 'green',
        createdAt: DateTime.now().subtract(const Duration(days: 25)),
      ),
      Project(
        id: 'proj_shopping',
        name: 'Courses',
        color: 'orange',
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
      ),
      Project(
        id: 'proj_health',
        name: 'Santé',
        color: 'red',
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
      Project(
        id: 'proj_study',
        name: 'Études',
        color: 'purple',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    ];

    // Créer des tâches de test avec différents niveaux de complexité
    final todos = [
      // TÂCHES TRAVAIL
      TodoItem(
        id: 'todo_work_1',
        title: 'Préparer la présentation client',
        description: 'Créer les slides pour la réunion de demain avec le client ABC Corp. Inclure les chiffres Q4 et les projections.',
        priority: Priority.high,
        projectId: 'proj_work',
        dueDate: DateTime.now().add(const Duration(days: 1)),
        reminderTime: DateTime.now().add(const Duration(hours: 2)),
        estimatedTime: 120, // 2 heures
        actualTime: 90, // 1h30 déjà passée
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        subtasks: [
          TodoItem(
            id: 'sub_work_1_1',
            title: 'Collecter les données Q4',
            description: 'Récupérer les rapports de vente et les analyses',
            priority: Priority.medium,
            projectId: 'proj_work',
            estimatedTime: 45,
            actualTime: 30,
            isCompleted: true,
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
          TodoItem(
            id: 'sub_work_1_2',
            title: 'Créer les graphiques',
            description: 'Visualiser les tendances et les comparaisons',
            priority: Priority.medium,
            projectId: 'proj_work',
            estimatedTime: 60,
            actualTime: 45,
            isCompleted: false,
            createdAt: DateTime.now().subtract(const Duration(hours: 12)),
            subtasks: [
              TodoItem(
                id: 'sub_sub_work_1_2_1',
                title: 'Graphique des ventes mensuelles',
                priority: Priority.low,
                projectId: 'proj_work',
                estimatedTime: 20,
                actualTime: 15,
                isCompleted: true,
                createdAt: DateTime.now().subtract(const Duration(hours: 6)),
              ),
              TodoItem(
                id: 'sub_sub_work_1_2_2',
                title: 'Comparaison avec l\'année précédente',
                priority: Priority.low,
                projectId: 'proj_work',
                estimatedTime: 25,
                actualTime: 0,
                isCompleted: false,
                createdAt: DateTime.now().subtract(const Duration(hours: 4)),
              ),
            ],
          ),
          TodoItem(
            id: 'sub_work_1_3',
            title: 'Rédiger le script de présentation',
            description: 'Préparer les points clés à aborder',
            priority: Priority.high,
            projectId: 'proj_work',
            estimatedTime: 30,
            actualTime: 15,
            isCompleted: false,
            createdAt: DateTime.now().subtract(const Duration(hours: 8)),
          ),
        ],
      ),
      
      TodoItem(
        id: 'todo_work_2',
        title: 'Réviser le code de l\'API',
        description: 'Passer en revue le code de l\'API REST avant la mise en production',
        priority: Priority.medium,
        projectId: 'proj_work',
        dueDate: DateTime.now().add(const Duration(days: 3)),
        reminderTime: DateTime.now().add(const Duration(days: 1)),
        estimatedTime: 180,
        actualTime: 0,
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        subtasks: [
          TodoItem(
            id: 'sub_work_2_1',
            title: 'Tests unitaires',
            priority: Priority.high,
            projectId: 'proj_work',
            estimatedTime: 60,
            actualTime: 0,
            isCompleted: false,
            createdAt: DateTime.now().subtract(const Duration(hours: 6)),
          ),
          TodoItem(
            id: 'sub_work_2_2',
            title: 'Documentation API',
            priority: Priority.medium,
            projectId: 'proj_work',
            estimatedTime: 90,
            actualTime: 0,
            isCompleted: false,
            createdAt: DateTime.now().subtract(const Duration(hours: 4)),
          ),
        ],
      ),

      // TÂCHES PERSONNELLES
      TodoItem(
        id: 'todo_personal_1',
        title: 'Planifier les vacances d\'été',
        description: 'Organiser le voyage en famille pour juillet',
        priority: Priority.medium,
        projectId: 'proj_personal',
        dueDate: DateTime.now().add(const Duration(days: 14)),
        reminderTime: DateTime.now().add(const Duration(days: 7)),
        estimatedTime: 240,
        actualTime: 60,
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        subtasks: [
          TodoItem(
            id: 'sub_personal_1_1',
            title: 'Rechercher les destinations',
            priority: Priority.medium,
            projectId: 'proj_personal',
            estimatedTime: 120,
            actualTime: 60,
            isCompleted: false,
            createdAt: DateTime.now().subtract(const Duration(days: 4)),
          ),
          TodoItem(
            id: 'sub_personal_1_2',
            title: 'Réserver les billets d\'avion',
            priority: Priority.high,
            projectId: 'proj_personal',
            estimatedTime: 60,
            actualTime: 0,
            isCompleted: false,
            createdAt: DateTime.now().subtract(const Duration(days: 3)),
          ),
        ],
      ),

      TodoItem(
        id: 'todo_personal_2',
        title: 'Apprendre la guitare',
        description: 'Pratiquer 30 minutes par jour pour progresser',
        priority: Priority.low,
        projectId: 'proj_personal',
        estimatedTime: 30,
        actualTime: 25,
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),

      // TÂCHES COURSES
      TodoItem(
        id: 'todo_shopping_1',
        title: 'Faire les courses de la semaine',
        description: 'Acheter les ingrédients pour les repas de la semaine',
        priority: Priority.high,
        projectId: 'proj_shopping',
        dueDate: DateTime.now().add(const Duration(days: 1)),
        reminderTime: DateTime.now().add(const Duration(hours: 4)),
        estimatedTime: 90,
        actualTime: 0,
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        subtasks: [
          TodoItem(
            id: 'sub_shopping_1_1',
            title: 'Fruits et légumes',
            priority: Priority.medium,
            projectId: 'proj_shopping',
            estimatedTime: 20,
            actualTime: 0,
            isCompleted: false,
            createdAt: DateTime.now().subtract(const Duration(hours: 12)),
          ),
          TodoItem(
            id: 'sub_shopping_1_2',
            title: 'Viandes et poissons',
            priority: Priority.medium,
            projectId: 'proj_shopping',
            estimatedTime: 25,
            actualTime: 0,
            isCompleted: false,
            createdAt: DateTime.now().subtract(const Duration(hours: 10)),
          ),
          TodoItem(
            id: 'sub_shopping_1_3',
            title: 'Produits d\'entretien',
            priority: Priority.low,
            projectId: 'proj_shopping',
            estimatedTime: 15,
            actualTime: 0,
            isCompleted: false,
            createdAt: DateTime.now().subtract(const Duration(hours: 8)),
          ),
        ],
      ),

      // TÂCHES SANTÉ
      TodoItem(
        id: 'todo_health_1',
        title: 'Rendez-vous chez le dentiste',
        description: 'Contrôle annuel et détartrage',
        priority: Priority.medium,
        projectId: 'proj_health',
        dueDate: DateTime.now().add(const Duration(days: 5)),
        reminderTime: DateTime.now().add(const Duration(days: 1)),
        estimatedTime: 60,
        actualTime: 0,
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
      ),

      TodoItem(
        id: 'todo_health_2',
        title: 'Séance de sport',
        description: 'Cardio 45 minutes + musculation',
        priority: Priority.high,
        projectId: 'proj_health',
        estimatedTime: 75,
        actualTime: 0,
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),

      // TÂCHES ÉTUDES
      TodoItem(
        id: 'todo_study_1',
        title: 'Réviser Flutter et Dart',
        description: 'Préparer l\'examen de certification Flutter',
        priority: Priority.high,
        projectId: 'proj_study',
        dueDate: DateTime.now().add(const Duration(days: 10)),
        reminderTime: DateTime.now().add(const Duration(days: 3)),
        estimatedTime: 300,
        actualTime: 120,
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        subtasks: [
          TodoItem(
            id: 'sub_study_1_1',
            title: 'Lire la documentation officielle',
            priority: Priority.medium,
            projectId: 'proj_study',
            estimatedTime: 120,
            actualTime: 60,
            isCompleted: false,
            createdAt: DateTime.now().subtract(const Duration(days: 14)),
          ),
          TodoItem(
            id: 'sub_study_1_2',
            title: 'Pratiquer avec des projets',
            priority: Priority.high,
            projectId: 'proj_study',
            estimatedTime: 180,
            actualTime: 60,
            isCompleted: false,
            createdAt: DateTime.now().subtract(const Duration(days: 12)),
          ),
        ],
      ),

      // TÂCHES SANS PROJET (pour tester "Toutes les tâches")
      TodoItem(
        id: 'todo_no_project_1',
        title: 'Appeler maman',
        description: 'Prendre des nouvelles et organiser le repas de dimanche',
        priority: Priority.medium,
        projectId: null,
        dueDate: DateTime.now().add(const Duration(days: 2)),
        reminderTime: DateTime.now().add(const Duration(hours: 6)),
        estimatedTime: 30,
        actualTime: 0,
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),

      TodoItem(
        id: 'todo_no_project_2',
        title: 'Nettoyer le garage',
        description: 'Ranger et trier les affaires du garage',
        priority: Priority.low,
        projectId: null,
        estimatedTime: 180,
        actualTime: 0,
        isCompleted: false,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),

      // TÂCHES TERMINÉES (pour tester l'affichage)
      TodoItem(
        id: 'todo_completed_1',
        title: 'Payer les factures',
        description: 'Régler les factures d\'électricité et d\'internet',
        priority: Priority.high,
        projectId: 'proj_personal',
        dueDate: DateTime.now().subtract(const Duration(days: 2)),
        estimatedTime: 45,
        actualTime: 30,
        isCompleted: true,
        completedAt: DateTime.now().subtract(const Duration(days: 1)),
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),

      TodoItem(
        id: 'todo_completed_2',
        title: 'Réunion équipe',
        description: 'Point hebdomadaire avec l\'équipe de développement',
        priority: Priority.medium,
        projectId: 'proj_work',
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
        estimatedTime: 60,
        actualTime: 55,
        isCompleted: true,
        completedAt: DateTime.now().subtract(const Duration(hours: 6)),
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];

    // Créer l'objet AppData avec toutes les données
    final appData = AppData(
      todos: todos,
      projects: projects,
      lastUpdated: DateTime.now(),
    );

    // Sauvegarder les données
    await localStorageService.saveAppData(appData);
    
    // Programmer les notifications de test
    await _scheduleTestNotifications(todos);
    
    // Marquer que les données de test ont été générées
    await localStorageService.saveBool(_testDataKey, true);
    
    debugPrint('Test data generated successfully!');
    debugPrint('Generated ${todos.length} todos and ${projects.length} projects');
  }

  /// Programme les notifications de test
  static Future<void> _scheduleTestNotifications(List<TodoItem> todos) async {
    final notificationService = NotificationService();
    
    for (final todo in todos) {
      if (todo.reminderTime != null && !todo.isCompleted) {
        await notificationService.scheduleNotification(
          todo.id,
          todo.title,
          todo.description ?? '',
          todo.reminderTime!,
        );
      }
    }
    
    debugPrint('Test notifications scheduled');
  }

  /// Supprime les données de test
  static Future<void> clearTestData() async {
    final localStorageService = LocalStorageService();
    await localStorageService.saveBool(_testDataKey, false);
    debugPrint('Test data flag cleared');
  }

  /// Vérifie si les données de test sont générées
  static Future<bool> isTestDataGenerated() async {
    final localStorageService = LocalStorageService();
    return await localStorageService.getBool(_testDataKey) ?? false;
  }
} 