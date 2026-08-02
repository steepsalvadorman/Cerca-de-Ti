import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../domain/technician_document.dart';
import 'providers_controller.dart';

part 'tech_docs_controller.g.dart';

/// File types the backend's allowlist accepts. Identity papers arrive
/// either as a photo or as a PDF downloaded from a government portal.
const _allowedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'pdf'];

const _contentTypes = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'pdf': 'application/pdf',
};

/// Large enough for a phone photo of a document, small enough that a
/// technician on mobile data isn't stuck uploading for minutes.
const _maxFileSizeBytes = 10 * 1024 * 1024;

/// The signed-in technician's document checklist
/// (`GET /technician/documents`, plus the upload-url/confirm pair).
@riverpod
class TechDocsController extends _$TechDocsController {
  @override
  Future<List<TechnicianDocumentStatus>> build() => ref.read(technicianRepositoryProvider).getDocuments();

  /// Picks a file and runs the three-step upload. Returns `false` when
  /// the technician backed out of the file picker, so the caller can
  /// tell "cancelled" apart from "uploaded".
  Future<bool> upload(String documentKey) async {
    final selection = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      // The bytes are needed anyway to PUT them, and this is the only
      // way to get them on web.
      withData: true,
    );

    final file = selection?.files.singleOrNull;
    if (file == null) return false;

    final bytes = file.bytes;
    final contentType = _contentTypes[file.extension?.toLowerCase()];
    if (bytes == null || contentType == null) {
      throw const ApiException(message: 'Formato no admitido. Sube una foto (JPG/PNG) o un PDF.');
    }
    if (bytes.length > _maxFileSizeBytes) {
      throw const ApiException(message: 'El archivo supera los 10 MB. Sube una versión más liviana.');
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _upload(documentKey: documentKey, bytes: bytes, contentType: contentType, filename: file.name);
      return ref.read(technicianRepositoryProvider).getDocuments();
    });

    // `guard` swallowed the error into the state; rethrow so the screen
    // can surface it instead of silently showing a stale checklist.
    if (state.hasError) throw state.error!;
    return true;
  }

  Future<void> _upload({
    required String documentKey,
    required Uint8List bytes,
    required String contentType,
    required String filename,
  }) async {
    final repository = ref.read(technicianRepositoryProvider);

    final ticket = await repository.requestUploadUrl(
      documentKey: documentKey,
      contentType: contentType,
      originalFilename: filename,
    );
    await repository.uploadToBucket(
      uploadUrl: ticket.uploadUrl,
      bytes: bytes,
      contentType: contentType,
    );
    // Only now does the document count as uploaded: if the app dies
    // mid-upload, the slot stays pending rather than claiming a file
    // that never arrived.
    await repository.confirmUpload(documentKey);
  }
}
