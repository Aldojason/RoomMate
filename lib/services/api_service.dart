import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://roommate-bw1x.onrender.com';

  // ============================================================
  // AUTH HEADERS
  // ============================================================

  static Future<Map<String, String>> authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ============================================================
  // TEST CONNECTION
  // ============================================================

  static Future<Map<String, dynamic>> testConnection() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/test'),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data;
    }

    throw Exception(
      data['message'] ?? 'Failed to connect to RoomMate backend',
    );
  }

  // ============================================================
  // LOGIN
  // ============================================================

  static Future<Map<String, dynamic>> login(
    String emailOrUsername,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'emailOrUsername': emailOrUsername,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('token', data['token']);
      await prefs.setString('userId', data['user']['id']);
      await prefs.setString('userName', data['user']['name']);
      await prefs.setString('userEmail', data['user']['email']);
      await prefs.setString('userTeam', data['user']['team']);
      await prefs.setString('userRole', data['user']['role']);

      return data;
    }

    throw Exception(data['message'] ?? 'Login failed');
  }

  // ============================================================
  // CURRENT TRASH PERSON
  // ============================================================

  static Future<Map<String, dynamic>> getCurrentTrashPerson() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/tasks/rotation/trash/current'),
      headers: await authHeaders(),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }

    throw Exception(
      data['message'] ?? 'Failed to get current trash person',
    );
  }

  // ============================================================
  // CURRENT WATER PERSON
  // ============================================================

  static Future<Map<String, dynamic>> getCurrentWaterPerson() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/tasks/rotation/water/current'),
      headers: await authHeaders(),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }

    throw Exception(
      data['message'] ?? 'Failed to get current water person',
    );
  }

  // ============================================================
  // COMPLETE TRASH TASK
  // ============================================================

  static Future<Map<String, dynamic>> completeTask(
    String taskId,
    String proofImage,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/tasks/$taskId/complete'),
      headers: await authHeaders(),
      body: jsonEncode({
        'proofImage': proofImage,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }

    throw Exception(
      data['message'] ?? 'Failed to complete trash task',
    );
  }

  // ============================================================
  // REPORT WATER EMPTY
  // ============================================================

  static Future<Map<String, dynamic>> reportWaterEmpty() async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/tasks/rotation/water/report'),
      headers: await authHeaders(),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        data['success'] == true) {
      return data;
    }

    throw Exception(
      data['message'] ?? 'Failed to report water empty',
    );
  }

  // ============================================================
  // COMPLETE WATER TASK
  // ============================================================

  static Future<Map<String, dynamic>> completeWaterTask(
    String taskId,
    String proofImage,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/tasks/water/$taskId/complete'),
      headers: await authHeaders(),
      body: jsonEncode({
        'proofImage': proofImage,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }

    throw Exception(
      data['message'] ?? 'Failed to complete water task',
    );
  }

  // ============================================================
  // MARK WATER TASK AS MISSED
  // ============================================================

  static Future<Map<String, dynamic>> markWaterMissed(
    String taskId,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/tasks/water/$taskId/miss'),
      headers: await authHeaders(),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }

    throw Exception(
      data['message'] ?? 'Failed to mark water task as missed',
    );
  }

  // ============================================================
  // MARK TRASH TASK AS MISSED
  // ============================================================

  static Future<Map<String, dynamic>> markTrashMissed(
    String taskId,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/tasks/$taskId/miss'),
      headers: await authHeaders(),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }

    throw Exception(
      data['message'] ?? 'Failed to mark trash task as missed',
    );
  }

  // ============================================================
// GET ALL TASKS — HISTORY
// ============================================================

static Future<List<dynamic>> getAllTasks() async {
  final response = await http.get(
    Uri.parse('$baseUrl/api/tasks'),
    headers: await authHeaders(),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode == 200 && data['success'] == true) {
    return data['tasks'] ?? [];
  }

  throw Exception(
    data['message'] ?? 'Failed to get tasks',
  );
}

// ============================================================
// GET SUNDAY CLEANING
// ============================================================

static Future<Map<String, dynamic>> getSundayCleaning(
  String sundayDate,
) async {
  final response = await http.get(
    Uri.parse('$baseUrl/api/sunday-cleaning/$sundayDate'),
    headers: await authHeaders(),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode == 200 && data['success'] == true) {
    return data;
  }

  throw Exception(
    data['message'] ?? 'Failed to get Sunday cleaning',
  );
}

// ============================================================
// CREATE SUNDAY CLEANING
// ============================================================

static Future<Map<String, dynamic>> createSundayCleaning(
  String sundayDate,
) async {
  final response = await http.post(
    Uri.parse('$baseUrl/api/sunday-cleaning/create'),
    headers: await authHeaders(),
    body: jsonEncode({
      'sundayDate': sundayDate,
    }),
  );

  final data = jsonDecode(response.body);

  if ((response.statusCode == 200 || response.statusCode == 201) &&
      data['success'] == true) {
    return data;
  }

  throw Exception(
    data['message'] ?? 'Failed to create Sunday cleaning',
  );
}

// ============================================================
// COMPLETE HOUSE CLEANING
// ============================================================

static Future<Map<String, dynamic>> completeHouseCleaning(
  String sundayDate,
  String proofImage,
) async {
  final response = await http.post(
    Uri.parse(
      '$baseUrl/api/sunday-cleaning/$sundayDate/house/complete',
    ),
    headers: await authHeaders(),
    body: jsonEncode({
      'proofImage': proofImage,
    }),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode == 200 && data['success'] == true) {
    return data;
  }

  throw Exception(
    data['message'] ?? 'Failed to complete house cleaning',
  );
}

// ============================================================
// COMPLETE BATHROOM CLEANING
// ============================================================

static Future<Map<String, dynamic>> completeBathroomCleaning(
  String sundayDate,
  String proofImage,
) async {
  final response = await http.post(
    Uri.parse(
      '$baseUrl/api/sunday-cleaning/$sundayDate/bathroom/complete',
    ),
    headers: await authHeaders(),
    body: jsonEncode({
      'proofImage': proofImage,
    }),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode == 200 && data['success'] == true) {
    return data;
  }

  throw Exception(
    data['message'] ?? 'Failed to complete bathroom cleaning',
  );
}

// ============================================================
// COMPLETE SUNDAY TRASH
// ============================================================

static Future<Map<String, dynamic>> completeSundayTrash(
  String sundayDate,
  String proofImage,
) async {
  final response = await http.post(
    Uri.parse(
      '$baseUrl/api/sunday-cleaning/$sundayDate/trash/complete',
    ),
    headers: await authHeaders(),
    body: jsonEncode({
      'proofImage': proofImage,
    }),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode == 200 && data['success'] == true) {
    return data;
  }

  throw Exception(
    data['message'] ?? 'Failed to complete Sunday trash',
  );
}

}