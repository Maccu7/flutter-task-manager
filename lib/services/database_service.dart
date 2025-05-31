import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/task.dart';
import '../config/api_config.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), 'task_manager.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDb,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        dueDate TEXT NOT NULL,
        priority INTEGER NOT NULL,
        status INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT
      )
    ''');
  }

  bool _isOnline = false;
  
  Future<bool> get isOnline async {
    try {
      final result = await testApiConnection();
      _isOnline = result;
      return result;
    } catch (_) {
      _isOnline = false;
      return false;
    }
  }

  void setOnlineStatus(bool status) {
    _isOnline = status;
  }

  // Local Database Operations
  Future<int> insertTask(Task task) async {
    final db = await database;
    final localId = await db.insert('tasks', task.toMap());

    if (_isOnline) {
      try {
        final apiTask = await createTaskOnApi(task);
        // Update local task with API ID
        await db.update(
          'tasks',
          {'apiId': apiTask.id},
          where: 'id = ?',
          whereArgs: [localId],
        );
      } catch (e) {
        print('Failed to sync with API: $e');
        // Task will be synced later when online
      }
    }

    return localId;
  }

  Future<List<Task>> getTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('tasks');
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  // Modified updateTask to handle both local and API updates
  Future<int> updateTask(Task task) async {
    final db = await database;
    final result = await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );

    if (_isOnline) {
      try {
        await updateTaskOnApi(task);
      } catch (e) {
        print('Failed to sync update with API: $e');
      }
    }

    return result;
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // API Operations
  Future<List<Task>> getTasksFromApi() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/tasks'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Task.fromMap(json)).toList();
      }
      throw Exception('Failed to load tasks from API');
    } catch (e) {
      throw Exception('Failed to connect to the server');
    }
  }

  Future<Task> createTaskOnApi(Task task) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/tasks'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(task.toMap()),
      );
      if (response.statusCode == 201) {
        return Task.fromMap(json.decode(response.body));
      }
      throw Exception('Failed to create task on API');
    } catch (e) {
      throw Exception('Failed to connect to the server');
    }
  }

  Future<Task> updateTaskOnApi(Task task) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/tasks/${task.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(task.toMap()),
      );
      if (response.statusCode == 200) {
        return Task.fromMap(json.decode(response.body));
      }
      throw Exception('Failed to update task on API');
    } catch (e) {
      throw Exception('Failed to connect to the server');
    }
  }

  Future<void> deleteTaskFromApi(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/tasks/$id'),
      );
      if (response.statusCode != 204) {
        throw Exception('Failed to delete task from API');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server');
    }
  }

  // Sync Operations
  Future<void> syncTasks() async {
    if (!await isOnline) return;

    try {
      // Get local tasks
      final localTasks = await getTasks();
      
      // Get remote tasks
      final remoteTasks = await getTasksFromApi();
      
      // Update local tasks with remote data
      final db = await database;
      await db.transaction((txn) async {
        // Clear local tasks
        await txn.delete('tasks');
        
        // Insert remote tasks
        for (var task in remoteTasks) {
          await txn.insert('tasks', task.toMap());
        }
      });

      print('Sync completed successfully');
    } catch (e) {
      print('Sync failed: $e');
      throw Exception('Failed to sync tasks');
    }
  }

  // Test API Connection
  Future<bool> testApiConnection() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/tasks'));
      return response.statusCode == 200;
    } catch (e) {
      print('API Connection test failed: $e');
      return false;
    }
  }
}
