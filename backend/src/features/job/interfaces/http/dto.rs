use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::features::job::application::{JobAccess, TechnicianJobsOutput};
use crate::features::job::domain::{JobOffer, JobRequest};
use crate::shared::{validation, AppError};

/// A job as its client or its assigned technician sees it.
#[derive(Serialize)]
pub struct JobRequestResponse {
    pub id: Uuid,
    pub client_id: Uuid,
    pub technician_profile_id: Option<i32>,
    pub tech_team_id: Option<i32>,
    pub job_kind: String,
    pub status: String,
    pub timeline_step: i32,
    pub fee_type: String,
    pub fee_amount: i32,
    pub fee_paid: bool,
    pub payment_method: Option<String>,
    pub payment_done: bool,
    pub mobility_included: bool,
    pub agreed_price: Option<i32>,
    pub rating: Option<i32>,
    pub title: Option<String>,
    pub address: Option<String>,
    pub comment: Option<String>,
    /// Populated only for a cancelled job. The client's history shows why
    /// a request went away, which a bare `status` cannot convey.
    pub cancelled_at: Option<String>,
    pub cancellation_reason: Option<String>,
    pub created_at: String,
}

impl From<JobRequest> for JobRequestResponse {
    fn from(j: JobRequest) -> Self {
        Self {
            id: j.id,
            client_id: j.client_id,
            technician_profile_id: j.technician_profile_id,
            tech_team_id: j.tech_team_id,
            job_kind: j.job_kind,
            status: j.status.as_str().to_string(),
            timeline_step: j.timeline_step,
            fee_type: j.fee_type,
            fee_amount: j.fee_amount,
            fee_paid: j.fee_paid,
            payment_method: j.payment_method,
            payment_done: j.payment_done,
            mobility_included: j.mobility_included,
            agreed_price: j.agreed_price,
            rating: j.rating,
            title: j.title,
            address: j.address,
            comment: j.comment,
            // `cancelled_by` is deliberately not exposed: it is always the
            // client who is reading this, and the technician never gets
            // this view of the job.
            cancelled_at: j.cancelled_at.map(|at| at.to_rfc3339()),
            cancellation_reason: j.cancellation_reason,
            created_at: j.created_at.to_rfc3339(),
        }
    }
}

/// A job as a technician who may bid on it sees it — and *only* that much.
///
/// A separate type rather than a flag on the full response, so the
/// restricted shape is what gets serialized and there is no field to
/// forget to clear. `client_id` and `address` are the two that matter:
/// `client_id` is a stable handle on a person (and can be correlated
/// across endpoints), and `address` is where they live. Neither has any
/// bearing on whether to bid, and both were previously handed to any
/// technician browsing the open-auction feed (GAP-18).
///
/// Deliberately absent as well: `fee_*` and `payment_*` (what the client
/// is being charged is not the technician's business), `rating` and
/// `comment` (the client's own review of a previous job), and
/// `technician_profile_id`/`tech_team_id`, which are necessarily unset on
/// an open auction.
#[derive(Serialize)]
pub struct OpenBidJobResponse {
    pub id: Uuid,
    pub job_kind: String,
    pub status: String,
    pub title: Option<String>,
    pub created_at: String,
}

impl From<&JobRequest> for OpenBidJobResponse {
    fn from(j: &JobRequest) -> Self {
        Self {
            id: j.id,
            job_kind: j.job_kind.clone(),
            status: j.status.as_str().to_string(),
            title: j.title.clone(),
            created_at: j.created_at.to_rfc3339(),
        }
    }
}

/// Either shape, chosen by the caller's relationship to the job.
#[derive(Serialize)]
#[serde(untagged)]
pub enum JobView {
    Full(Box<JobRequestResponse>),
    OpenBid(OpenBidJobResponse),
}

impl JobView {
    /// The full view for the client and the assigned technician; the
    /// restricted one for a technician who is still only a candidate.
    pub fn for_access(job: JobRequest, access: JobAccess) -> Self {
        if access.may_see_client_details() {
            JobView::Full(Box::new(JobRequestResponse::from(job)))
        } else {
            JobView::OpenBid(OpenBidJobResponse::from(&job))
        }
    }
}

#[derive(Deserialize)]
pub struct CreateJobRequest {
    pub technician_profile_id: Option<i32>,
    pub tech_team_id: Option<i32>,
    pub job_kind: String, // "direct", "bidding", "project"
    pub title: Option<String>,
    pub address: Option<String>,
    pub mobility_included: Option<bool>,
}

