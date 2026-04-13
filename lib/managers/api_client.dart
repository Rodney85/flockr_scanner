import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  Future<Map<String, String?>> getCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('api_base_url');
    final token = prefs.getString('api_token');
    return {'baseUrl': baseUrl, 'token': token};
  }

  /// Sends a scan to the server.
  /// Returns a map with 'found' (bool) and 'animal_name' (String?).
  /// Throws an exception if the network call fails or credentials are missing.
  Future<Map<String, dynamic>> sendScan(String epc) async {
    final creds = await getCredentials();
    final baseUrl = creds['baseUrl'];
    final token = creds['token'];

    if (baseUrl == null || baseUrl.isEmpty || token == null || token.isEmpty) {
      throw Exception('API Configuration missing. Please update Settings.');
    }

    final url = Uri.parse('$baseUrl/api/rfid/scan');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'tag_id': epc}),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'found': data['found'] ?? false,
        'animalName': data['animal']['name'],
      };
    } else {
      throw Exception('Server returned ${response.statusCode}');
    }
  }

  /// Registers a new animal for an unrecognized tag.
  Future<void> registerAnimal(String epc, String name, String species) async {
    final creds = await getCredentials();
    final baseUrl = creds['baseUrl'];
    final token = creds['token'];

    if (baseUrl == null || baseUrl.isEmpty || token == null || token.isEmpty) {
      throw Exception('API Configuration missing. Please update Settings.');
    }

    final url = Uri.parse('$baseUrl/api/animals');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'tag_id': epc,
        'name': name,
        'species': species,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Registration failed: Server returned ${response.statusCode}');
    }
  }
}
