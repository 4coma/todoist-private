import 'dart:async';
import 'package:flutter/foundation.dart';

class TimerService extends ChangeNotifier {
  static final TimerService _instance = TimerService._internal();
  factory TimerService() => _instance;
  TimerService._internal();

  Timer? _timer;
  int _currentTaskId = -1;
  int _elapsedSeconds = 0;
  int _initialElapsedSeconds = 0;
  bool _isRunning = false;
  DateTime? _startTime;

  // Getters
  int get currentTaskId => _currentTaskId;
  int get elapsedSeconds => _elapsedSeconds;
  bool get isRunning => _isRunning;
  DateTime? get startTime => _startTime;

  // Méthode pour démarrer le chronomètre pour une tâche, avec un offset initial
  void startTimer(int taskId, {int alreadyElapsedSeconds = 0}) {
    if (_isRunning && _currentTaskId == taskId) {
      // Le chronomètre est déjà en cours pour cette tâche
      return;
    }

    // Arrêter le chronomètre précédent s'il y en a un
    if (_isRunning) {
      stopTimer();
    }

    _currentTaskId = taskId;
    _isRunning = true;
    _startTime = DateTime.now();
    _initialElapsedSeconds = alreadyElapsedSeconds;
    _elapsedSeconds = 0;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      notifyListeners();
    });

    debugPrint('⏱️ Chronomètre démarré pour la tâche $taskId (offset: $_initialElapsedSeconds s)');
    notifyListeners();
  }

  // Méthode pour mettre en pause le chronomètre
  void pauseTimer() {
    if (!_isRunning) return;

    _timer?.cancel();
    _isRunning = false;
    _startTime = null;

    debugPrint('⏸️ Chronomètre mis en pause pour la tâche $_currentTaskId');
    notifyListeners();
  }

  // Méthode pour reprendre le chronomètre
  void resumeTimer() {
    if (_isRunning || _currentTaskId == -1) return;

    _isRunning = true;
    _startTime = DateTime.now();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      notifyListeners();
    });

    debugPrint('▶️ Chronomètre repris pour la tâche $_currentTaskId');
    notifyListeners();
  }

  // Méthode pour arrêter le chronomètre et retourner le temps écoulé
  int stopTimer() {
    if (!_isRunning && _currentTaskId == -1) return 0;

    _timer?.cancel();
    final elapsedMinutes = ((_elapsedSeconds + _initialElapsedSeconds) / 60).round();
    
    final taskId = _currentTaskId;
    _currentTaskId = -1;
    _isRunning = false;
    _startTime = null;
    _elapsedSeconds = 0;
    _initialElapsedSeconds = 0;

    debugPrint('⏹️ Chronomètre arrêté pour la tâche $taskId - Temps: ${elapsedMinutes}min');
    notifyListeners();

    return elapsedMinutes;
  }

  // Méthode pour vérifier si une tâche est en cours de chronométrage
  bool isTaskRunning(int taskId) {
    return _isRunning && _currentTaskId == taskId;
  }

  // Temps total écoulé (déjà passé + en cours)
  int getTotalElapsedSeconds() {
    return _initialElapsedSeconds + _elapsedSeconds;
  }

  // Méthode pour obtenir le temps écoulé formaté (live)
  String getFormattedElapsedTime() {
    final totalSeconds = getTotalElapsedSeconds();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Méthode pour nettoyer les ressources
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
} 