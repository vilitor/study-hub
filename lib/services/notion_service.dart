import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:study_hub/models/study_log.dart';
import 'package:study_hub/models/notion_schema.dart';
import 'package:study_hub/services/storage_service.dart';

/// Service responsible for integration with the Notion API.
class NotionService {
  final StorageService _storage = StorageService();
  static const String _notionApiBaseUrl = 'https://api.notion.com/v1';
  static const String _notionVersion = '2022-06-28';

  /// Prepares authentication headers for Notion requests.
  Future<Map<String, String>?> _getHeaders() async {
    final token = await _storage.getNotionToken();
    if (token == null || token.isEmpty) return null;

    return {
      'Authorization': 'Bearer $token',
      'Notion-Version': _notionVersion,
      'Content-Type': 'application/json',
    };
  }

  /// Creates a new study log entry in the configured Notion database.
  /// Returns the page ID on success, or null on failure.
  Future<String?> createStudyLog(StudyLog log) async {
    try {
      final headers = await _getHeaders();
      final databaseId = await _storage.getNotionDatabaseId();

      if (headers == null || databaseId == null || databaseId.isEmpty) {
        debugPrint('[NotionService] Token or Database ID not configured.');
        return null;
      }

      final payload = log.toNotionPayload(databaseId);

      final response = await http.post(
        Uri.parse('$_notionApiBaseUrl/pages'),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        return body['id'] as String?;
      } else {
        debugPrint('[NotionService] Failed to create page. Status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('[NotionService] Exception during log creation: $e');
      return null;
    }
  }

  /// Archives (soft-deletes) a Notion page by its ID.
  Future<bool> archivePage(String pageId) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) return false;

      final response = await http.patch(
        Uri.parse('$_notionApiBaseUrl/pages/$pageId'),
        headers: headers,
        body: jsonEncode({'archived': true}),
      );

      if (response.statusCode == 200) {
        debugPrint('[NotionService] ✅ Page $pageId archived.');
        return true;
      } else {
        debugPrint('[NotionService] ❌ Failed to archive page. Status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('[NotionService] Exception archiving page: $e');
      return false;
    }
  }

  /// Validates the connection by attempting to retrieve database metadata.
  Future<bool> testConnection(String token, String databaseId) async {
    try {
      final headers = {
        'Authorization': 'Bearer $token',
        'Notion-Version': _notionVersion,
      };

      final response = await http.get(
        Uri.parse('$_notionApiBaseUrl/databases/$databaseId'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[NotionService] Connection test failed: $e');
      return false;
    }
  }

  /// Retrieves the Notion database structure (Schema).
  Future<NotionDatabaseSchema?> fetchDatabaseSchema(String databaseId) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) return null;

      final response = await http.get(
        Uri.parse('$_notionApiBaseUrl/databases/$databaseId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final decodedBody = jsonDecode(response.body);
        return NotionDatabaseSchema.fromJson(decodedBody);
      } else {
        debugPrint('[NotionService] Schema fetch failed. Status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('[NotionService] Exception during schema fetch: $e');
      return null;
    }
  }
}
