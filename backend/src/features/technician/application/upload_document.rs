use std::sync::Arc;
use uuid::Uuid;

use crate::features::technician::domain::{
    is_valid_document_key, DocStatus, TechnicianError, TechnicianProfile, TechnicianRepository,
    MANDATORY_DOCUMENT_KEYS,
};

use super::ports::ObjectStorage;

/// What a verification document may be. Identity papers arrive either as
/// a photo or as a PDF downloaded from a government portal, and nothing
/// else has a reason to end up in this bucket.
const ALLOWED_CONTENT_TYPES: [(&str, &str); 4] = [
    ("image/jpeg", "jpg"),
    ("image/png", "png"),
    ("image/webp", "webp"),
    ("application/pdf", "pdf"),
];

/// Largest verification document this server accepts. Enforced against
/// what is actually in the bucket, not against what the client claims: the
/// signed URL cannot carry a size limit, so without this the only bound
/// was the one in the Flutter app (`tech_docs_controller.dart`), which any
/// other client is free to ignore (GAP-62).
pub const MAX_DOCUMENT_BYTES: u64 = 10 * 1024 * 1024;

fn extension_for(content_type: &str) -> Option<&'static str> {
    ALLOWED_CONTENT_TYPES
        .iter()
        .find(|(allowed, _)| *allowed == content_type)
        .map(|(_, extension)| *extension)
}

/// The leading bytes that identify each allowed format.
///
/// A declared `Content-Type` is a claim by the client; these are what the
/// file actually is. Without checking them, a URL obtained for
/// `image/jpeg` will happily accept an HTML document — which the bucket
/// then serves back with the recorded type, so any later inline rendering
/// of a "photo" is stored XSS (GAP-63).
fn looks_like(content_type: &str, head: &[u8]) -> bool {
    match content_type {
        "image/jpeg" => head.starts_with(&[0xFF, 0xD8, 0xFF]),
        "image/png" => head.starts_with(&[0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A]),
        // RIFF....WEBP
        "image/webp" => head.len() >= 12 && head.starts_with(b"RIFF") && &head[8..12] == b"WEBP",
        "application/pdf" => head.starts_with(b"%PDF-"),
        _ => false,
    }
}

/// How many leading bytes `looks_like` needs for the longest signature.
const SNIFF_BYTES: usize = 12;

pub struct CreateDocumentUploadUrlInput {
    pub user_id: Uuid,
    pub document_key: String,
    pub content_type: String,
    pub original_filename: Option<String>,
}

pub struct CreateDocumentUploadUrlOutput {
    pub upload_url: String,
    pub storage_key: String,
}

/// Hands the technician's device a short-lived URL to upload one
/// document straight to the bucket, and records the slot as `pending`
/// until [`ConfirmDocumentUploadUseCase`] hears the bytes landed.
pub struct CreateDocumentUploadUrlUseCase {
    technician_repo: Arc<dyn TechnicianRepository>,
    storage: Arc<dyn ObjectStorage>,
}

impl CreateDocumentUploadUrlUseCase {
    pub fn new(technician_repo: Arc<dyn TechnicianRepository>, storage: Arc<dyn ObjectStorage>) -> Self {
        Self { technician_repo, storage }
    }

    pub async fn execute(
        &self,
        input: CreateDocumentUploadUrlInput,
    ) -> Result<CreateDocumentUploadUrlOutput, TechnicianError> {
        if !is_valid_document_key(&input.document_key) {
            return Err(TechnicianError::InvalidDocumentKey(input.document_key));
        }

        let extension = extension_for(&input.content_type)
            .ok_or_else(|| TechnicianError::InvalidContentType(input.content_type.clone()))?;

        let profile = self
            .technician_repo
            .find_profile_by_user_id(input.user_id)
            .await?
            .ok_or(TechnicianError::TechnicianNotFound)?;

        // A fresh UUID per attempt, so re-uploading a document never
        // overwrites the object a previous attempt is still reading, and
        // the key can't be guessed from the technician's id alone.
        let storage_key = format!(
            "technicians/{}/{}/{}.{extension}",
            profile.id,
            input.document_key,
            Uuid::new_v4()
        );

        let upload_url = self
            .storage
            .presign_put(&storage_key, &input.content_type, MAX_DOCUMENT_BYTES)?;

        self.technician_repo
            .start_document_upload(
                profile.id,
                &input.document_key,
                &storage_key,
                &input.content_type,
                input.original_filename.as_deref(),
            )
            .await?;

        Ok(CreateDocumentUploadUrlOutput { upload_url, storage_key })
    }
}

pub struct ConfirmDocumentUploadInput {
    pub user_id: Uuid,
    pub document_key: String,
}

