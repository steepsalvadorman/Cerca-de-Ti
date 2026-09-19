use async_trait::async_trait;
use uuid::Uuid;

use super::errors::TechnicianError;
use super::technician_document::TechnicianDocument;
use super::technician_profile::TechnicianProfile;
use super::tech_team::TechTeam;

#[async_trait]
pub trait TechnicianRepository: Send + Sync {
    async fn find_profile_by_user_id(&self, user_id: Uuid) -> Result<Option<TechnicianProfile>, TechnicianError>;
    // Not called by any use case yet — reserved for an upcoming "technician detail" endpoint.
    #[allow(dead_code)]
    async fn find_profile_by_id(&self, id: i32) -> Result<Option<TechnicianProfile>, TechnicianError>;
    async fn save_profile(&self, profile: &TechnicianProfile) -> Result<(), TechnicianError>;
    async fn list_profiles(&self, category: Option<&str>) -> Result<Vec<TechnicianProfile>, TechnicianError>;
    async fn list_teams(&self) -> Result<Vec<TechTeam>, TechnicianError>;
    // Not called by any use case yet — reserved for an upcoming "team detail" endpoint.
    #[allow(dead_code)]
    async fn find_team_by_id(&self, id: i32) -> Result<Option<TechTeam>, TechnicianError>;
    async fn find_documents(&self, technician_profile_id: i32) -> Result<Vec<TechnicianDocument>, TechnicianError>;

    /// Records that an upload slot was handed out: the document goes (or
    /// stays) `pending` and points at the object the device is about to
    /// write. Re-requesting a slot for the same document replaces the
    /// previous one.
    async fn start_document_upload(
        &self,
        technician_profile_id: i32,
        document_key: &str,
        storage_key: &str,
        content_type: &str,
        original_filename: Option<&str>,
    ) -> Result<(), TechnicianError>;

    /// Flips a document to `uploaded`. Returns `DocumentNotFound` when no
    /// slot was ever handed out for it, so a client cannot mark a
    /// document done without uploading anything.
    async fn confirm_document_upload(
        &self,
        technician_profile_id: i32,
        document_key: &str,
    ) -> Result<(), TechnicianError>;

    /// Recomputes `rating` and `reviews` from completed jobs that carry
    /// a score. Called after a client rates a job (GAP-16).
    async fn recalculate_rating_from_jobs(
        &self,
        technician_profile_id: i32,
    ) -> Result<(), TechnicianError>;
}
