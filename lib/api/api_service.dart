import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://backend-integrador-7afd.onrender.com/api';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  Future<http.Response> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');
    print('Intentando login en: $url');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    print('Respuesta Login [${response.statusCode}]: ${response.body}');
    return response;
  }

  Future<http.Response> register(Map<String, dynamic> userData) async {
    final url = Uri.parse('$baseUrl/usuarios');
    print('Intentando registro en: $url');
    print('Datos: ${jsonEncode(userData)}');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(userData),
    );
    print('Respuesta Registro [${response.statusCode}]: ${response.body}');
    return response;
  }

  Future<http.Response> getMe() async {
    final token = await getToken();
    final url = Uri.parse('$baseUrl/usuarios/me');
    print('GET Me: $url');
    print('DEBUG: Enviando Token: ${token ?? "NULL"}');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${token ?? ""}',
      },
    );
    print('Response [getMe]: ${response.statusCode}');
    return response;
  }

  // Generic GET method for other entities
  Future<http.Response> getEntity(String entityPath) async {
    final token = await getToken();
    final url = Uri.parse('$baseUrl/$entityPath');
    
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    print('GET Entity: $url');
    final response = await http.get(url, headers: headers);
    print('Response [$entityPath]: ${response.statusCode}');
    return response;
  }

  // Generic POST method for other entities
  Future<http.Response> registerEntity(String entityPath, Map<String, dynamic> data) async {
    final token = await getToken();
    final url = Uri.parse('$baseUrl/$entityPath');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${token ?? ""}',
      },
      body: jsonEncode(data),
    );
    return response;
  }

  // Generic PUT method for updating entities
  Future<http.Response> updateEntity(String entityPath, int id, Map<String, dynamic> data) async {
    final token = await getToken();
    final url = Uri.parse('$baseUrl/$entityPath/$id');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${token ?? ""}',
      },
      body: jsonEncode(data),
    );
    return response;
  }

  // Generic DELETE method
  Future<http.Response> deleteEntity(String entityPath, int id) async {
    final token = await getToken();
    final url = Uri.parse('$baseUrl/$entityPath/$id');
    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${token ?? ""}',
      },
    );
    return response;
  }
}
