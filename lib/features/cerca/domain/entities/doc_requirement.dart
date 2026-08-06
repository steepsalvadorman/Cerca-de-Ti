enum DocStatus { uploaded, pending }

/// One document a technician can upload to get verified (e.g. "Cédula").
class DocRequirement {
  const DocRequirement({
    required this.key,
    required this.label,
    required this.mono,
    this.mandatory = true,
  });

  final String key;
  final String label;
  final String mono;

  /// Whether verification waits for this one. Must agree with
  /// `MANDATORY_DOCUMENT_KEYS` in the backend
  /// (`technician/domain/technician_document.rs`) — counting an optional
  /// document toward progress left technicians stuck at "3 de 4" while
  /// the server had already verified them.
  final bool mandatory;
}
