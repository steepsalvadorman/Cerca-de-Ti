use std::sync::Arc;
use uuid::Uuid;

use crate::features::job::domain::{JobError, JobRepository, JobStatus};
use crate::features::technician::domain::TechnicianRepository;

pub struct SubmitOfferInput {
    pub job_request_id: Uuid,
    pub technician_user_id: Uuid,
    pub price: i32,
    pub eta: String,
}

pub struct SubmitOfferUseCase {
    job_repo: Arc<dyn JobRepository>,
    technician_repo: Arc<dyn TechnicianRepository>,
}

impl SubmitOfferUseCase {
    pub fn new(
        job_repo: Arc<dyn JobRepository>,
        technician_repo: Arc<dyn TechnicianRepository>,
    ) -> Self {
        Self { job_repo, technician_repo }
    }

    pub async fn execute(&self, input: SubmitOfferInput) -> Result<(), JobError> {
        let profile = self.technician_repo
            .find_profile_by_user_id(input.technician_user_id)
            .await
            .map_err(|e| JobError::Repository(e.to_string()))?
            .ok_or(JobError::Unauthorized)?; // Only registered technicians can bid

        if input.price <= 0 {
            return Err(JobError::InvalidOffer);
        }
        if input.eta.trim().is_empty() {
            return Err(JobError::InvalidOffer);
        }

        let job = self.job_repo
            .find_job_request_by_id(input.job_request_id)
            .await?
            .ok_or(JobError::JobNotFound)?;

        // Only an open auction takes bids: not a direct hire, not a job
        // that already has its technician, not one already under way.
        if job.job_kind != "bidding" || job.status != JobStatus::Pending {
            return Err(JobError::InvalidStatusTransition);
        }
        if job.technician_profile_id.is_some() {
            return Err(JobError::InvalidStatusTransition);
        }

        // The database enforces this too (UNIQUE in migration 0009); this
        // check is what turns the constraint violation into a clear error
        // instead of a 500.
        let already_bid = self
            .job_repo
            .find_offers_by_job_id(input.job_request_id)
            .await?
            .iter()
            .any(|offer| offer.technician_profile_id == profile.id);
        if already_bid {
            return Err(JobError::OfferAlreadySubmitted);
        }

        self.job_repo
            .add_job_offer(input.job_request_id, profile.id, input.price, input.eta)
            .await?;

        Ok(())
    }
}