/// Field bounds for a job request (GAP-02).
///
/// `job_kind` is checked against the known set here as well as in
/// `CreateJobUseCase`: the use case returns a status-transition error,
/// which is the wrong shape for "you sent `job_kind: 'freebie'`", and
/// validation is the interface's job.
pub const CREATE_JOB_KINDS: [&str; 3] = ["direct", "bidding", "project"];
pub const MAX_TITLE_CHARS: usize = 120;
pub const MAX_ADDRESS_CHARS: usize = 300;

impl CreateJobRequest {
    pub fn validate(&self) -> Result<(), AppError> {
        validation::one_of("job_kind", &self.job_kind, &CREATE_JOB_KINDS)?;
        validation::optional_text("title", self.title.as_deref(), MAX_TITLE_CHARS)?;
        validation::optional_text("address", self.address.as_deref(), MAX_ADDRESS_CHARS)?;
        Ok(())
    }
}

#[derive(Deserialize)]
pub struct PayFeeRequest {
    pub payment_method: String,
}

/// Canonical fee payment methods. The Flutter app sends Spanish labels;
/// both forms are accepted and stored as the canonical code.
pub const PAYMENT_METHODS: &[&str] = &["card", "cash", "transfer"];

pub fn normalize_payment_method(raw: &str) -> Result<String, AppError> {
    match raw.trim().to_lowercase().as_str() {
        "card" | "tarjeta" => Ok("card".to_string()),
        "cash" | "efectivo" => Ok("cash".to_string()),
        "transfer" | "transferencia" => Ok("transfer".to_string()),
        _ => Err(AppError::Validation(format!(
            "payment_method debe ser uno de: {}",
            PAYMENT_METHODS.join(", ")
        ))),
    }
}

impl PayFeeRequest {
    pub fn validate(&self) -> Result<String, AppError> {
        normalize_payment_method(&self.payment_method)
    }
}

#[derive(Serialize)]
pub struct PayFeeResponse {
    pub gateway_reference: String,
    pub simulated: bool,
}

#[derive(Deserialize)]
pub struct RateJobRequest {
    pub rating: i32,
    pub comment: Option<String>,
}

pub const MAX_RATING_COMMENT_CHARS: usize = 300;

impl RateJobRequest {
    pub fn validate(&self) -> Result<(), AppError> {
        // The range is also enforced by the domain. Checking it here is
        // what makes "rating: 9" a 422 naming the field instead of a
        // status-transition error (GAP-17).
        validation::in_range("rating", self.rating as i64, 1, 5)?;
        validation::optional_text("comment", self.comment.as_deref(), MAX_RATING_COMMENT_CHARS)?;
        Ok(())
    }
}

/// `reason` is optional: the client may just want the job gone, and a
/// mandatory explanation would be answered with "asdf" anyway. The use case
/// bounds its length.
#[derive(Deserialize)]
pub struct CancelJobRequest {
    #[serde(default)]
    pub reason: Option<String>,
}

#[derive(Serialize)]
pub struct JobOfferResponse {
    pub id: i32,
    pub job_request_id: Uuid,
    pub technician_profile_id: i32,
    pub price: i32,
    pub eta: String,
    pub name: String,
    pub mono: String,
    pub oficio: String,
    pub rating: f64,
    pub verified: bool,
}

impl From<JobOffer> for JobOfferResponse {
    fn from(o: JobOffer) -> Self {
        Self {
            id: o.id,
            job_request_id: o.job_request_id,
            technician_profile_id: o.technician_profile_id,
            price: o.price,
            eta: o.eta,
            name: o.name,
            mono: o.mono,
            oficio: o.oficio,
            rating: o.rating,
            verified: o.verified,
        }
    }
}

#[derive(Deserialize)]
pub struct SubmitOfferRequest {
    pub price: i32,
    pub eta: String,
}

#[derive(Deserialize)]
pub struct ChooseOfferRequest {
    pub offer_id: i32,
}

#[derive(Serialize)]
pub struct TechnicianJobsResponse {
    /// Jobs where this technician is already the chosen one: full view,
    /// the same shape the client sees.
    pub assigned: Vec<JobRequestResponse>,
    /// Open auctions they may bid on: restricted view. This is the feed
    /// itself, so it is exactly where the client's identity and address
    /// used to leak to every browsing technician (GAP-18).
    pub open_for_bid: Vec<OpenBidJobResponse>,
}

impl From<TechnicianJobsOutput> for TechnicianJobsResponse {
    fn from(o: TechnicianJobsOutput) -> Self {
        Self {
            assigned: o.assigned.into_iter().map(Into::into).collect(),
            open_for_bid: o.open_for_bid.iter().map(Into::into).collect(),
        }
    }
}
