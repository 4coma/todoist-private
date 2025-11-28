import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class FileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  /// Demande les permissions nécessaires
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      // Sur Android 13+ (API 33+), on n'a plus besoin de permissions de stockage
      // pour accéder aux fichiers via le sélecteur de fichiers
      if (await _isAndroid13OrHigher()) {
        return true;
      }
      
      // Sur les versions antérieures, demander les permissions
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return true; // Sur iOS et autres plateformes, les permissions sont gérées automatiquement
  }

  /// Vérifie si on est sur Android 13 ou plus
  Future<bool> _isAndroid13OrHigher() async {
    if (Platform.isAndroid) {
      try {
        // Utiliser une approche simple pour détecter la version
        // En production, on utiliserait device_info_plus
        return true; // Pour l'instant, on assume Android 13+
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  /// Sauvegarde les données dans un fichier JSON
  Future<String?> saveDataToFile(Map<String, dynamic> data) async {
    try {
      // Générer un nom de fichier avec timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'todo_app_backup_$timestamp.json';

      // Demander à l'utilisateur de sélectionner un répertoire
      String? directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Sélectionner un dossier pour sauvegarder',
      );

      if (directoryPath == null) {
        return null; // Utilisateur a annulé
      }

      // Créer le chemin complet du fichier
      final outputFile = '$directoryPath/$fileName';

      // Écrire les données dans le fichier
      final file = File(outputFile);
      final jsonString = jsonEncode(data);
      await file.writeAsString(jsonString, flush: true);

      return outputFile;
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde fichier: $e');
      rethrow;
    }
  }

  /// Charge les données depuis un fichier JSON
  Future<Map<String, dynamic>?> loadDataFromFile() async {
    try {
      // Demander à l'utilisateur de sélectionner un fichier
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Sélectionner un fichier de sauvegarde',
        allowedExtensions: ['json'],
        type: FileType.custom,
      );

      if (result == null || result.files.isEmpty) {
        return null; // Utilisateur a annulé
      }

      final file = File(result.files.first.path!);
      
      // Vérifier que le fichier existe
      if (!await file.exists()) {
        throw Exception('Fichier introuvable');
      }

      // Lire et parser le contenu JSON
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      return data;
    } catch (e) {
      debugPrint('❌ Erreur chargement fichier: $e');
      rethrow;
    }
  }

  /// Obtient le répertoire de documents de l'application
  Future<Directory?> getAppDocumentsDirectory() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (e) {
      debugPrint('❌ Erreur répertoire documents: $e');
      return null;
    }
  }

  /// Vérifie si un fichier est un fichier de sauvegarde valide
  bool isValidBackupFile(Map<String, dynamic> data) {
    // Vérifier que le fichier contient au moins une des clés attendues
    // Plus flexible pour accepter différents formats
    final possibleKeys = ['todos', 'projects', 'preferences', 'version', 'exportDate'];
    final hasAtLeastOneKey = possibleKeys.any((key) => data.containsKey(key));
    
    // Vérifier aussi que c'est bien un Map (pas null, pas une liste, etc.)
    if (!hasAtLeastOneKey) {
      debugPrint('⚠️ Fichier invalide: aucune clé attendue trouvée. Clés présentes: ${data.keys.toList()}');
      return false;
    }
    
    // Si on a 'todos' ou 'projects', c'est probablement un fichier valide
    if (data.containsKey('todos') || data.containsKey('projects')) {
      return true;
    }
    
    // Sinon, on accepte si on a au moins 'preferences' ou 'version'
    return data.containsKey('preferences') || data.containsKey('version');
  }

  /// Formate la taille d'un fichier
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
} 