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

fn extension_for(content_type: &str) -> Option<&'static str> {
    ALLOWED_CONTENT_TYPES
        .iter()
        .find(|(allowed, _)| *allowed == content_type)
        .map(|(_, extension)| *extension)
}

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

        let upload_url = self.storage.presign_put(&storage_key, &input.content_type)?;

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
pub struct ConfirmDocumentUploadUseCase {
    technician_repo: Arc<dyn TechnicianRepository>,
}

impl ConfirmDocumentUploadUseCase {
    pub fn new(technician_repo: Arc<dyn TechnicianRepository>) -> Self {
        Self { technician_repo }
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

        // Fails when no upload slot was ever handed out for this
        // document, which is the only way a client could claim an upload
        // finished without one having started.
        self.technician_repo
            .confirm_document_upload(profile.id, &input.document_key)
            .await?;

        self.refresh_verification(profile).await
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
