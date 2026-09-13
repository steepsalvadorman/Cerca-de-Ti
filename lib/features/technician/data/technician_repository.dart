import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/tech_team.dart';
import '../domain/technician.dart';
import '../domain/technician_document.dart';

class ProvidersPage {
  const ProvidersPage({required this.technicians, required this.teams});

  final List<Technician> technicians;
  final List<TechTeam> teams;
}

/// A permission slip to upload one document: where to `PUT` the bytes,
/// and the key the backend filed it under.
class DocumentUploadTicket {
  const DocumentUploadTicket({required this.uploadUrl, required this.storageKey});

  final String uploadUrl;
  final String storageKey;
}

/// Talks to the `technician` feature of the backend (`/providers`,
/// `/technician/profile`, `/technician/documents`).
class TechnicianRepository {
  TechnicianRepository(this._dio);

  final Dio _dio;

  Future<ProvidersPage> getProviders({String? category}) async {
    try {
      final response = await _dio.get('/providers', queryParameters: {
        'category': ?category,
      });
      final data = response.data as Map<String, dynamic>;
      return ProvidersPage(
        technicians: (data['technicians'] as List).map((e) => Technician.fromJson(e as Map<String, dynamic>)).toList(),
        teams: (data['teams'] as List).map((e) => TechTeam.fromJson(e as Map<String, dynamic>)).toList(),
      );
    } on DioException catch (e) {
      throw apiExceptionOf(e);
    }
  }

  /// Returns `null` if the caller has no saved technician profile yet.
  Future<Technician?> getMyProfile() async {
    try {
      final response = await _dio.get('/technician/profile');
      return Technician.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final error = apiExceptionOf(e);
      if (error.isNotFound) return null;
      throw error;
    }
  }

  Future<void> saveProfile({
    required String oficio,
    required String priceLabel,
    required int coverageKm,
    required List<String> availableDays,
    required List<String> categories,
  }) async {
    try {
      await _dio.post('/technician/profile', data: {
        'oficio': oficio,
        'price_label': priceLabel,
        'coverage_km': coverageKm,
        'available_days': availableDays,
        'categories': categories,
      });
    } on DioException catch (e) {
      throw apiExceptionOf(e);
    }
  }

  Future<List<TechnicianDocumentStatus>> getDocuments() async {
    try {
      final response = await _dio.get('/technician/documents');
      return (response.data as List).map((e) => TechnicianDocumentStatus.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final error = apiExceptionOf(e);
      if (error.isNotFound) return [];
      throw error;
    }
  }

  /// Step 1 of an upload: asks the backend for a short-lived signed URL
  /// and stages the document as pending.
  Future<DocumentUploadTicket> requestUploadUrl({
    required String documentKey,
    required String contentType,
    String? originalFilename,
  }) async {
    try {
      final response = await _dio.post('/technician/documents/$documentKey/upload-url', data: {
        'content_type': contentType,
        'original_filename': ?originalFilename,
      });
      final data = response.data as Map<String, dynamic>;
      return DocumentUploadTicket(
        uploadUrl: data['upload_url'] as String,
        storageKey: data['storage_key'] as String,
      );
    } on DioException catch (e) {
      throw apiExceptionOf(e);
    }
  }

  /// Step 2: the bytes go straight to the bucket, never through our API.
  ///
  /// Deliberately a bare [Dio] rather than the shared client: the shared
  /// one attaches our `Authorization: Bearer <jwt>` to every request,
  /// and sending it to a third-party bucket would both leak the token
  /// and make the storage provider reject the request as a malformed
  /// signature.
  Future<void> uploadToBucket({
    required String uploadUrl,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      await Dio().put<void>(
        uploadUrl,
        data: Stream<List<int>>.fromIterable([bytes]),
        options: Options(
          contentType: contentType,
          headers: {Headers.contentLengthHeader: bytes.length},
        ),
      );
    } on DioException catch (_) {
      throw const ApiException(message: 'No se pudo subir el archivo. Inténtalo de nuevo.');
    }
  }

  /// Step 3: tells the backend the bytes landed, which is what flips the
  /// document to "uploaded" and can mark the technician verified.
  Future<void> confirmUpload(String documentKey) async {
    try {
      await _dio.post('/technician/documents/$documentKey/confirm');
    } on DioException catch (e) {
      throw apiExceptionOf(e);
    }
  }
}
