import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';

class DBHelper {
  static Future<Database> database() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'tasks.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, isDone INTEGER)',
        );
      },
      version: 1,
    );
  }

  static Future<void> insertTask(Task task) async {
    final db = await DBHelper.database();
    await db.insert('tasks', task.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Task>> fetchTasks() async {
    final db = await DBHelper.database();
    final maps = await db.query('tasks');
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  static Future<void> updateTask(Task task) async {
    final db = await DBHelper.database();
    await db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  static Future<void> deleteTask(int id) async {
    final db = await DBHelper.database();
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }
}
