import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/reimbursement.dart';

/// Error con un mensaje listo para mostrar al usuario.
class ApiException implements Exception {
  const ApiException(this.message, {this.isConnectionError = false});

  final String message;

  /// true cuando no hubo respuesta del servidor (caído, sin red, timeout).
  final bool isConnectionError;

  @override
  String toString() => message;
}

class ReimbursementApiService {
  ReimbursementApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUri = Uri.parse('${baseUrl ?? ApiConfig.baseUrl}${ApiConfig.reimbursementsPath}');

  final http.Client _client;
  final Uri _baseUri;

  Future<List<Reimbursement>> getMyReimbursements(String employeeName) async {
    final uri = _baseUri.replace(queryParameters: {'employeeName': employeeName});
    final body = await _send(() => _client.get(uri, headers: _headers));

    if (body is! List) {
      throw const ApiException('La respuesta del servidor no tiene el formato esperado.');
    }
    return _parse(() => body.map((item) => Reimbursement.fromJson(item as Map<String, dynamic>)).toList());
  }

  Future<Reimbursement> createReimbursement({
    required String employeeName,
    required int amount,
    required String category,
    required String description,
  }) async {
    final payload = jsonEncode({
      'employeeName': employeeName,
      'amount': amount,
      'category': category,
      'description': description,
    });
    final body = await _send(() => _client.post(_baseUri, headers: _headers, body: payload));

    if (body is! Map<String, dynamic>) {
      throw const ApiException('La respuesta del servidor no tiene el formato esperado.');
    }
    return _parse(() => Reimbursement.fromJson(body));
  }

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Ejecuta la petición y traduce cualquier fallo a [ApiException].
  Future<Object?> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(ApiConfig.timeout);
    } on TimeoutException {
      throw const ApiException(
        'El servidor tardó demasiado en responder. Intenta de nuevo.',
        isConnectionError: true,
      );
    } on SocketException {
      throw const ApiException('No se pudo conectar con el servidor.', isConnectionError: true);
    } on http.ClientException {
      throw const ApiException('No se pudo conectar con el servidor.', isConnectionError: true);
    }

    final decoded = _tryDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded == null) {
        throw const ApiException('La respuesta del servidor no es válida.');
      }
      return decoded;
    }

    // Errores esperados de la API: {"message": "..."}
    if (response.statusCode < 500 && decoded is Map && decoded['message'] is String) {
      throw ApiException(decoded['message'] as String);
    }
    throw ApiException('Error del servidor (${response.statusCode}). Intenta más tarde.');
  }

  static Object? _tryDecode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  static T _parse<T>(T Function() parse) {
    try {
      return parse();
    } on FormatException catch (e) {
      throw ApiException(e.message);
    } on TypeError {
      throw const ApiException('La respuesta del servidor no tiene el formato esperado.');
    }
  }
}
