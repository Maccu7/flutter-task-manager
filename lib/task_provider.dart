import 'package:flutter/foundation.dart';
import 'models/task.dart';
import 'services/database_service.dart';

class TaskProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _error;

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Task> get pendingTasks => _tasks.where((task) => task.status == TaskStatus.pending).toList();
  List<Task> get inProgressTasks => _tasks.where((task) => task.status == TaskStatus.inProgress).toList();
  List<Task> get completedTasks => _tasks.where((task) => task.status == TaskStatus.completed).toList();

  Future<void> loadTasks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _tasks = await _databaseService.getTasks();
      await _databaseService.syncTasks();
      _tasks = await _databaseService.getTasks();
      
    } catch (e) {
      _error = 'Failed to load tasks: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTask(Task task) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final id = await _databaseService.insertTask(task);
      final newTask = task.copyWith(id: id);
      _tasks.add(newTask);
      print('Task added  with ID: ${newTask}');
      notifyListeners();
      
      // Sync with API
      try {
        await _databaseService.createTaskOnApi(newTask);
      print('Task added  with ID: ${newTask}');

      } catch (e) {
        print('Failed to sync task with API: ${e.toString()}');
      }
    } catch (e) {
      _error = 'Failed to add task: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateTask(Task task) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _databaseService.updateTask(task);
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = task;
      }

      // Sync with API
      try {
        await _databaseService.updateTaskOnApi(task);
      } catch (e) {
        print('Failed to sync task update with API: ${e.toString()}');
      }
    } catch (e) {
      _error = 'Failed to update task: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteTask(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _databaseService.deleteTask(id);
      _tasks.removeWhere((task) => task.id == id);

      // Sync with API
      try {
        await _databaseService.deleteTaskFromApi(id);
      } catch (e) {
        print('Failed to sync task deletion with API: ${e.toString()}');
      }
    } catch (e) {
      _error = 'Failed to delete task: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> syncWithApi() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _databaseService.syncTasks();
      await loadTasks();
    } catch (e) {
      _error = 'Failed to sync with API: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
