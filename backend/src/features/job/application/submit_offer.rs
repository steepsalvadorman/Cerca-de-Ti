use std::sync::Arc;
use uuid::Uuid;

use crate::features::job::domain::{JobError, JobRepository, JobStatus};
use crate::features::technician::domain::TechnicianRepository;

/// Largest offer the server accepts, in soles.
///
/// `price` is an `i32`, so without a ceiling a client could post
/// `2147483647` and poison the client's bidding screen — and any later
/// arithmetic on it. The bound is deliberately loose: it exists to reject
/// the absurd, not to second-guess a quote (GAP-06).
const MAX_OFFER_PRICE: i32 = 1_000_000;

/// Longest estimate text accepted. Bids carry a free-text ETA that the
/// client renders verbatim; unbounded text is a storage and payload
/// problem (GAP-02).
const MAX_ETA_LEN: usize = 60;

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

        // Before anything else: an unverified technician is not a bidder.
        // This is the action `is_verified` is supposed to vouch for, and
        // gating it here (rather than only hiding the feed) is what makes
        // the badge mean something — the feed is a convenience, this is
        // the rule.
        if !profile.is_verified {
            return Err(JobError::TechnicianNotVerified);
        }

        if input.price <= 0 || input.price > MAX_OFFER_PRICE {
            return Err(JobError::InvalidOffer);
        }
        let eta = input.eta.trim();
        if eta.is_empty() || eta.chars().count() > MAX_ETA_LEN {
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
            .add_job_offer(input.job_request_id, profile.id, input.price, eta.to_string())
            .await?;

        Ok(())
    }
}
