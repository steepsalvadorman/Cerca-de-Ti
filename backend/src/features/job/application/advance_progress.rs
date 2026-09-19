use std::sync::Arc;
use uuid::Uuid;

use crate::features::job::domain::{JobError, JobRepository};
use crate::features::technician::domain::TechnicianRepository;

use super::{authorize_job_access, JobAccess};

/// Moves a job along its timeline: `Confirmado → En camino → En el trabajo
/// → Finalizado`.
///
/// Only the **assigned technician** may do this. The check used to be the
/// general `authorize_job_access`, which also admits the owning client — so
/// a client could open their own tracking screen and tap through to
/// `completed` without the technician ever leaving the house, and then rate
/// the job they had just closed themselves (GAP-15). The client has no way
/// to know whether the work was done, so their confirmation belongs in a
/// separate step, not in this one.
pub struct AdvanceProgressUseCase {
    job_repo: Arc<dyn JobRepository>,
    technician_repo: Arc<dyn TechnicianRepository>,
}

impl AdvanceProgressUseCase {
    pub fn new(job_repo: Arc<dyn JobRepository>, technician_repo: Arc<dyn TechnicianRepository>) -> Self {
        Self { job_repo, technician_repo }
    }

    pub async fn execute(&self, job_request_id: Uuid, caller_id: Uuid) -> Result<(), JobError> {
        let mut job = self.job_repo
            .find_job_request_by_id(job_request_id)
            .await?
            .ok_or(JobError::JobNotFound)?;

        // Resolve the relationship first, so a client is told plainly that
        // this is not theirs to move rather than getting a confusing
        // status-transition error further down.
        let access = authorize_job_access(&job, caller_id, &self.technician_repo).await?;
        if access != JobAccess::AssignedTechnician {
            return Err(JobError::Unauthorized);
        }

        job.advance_timeline()?;

        self.job_repo.save_job_request(&job).await?;
        Ok(())
    }
}
