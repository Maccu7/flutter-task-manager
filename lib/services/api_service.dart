import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/task.dart';

class ApiService {
  String? _token;

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    _token = token;
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    _token = null;
  }

  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // Auth
  Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse(ApiConfig.baseUrl + '/auth/login'),
      headers: headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await saveToken(data['token']);
      return;
    }
    String message = 'Login failed';
    try {
      final data = jsonDecode(response.body);
      message = data['error'] ?? message;
    } catch (_) {}
    throw Exception(message);
  }

  Future<void> register(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse(ApiConfig.baseUrl + '/auth/register'),
      headers: headers,
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      await saveToken(data['token']);
      return;
    }
    String message = 'Registration failed';
    try {
      final data = jsonDecode(response.body);
      message = data['error'] ?? message;
    } catch (_) {}
    throw Exception(message);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') != null;
  }

  // Tasks CRUD
  Future<List<Task>> fetchTasks() async {
    await loadToken();
    final response = await http.get(
      Uri.parse(ApiConfig.baseUrl + ApiConfig.tasksEndpoint),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Use Task.fromApi for backend mapping
      return (data['tasks'] as List).map((e) => Task.fromApi(e)).toList();
    }
    throw Exception('Failed to load tasks');
  }

  Future<Task> createTask(Task task) async {
    await loadToken();
    final response = await http.post(
      Uri.parse(ApiConfig.baseUrl + ApiConfig.tasksEndpoint),
      headers: headers,
      body: jsonEncode(task.toApi()),
    );
    if (response.statusCode == 201) {
      return Task.fromApi(jsonDecode(response.body));
    }
    throw Exception('Failed to create task');
  }

  Future<Task> updateTask(Task task) async {
    await loadToken();
    final response = await http.patch(
      Uri.parse(ApiConfig.baseUrl + ApiConfig.tasksEndpoint + '/${task.id}'),
      headers: headers,
      body: jsonEncode(task.toApi()),
    );
    if (response.statusCode == 200) {
      return Task.fromApi(jsonDecode(response.body));
    }
    throw Exception('Failed to update task');
  }

  Future<void> deleteTask(int id) async {
    await loadToken();
    final response = await http.delete(
      Uri.parse(ApiConfig.baseUrl + ApiConfig.tasksEndpoint + '/$id'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete task');
    }
  }
}
