import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // API Configuration
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api';
    } else {
      return 'http://localhost:3000/api';
    }
  }

  // API Endpoints
  static const String tasksEndpoint = '/tasks';

  // Headers
  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        // if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      };
}
