import 'package:flutter/foundation.dart';

class DebugLogger {
  static final DebugLogger _instance = DebugLogger._internal();
  factory DebugLogger() => _instance;
  DebugLogger._internal();

  // Liste pour stocker les logs en mémoire
  final List<String> _logs = [];
  
  // Callback pour notifier les changements
  Function()? _onLogAdded;

  void setOnLogAdded(Function() callback) {
    _onLogAdded = callback;
  }

  void log(String message) {
    final timestamp = DateTime.now().toString();
    final logMessage = '[$timestamp] $message';
    
    // Ajouter au debug console
    debugPrint(logMessage);
    
    // Ajouter à la liste en mémoire
    _logs.add(logMessage);
    
    // Limiter la taille de la liste
    if (_logs.length > 100) {
      _logs.removeAt(0);
    }
    
    // Notifier le changement
    _onLogAdded?.call();
  }

  List<String> getLogs() {
    return List.from(_logs);
  }

  void clearLogs() {
    _logs.clear();
    _onLogAdded?.call();
  }

  void logError(String message, [dynamic error, StackTrace? stackTrace]) {
    final timestamp = DateTime.now().toString();
    final logMessage = '[$timestamp] ❌ ERREUR: $message';
    
    debugPrint(logMessage);
    if (error != null) {
      debugPrint('[$timestamp] Détails: $error');
    }
    if (stackTrace != null) {
      debugPrint('[$timestamp] Stack trace: $stackTrace');
    }
    
    _logs.add(logMessage);
    if (error != null) {
      _logs.add('[$timestamp] Détails: $error');
    }
    
    if (_logs.length > 100) {
      _logs.removeAt(0);
    }
    
    _onLogAdded?.call();
  }

  void logSuccess(String message) {
    final timestamp = DateTime.now().toString();
    final logMessage = '[$timestamp] ✅ SUCCÈS: $message';
    
    debugPrint(logMessage);
    _logs.add(logMessage);
    
    if (_logs.length > 100) {
      _logs.removeAt(0);
    }
    
    _onLogAdded?.call();
  }

  void logWarning(String message) {
    final timestamp = DateTime.now().toString();
    final logMessage = '[$timestamp] ⚠️ ATTENTION: $message';
    
    debugPrint(logMessage);
    _logs.add(logMessage);
    
    if (_logs.length > 100) {
      _logs.removeAt(0);
    }
    
    _onLogAdded?.call();
  }

  void logInfo(String message) {
    final timestamp = DateTime.now().toString();
    final logMessage = '[$timestamp] ℹ️ INFO: $message';
    
    debugPrint(logMessage);
    _logs.add(logMessage);
    
    if (_logs.length > 100) {
      _logs.removeAt(0);
    }
    
    _onLogAdded?.call();
  }
} 