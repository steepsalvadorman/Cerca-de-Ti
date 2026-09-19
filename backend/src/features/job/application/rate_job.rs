use std::sync::Arc;
use uuid::Uuid;

use crate::features::job::domain::{JobError, JobRepository};
use crate::features::technician::domain::TechnicianRepository;

pub struct RateJobInput {
    pub job_request_id: Uuid,
    pub client_id: Uuid,
    pub rating: i32,
    pub comment: Option<String>,
}

pub struct RateJobUseCase {
    job_repo: Arc<dyn JobRepository>,
    technician_repo: Arc<dyn TechnicianRepository>,
}

impl RateJobUseCase {
    pub fn new(
        job_repo: Arc<dyn JobRepository>,
        technician_repo: Arc<dyn TechnicianRepository>,
    ) -> Self {
        Self {
            job_repo,
            technician_repo,
        }
    }

    pub async fn execute(&self, input: RateJobInput) -> Result<(), JobError> {
        let mut job = self.job_repo
            .find_job_request_by_id(input.job_request_id)
            .await?
            .ok_or(JobError::JobNotFound)?;

        if job.client_id != input.client_id {
            return Err(JobError::Unauthorized);
        }

        job.rate(input.rating, input.comment)?;

        self.job_repo.save_job_request(&job).await?;

        if let Some(profile_id) = job.technician_profile_id {
            self.technician_repo
                .recalculate_rating_from_jobs(profile_id)
                .await
                .map_err(|e| JobError::Repository(e.to_string()))?;
        }

        Ok(())
    }
}
