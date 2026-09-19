use std::sync::Arc;
use uuid::Uuid;

use crate::features::job::domain::{JobError, JobRepository};

/// Longest cancellation note accepted. Free text the client renders
/// verbatim, so it is bounded like every other input (GAP-02).
const MAX_REASON_LEN: usize = 300;

pub struct CancelJobInput {
    pub job_request_id: Uuid,
    pub client_id: Uuid,
    pub reason: Option<String>,
}

/// Lets the client who posted a job end it.
///
/// `cancelled` has been in the state machine and in the database CHECK
/// since the beginning, but nothing ever wrote it — so a client whose
/// auction drew no bids, or who no longer wanted the work, had no way out
/// and the job stayed open indefinitely (GAP-19).
///
/// Only the owning client, and only while the job is still open or under
/// way. Technicians cannot cancel: walking away from a job you agreed to
/// is an abandonment, which needs its own rule and its own consequences
/// for a technician's record, not a status flip by the person leaving.
pub struct CancelJobUseCase {
    job_repo: Arc<dyn JobRepository>,
}

impl CancelJobUseCase {
    pub fn new(job_repo: Arc<dyn JobRepository>) -> Self {
        Self { job_repo }
    }

    pub async fn execute(&self, input: CancelJobInput) -> Result<(), JobError> {
        let mut job = self
            .job_repo
            .find_job_request_by_id(input.job_request_id)
            .await?
            .ok_or(JobError::JobNotFound)?;

        if job.client_id != input.client_id {
            return Err(JobError::Unauthorized);
        }

        let reason = input.reason.map(|reason| {
            let trimmed = reason.trim();
            trimmed.chars().take(MAX_REASON_LEN).collect::<String>()
        });

        // The domain decides which states are cancellable; this keeps the
        // rule in one place instead of duplicating a status check here.
        job.cancel(input.client_id, reason)?;

        self.job_repo.save_job_request(&job).await?;
        Ok(())
    }
}
