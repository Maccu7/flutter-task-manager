import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class TaskProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService ;
  
  TaskProvider({required NotificationService notificationService})
      : _notificationService = notificationService;
      
  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _error;

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Task> get pendingTasks => _tasks.where((task) => task.status == TaskStatus.pending).toList();
  List<Task> get inProgressTasks => _tasks.where((task) => task.status == TaskStatus.inProgress).toList();
  List<Task> get completedTasks => _tasks.where((task) => task.status == TaskStatus.completed).toList();

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadTasks() async {
    try {
      _setLoading(true);
      _setError(null);
      _tasks = await _databaseService.getTasks();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load tasks: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addTask(Task task) async {
    try {
      _setLoading(true);
      _setError(null);

      final id = await _databaseService.insertTask(task);

      await _notificationService.scheduleNotification(
        title: 'Task Due: ${task.title}',
        body: task.description,
        scheduledDate: task.dueDate,
        payload: id.toString(), // optional: .toIso8601String()
      );

      try {
        await _databaseService.createTaskOnApi(task);
      } catch (e) {
        print('API sync failed: $e');
      }

      await loadTasks();
    } catch (e) {
      _setError('Failed to add task: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateTask(Task task) async {
    try {
      _setLoading(true);
      _setError(null);

      await _databaseService.updateTask(task);

      await _notificationService.cancelNotification(task.id!);
      await _notificationService.scheduleNotification(
        title: 'Task Due: ${task.title}',
        body: task.description,
        scheduledDate: task.dueDate,
        payload: task.id.toString(),
      );

      try {
        await _databaseService.updateTaskOnApi(task);
      } catch (e) {
        print('API sync failed: $e');
      }

      await loadTasks();
    } catch (e) {
      _setError('Failed to update task: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteTask(int id) async {
    try {
      _setLoading(true);
      _setError(null);

      await _databaseService.deleteTask(id);
      await _notificationService.cancelNotification(id);

      try {
        await _databaseService.deleteTaskFromApi(id);
      } catch (e) {
        print('API sync failed: $e');
      }

      await loadTasks();
    } catch (e) {
      _setError('Failed to delete task: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateTaskStatus(Task task, TaskStatus newStatus) async {
    final updatedTask = task.copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
    );
    await updateTask(updatedTask);
  }

  Future<void> updateTaskPriority(Task task, TaskPriority newPriority) async {
    final updatedTask = task.copyWith(
      priority: newPriority,
      updatedAt: DateTime.now(),
    );
    await updateTask(updatedTask);
  }

  Future<void> syncTasks() async {
    try {
      _setLoading(true);
      _setError(null);
      await _databaseService.syncTasks();
      await loadTasks();
    } catch (e) {
      _setError('Failed to sync tasks: $e');
    } finally {
      _setLoading(false);
    }
  }

  List<Task> filterTasks({
    TaskStatus? status,
    TaskPriority? priority,
    String? searchQuery,
  }) {
    return _tasks.where((task) {
      final statusMatch = status == null || task.status == status;
      final priorityMatch = priority == null || task.priority == priority;
      final searchMatch = searchQuery == null || searchQuery.isEmpty ||
          task.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          task.description.toLowerCase().contains(searchQuery.toLowerCase());

      return statusMatch && priorityMatch && searchMatch;
    }).toList();
  }

  List<Task> get overdueTasks {
    final now = DateTime.now();
    return _tasks.where((task) =>
      task.status != TaskStatus.completed &&
      task.dueDate.isBefore(now)
    ).toList();
  }

  Future<bool> testConnection() async {
    try {
      return await _databaseService.testApiConnection();
    } catch (e) {
      _setError('Connection test failed: $e');
      return false;
    }
  }
}
