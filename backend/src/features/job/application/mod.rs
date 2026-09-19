pub mod advance_progress;
pub mod cancel_job;
pub mod choose_offer;
pub mod create_job;
pub mod get_technician_jobs;
pub mod job_participation;
pub mod pay_fee;
pub mod ports;
pub mod rate_job;
pub mod submit_offer;

use std::sync::Arc;
use uuid::Uuid;

pub use advance_progress::AdvanceProgressUseCase;
pub use cancel_job::{CancelJobInput, CancelJobUseCase};
pub use choose_offer::{ChooseOfferInput, ChooseOfferUseCase};
pub use create_job::{CreateJobInput, CreateJobUseCase};
pub use get_technician_jobs::{GetTechnicianJobsUseCase, TechnicianJobsOutput};
pub use pay_fee::{PayFeeInput, PayFeeResult, PayFeeUseCase};
pub use rate_job::{RateJobInput, RateJobUseCase};
pub use ports::{PaymentCapture, PaymentError, PaymentGateway};
pub use submit_offer::{SubmitOfferInput, SubmitOfferUseCase};

use crate::features::job::domain::{JobError, JobOffer, JobRequest, JobRepository, JobStatus};
use crate::features::technician::domain::TechnicianRepository;

/// How the caller is connected to a job. The authorization rule returns
/// this rather than a bare `Ok(())` because the *shape of the response*
/// depends on it: a technician who has not been chosen may read an open
/// auction in order to bid on it, but must not be handed the client's
/// identity or address (GAP-18).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum JobAccess {
    /// The client who created the job. Full view.
    OwningClient,
    /// The technician currently assigned to it. Full view.
    AssignedTechnician,
    /// A technician who may bid on this job but has no relationship to the
    /// client yet. Restricted view.
    BiddableTechnician,
}

impl JobAccess {
    /// True when the response may carry the client's personal data.
    pub fn may_see_client_details(self) -> bool {
        matches!(self, JobAccess::OwningClient | JobAccess::AssignedTechnician)
    }
}

/// Shared check for every handler that reads or mutates a single job.
///
/// Three ways in:
///   * the job's client;
///   * the technician currently assigned to it;
///   * a registered technician, on a `bidding` job that is still open and
///     has no technician yet — this is what makes the bidding feed usable.
///     Before this rule existed the technician could list open auctions but
///     got a 403 when opening one, so the offer form never rendered and the
///     whole bidding mode was inoperable from the app (GAP-80).
///
/// Note this is an *access* decision, not a *visibility* one: it decides
/// who may read the job at all. The interfaces layer still narrows the
/// payload for `BiddableTechnician` (see `JobRequestResponse`), so being
/// allowed in does not mean seeing the client's address.
pub(crate) async fn authorize_job_access(
    job: &JobRequest,
    caller_id: Uuid,
    technician_repo: &Arc<dyn TechnicianRepository>,
) -> Result<JobAccess, JobError> {
    if job.client_id == caller_id {
        return Ok(JobAccess::OwningClient);
    }

    // One lookup answers both technician questions, and registering a
    // profile is the only way to stop being "just a user".
    let profile = technician_repo
        .find_profile_by_user_id(caller_id)
        .await
        .map_err(|e| JobError::Repository(e.to_string()))?;

    let Some(profile) = profile else {
        return Err(JobError::Unauthorized);
    };

    if job.technician_profile_id == Some(profile.id) {
        return Ok(JobAccess::AssignedTechnician);
    }

    let is_open_bidding_job = job.job_kind == "bidding"
        && job.technician_profile_id.is_none()
        && job.status == JobStatus::Pending;

    if is_open_bidding_job {
        return Ok(JobAccess::BiddableTechnician);
    }

    Err(JobError::Unauthorized)
}

pub struct GetJobRequestUseCase {
    job_repo: Arc<dyn JobRepository>,
    technician_repo: Arc<dyn TechnicianRepository>,
}

/// A job plus the caller's relationship to it.
pub struct JobWithAccess {
    pub job: JobRequest,
    pub access: JobAccess,
}

impl GetJobRequestUseCase {
    pub fn new(job_repo: Arc<dyn JobRepository>, technician_repo: Arc<dyn TechnicianRepository>) -> Self {
        Self { job_repo, technician_repo }
    }

    pub async fn execute(&self, id: Uuid, caller_id: Uuid) -> Result<Option<JobWithAccess>, JobError> {
        let Some(job) = self.job_repo.find_job_request_by_id(id).await? else {
            return Ok(None);
        };

        let access = authorize_job_access(&job, caller_id, &self.technician_repo).await?;
        Ok(Some(JobWithAccess { job, access }))
    }
}

pub struct GetJobOffersUseCase {
    job_repo: Arc<dyn JobRepository>,
    technician_repo: Arc<dyn TechnicianRepository>,
}

impl GetJobOffersUseCase {
    pub fn new(job_repo: Arc<dyn JobRepository>, technician_repo: Arc<dyn TechnicianRepository>) -> Self {
        Self { job_repo, technician_repo }
    }

    pub async fn execute(&self, job_request_id: Uuid, caller_id: Uuid) -> Result<Vec<JobOffer>, JobError> {
        let job = self.job_repo
            .find_job_request_by_id(job_request_id)
            .await?
            .ok_or(JobError::JobNotFound)?;
        authorize_job_access(&job, caller_id, &self.technician_repo).await?;

        self.job_repo.find_offers_by_job_id(job_request_id).await
    }
}

pub struct GetClientHistoryUseCase {
    job_repo: Arc<dyn JobRepository>,
}

impl GetClientHistoryUseCase {
    pub fn new(job_repo: Arc<dyn JobRepository>) -> Self {
        Self { job_repo }
    }

    pub async fn execute(&self, client_id: Uuid) -> Result<Vec<JobRequest>, JobError> {
        self.job_repo.find_client_history(client_id).await
    }
}