/// Marks a document as uploaded once the device reports the `PUT` to the
/// bucket succeeded, then re-checks whether the technician now qualifies
/// as verified.
///
/// "Once the device reports" used to be the whole story, and that was the
/// hole: `confirm` flipped a row to `uploaded` on the client's word, and
/// three such calls — with an empty bucket — were enough to be verified
/// (GAP-30). The bucket is now asked what is actually there, and the
/// answer has to match what was declared before any state changes.
pub struct ConfirmDocumentUploadUseCase {
    technician_repo: Arc<dyn TechnicianRepository>,
    storage: Arc<dyn ObjectStorage>,
}

impl ConfirmDocumentUploadUseCase {
    pub fn new(
        technician_repo: Arc<dyn TechnicianRepository>,
        storage: Arc<dyn ObjectStorage>,
    ) -> Self {
        Self { technician_repo, storage }
    }

    pub async fn execute(&self, input: ConfirmDocumentUploadInput) -> Result<(), TechnicianError> {
        if !is_valid_document_key(&input.document_key) {
            return Err(TechnicianError::InvalidDocumentKey(input.document_key));
        }

        let profile = self
            .technician_repo
            .find_profile_by_user_id(input.user_id)
            .await?
            .ok_or(TechnicianError::TechnicianNotFound)?;

        let documents = self.technician_repo.find_documents(profile.id).await?;
        let document = documents
            .iter()
            .find(|doc| doc.document_key == input.document_key)
            // No row at all means no upload slot was ever handed out,
            // which is the only way a client could claim an upload
            // finished without one having started.
            .ok_or(TechnicianError::DocumentNotFound)?;

        let storage_key = document
            .storage_key
            .clone()
            .ok_or(TechnicianError::DocumentNotFound)?;

        self.verify_object(&storage_key, document.content_type.as_deref())
            .await?;

        self.technician_repo
            .confirm_document_upload(profile.id, &input.document_key)
            .await?;

        self.refresh_verification(profile).await
    }

    /// Confirms the bucket holds an object that is plausibly the file the
    /// client said it would upload.
    ///
    /// Three independent things are checked, because each closes a
    /// different way of lying: that the object exists at all (a client can
    /// request a URL and simply never `PUT`), that it is within the size
    /// cap (the signed URL cannot carry `content-length-range`, so the
    /// limit lives here), and that the bytes really are the declared
    /// format (otherwise an `image/jpeg` slot accepts an HTML file, which
    /// the bucket later serves back under that label).
    async fn verify_object(
        &self,
        storage_key: &str,
        declared_content_type: Option<&str>,
    ) -> Result<(), TechnicianError> {
        let metadata = self
            .storage
            .head_object(storage_key)
            .await?
            // No object: the client asked for a slot and never used it.
            .ok_or(TechnicianError::DocumentNotFound)?;

        if metadata.size_bytes == 0 {
            return Err(TechnicianError::DocumentContentMismatch(
                "the uploaded file is empty".to_string(),
            ));
        }

        if metadata.size_bytes > MAX_DOCUMENT_BYTES {
            return Err(TechnicianError::DocumentTooLarge {
                size_bytes: metadata.size_bytes,
                limit_bytes: MAX_DOCUMENT_BYTES,
            });
        }

        let declared = declared_content_type.unwrap_or_default();

        // The bucket's own view of the type, when it reports one, has to
        // agree with what was declared. Providers that echo the PUT's
        // Content-Type will agree trivially; a disagreement means the two
        // sides saw different requests.
        if let Some(actual) = metadata.content_type.as_deref() {
            if !actual.is_empty() && actual != declared {
                return Err(TechnicianError::DocumentContentMismatch(format!(
                    "declared {declared}, bucket reports {actual}"
                )));
            }
        }

        // The decisive check: what the bytes are, which no client controls.
        let head = self
            .storage
            .read_prefix(storage_key, SNIFF_BYTES)
            .await?
            .ok_or(TechnicianError::DocumentNotFound)?;

        if !looks_like(declared, &head) {
            return Err(TechnicianError::DocumentContentMismatch(format!(
                "the file content is not a valid {declared}"
            )));
        }

        Ok(())
    }

    /// A technician counts as verified once every mandatory document has
    /// a confirmed file. `seguro` is optional and deliberately excluded.
    async fn refresh_verification(&self, profile: TechnicianProfile) -> Result<(), TechnicianError> {
        let documents = self.technician_repo.find_documents(profile.id).await?;

        let all_mandatory_uploaded = MANDATORY_DOCUMENT_KEYS.iter().all(|required| {
            documents
                .iter()
                .any(|doc| doc.document_key == *required && doc.status == DocStatus::Uploaded)
        });

        if all_mandatory_uploaded && !profile.is_verified {
            let mut verified = profile;
            verified.is_verified = true;
            self.technician_repo.save_profile(&verified).await?;
        }

        Ok(())
    }
}
