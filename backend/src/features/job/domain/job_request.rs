use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::errors::JobError;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum JobStatus {
    Pending,
    Active,
    Completed,
    Cancelled,
}

impl JobStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            JobStatus::Pending => "pending",
            JobStatus::Active => "active",
            JobStatus::Completed => "completed",
            JobStatus::Cancelled => "cancelled",
        }
    }

    pub fn parse(raw: &str) -> Result<Self, String> {
        match raw {
            "pending" => Ok(JobStatus::Pending),
            "active" => Ok(JobStatus::Active),
            "completed" => Ok(JobStatus::Completed),
            "cancelled" => Ok(JobStatus::Cancelled),
            _ => Err(format!("invalid job status: {raw}")),
        }
    }
}

/// The app-fee schedule (soles), keyed by `fee_type`. The single source of
/// truth for what a client is actually charged — the frontend used to keep
/// its own copy of these amounts purely for display, with nothing tying it
/// to what the backend would accept.
///
/// PLACEHOLDER PRICING: these are a rough conversion from the original
/// Chilean-peso prototype (2990/4990 CLP), not a real product-pricing
/// decision for the Peru market — confirm the actual amounts before launch.
fn fee_amount_for(fee_type: &str) -> i32 {
    match fee_type {
        "bidding" => 4,
        _ => 0,
    }
}

#[derive(Debug, Clone)]
pub struct JobRequest {
    pub id: Uuid,
    pub client_id: Uuid,
    pub technician_profile_id: Option<i32>,
    pub tech_team_id: Option<i32>,
    pub job_kind: String, // "direct", "bidding", "project"
    pub status: JobStatus,
    pub timeline_step: i32, // 0: Confirmado, 1: En camino, 2: En el trabajo, 3: Finalizado
    pub fee_type: String, // "direct", "bidding", "project"
    pub fee_amount: i32,
    /// Cerca's app fee is settled: either paid, or there was nothing to
    /// charge (a free `fee_type` is born with this already `true`).
    pub fee_paid: bool,
    pub payment_method: Option<String>,
    /// A payment transaction actually happened. A free job is `fee_paid`
    /// without `payment_done`, and that is correct, not a divergence.
    pub payment_done: bool,
    pub mobility_included: bool,
    pub agreed_price: Option<i32>,
    pub rating: Option<i32>,
    pub title: Option<String>,
    pub address: Option<String>,
    pub comment: Option<String>,
    /// Set exactly when `status` is `Cancelled`; a CHECK constraint in
    /// migration 0012 enforces that correspondence.
    pub cancelled_at: Option<DateTime<Utc>>,
    /// Who ended it. Kept separate from the status because "the client
    /// withdrew before anyone bid" and "the technician walked away
    /// mid-job" are the same status and very different facts.
    pub cancelled_by: Option<Uuid>,
    pub cancellation_reason: Option<String>,
    /// Optimistic-concurrency counter (migration 0013). Incremented on the
    /// way out of `save_job_request`, and compared so a second writer
    /// whose read is stale matches no rows instead of overwriting the
    /// first (GAP-07).
    pub version: i32,
    pub created_at: DateTime<Utc>,
}

impl JobRequest {
    pub fn new(
        client_id: Uuid,
        technician_profile_id: Option<i32>,
        tech_team_id: Option<i32>,
        job_kind: String,
        fee_type: String,
        title: Option<String>,
        address: Option<String>,
        mobility_included: bool,
    ) -> Self {
        let fee_amount = fee_amount_for(&fee_type);
        let is_free = fee_amount == 0;
        Self {
            id: Uuid::new_v4(),
            client_id,
            technician_profile_id,
            tech_team_id,
            job_kind,
            status: if is_free { JobStatus::Active } else { JobStatus::Pending },
            timeline_step: 0,
            fee_amount,
            fee_type,
            fee_paid: is_free,
            payment_method: None,
            payment_done: false,
            mobility_included,
            agreed_price: None,
            rating: None,
            title,
            address,
            comment: None,
            cancelled_at: None,
            cancelled_by: None,
            cancellation_reason: None,
            version: 0,
            created_at: Utc::now(),
        }
    }

    /// Records the bidding fee as paid and starts the job. Free jobs are
    /// already active, so retries are harmless no-ops.
    ///
    /// Idempotent on purpose: a retried request (flaky network, an
    /// impatient double tap) must not be an error, but it must also not
    /// replay the state change — without the early return, paying twice
    /// on a finished job would reset it to `Active` at step 0, undoing
    /// a completed job.
    ///
    /// The terminal check comes *first*, and that ordering matters: while
    /// the early return ran before any status validation, a *free* job
    /// (already `fee_paid`) that had been cancelled or completed answered
    /// `Ok` here, so `POST /pay` reported success on a job nobody could
    /// pay for. Reachable the moment cancellation existed (GAP-12).
    pub fn pay_fee(&mut self) -> Result<(), JobError> {
        if self.is_terminal() {
            return Err(JobError::InvalidStatusTransition);
        }
        if self.fee_paid {
            return Ok(());
        }
        if self.status != JobStatus::Pending {
            return Err(JobError::InvalidStatusTransition);
        }

        self.fee_paid = true;
        self.payment_done = true;
        self.status = JobStatus::Active;
        self.timeline_step = 0; // Confirmado
        Ok(())
    }

    pub fn advance_timeline(&mut self) -> Result<(), JobError> {
        if self.status != JobStatus::Active {
            return Err(JobError::InvalidStatusTransition);
        }
        if self.timeline_step < 3 {
            self.timeline_step += 1;
            if self.timeline_step == 3 {
                self.status = JobStatus::Completed;
            }
        }
        Ok(())
    }

    pub fn rate(&mut self, rating: i32, comment: Option<String>) -> Result<(), JobError> {
        if self.status != JobStatus::Completed {
            return Err(JobError::InvalidStatusTransition);
        }
        if self.rating.is_some() {
            return Err(JobError::InvalidStatusTransition);
        }
        if !(1..=5).contains(&rating) {
            return Err(JobError::InvalidStatusTransition);
        }
        self.rating = Some(rating);
        self.comment = comment;
        Ok(())
    }

    /// Ends a job that has not finished.
    ///
    /// `cancelled` existed in the domain and in the database CHECK from the
    /// start, but nothing ever wrote it, so there was no way out of a job:
    /// a client whose auction drew no bids kept it forever, and an
    /// abandoned job sat in `active` for good (GAP-19).
    ///
    /// Terminal states are refused — there is nothing to cancel once the
    /// work is done, and cancelling twice is not a second event. Calling
    /// this on an already-cancelled job is an error rather than a no-op
    /// because the caller had to read the job to get here, so a repeat
    /// means a stale view or a double submit, and silently accepting it
    /// would erase the original reason and timestamp.
    pub fn cancel(&mut self, by: Uuid, reason: Option<String>) -> Result<(), JobError> {
        match self.status {
            JobStatus::Completed => return Err(JobError::InvalidStatusTransition),
            JobStatus::Cancelled => return Err(JobError::InvalidStatusTransition),
            JobStatus::Pending | JobStatus::Active => {}
        }

        self.status = JobStatus::Cancelled;
        self.cancelled_at = Some(Utc::now());
        self.cancelled_by = Some(by);
        self.cancellation_reason = reason
            .map(|reason| reason.trim().to_string())
            .filter(|reason| !reason.is_empty());

        Ok(())
    }

    /// True once the job has reached a state nothing can move it out of.
    pub fn is_terminal(&self) -> bool {
        matches!(self.status, JobStatus::Completed | JobStatus::Cancelled)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn job(kind: &str) -> JobRequest {
        JobRequest::new(
            Uuid::new_v4(),
            None,
            None,
            kind.to_string(),
            kind.to_string(),
            None,
            None,
            true,
        )
    }

    #[test]
    fn only_bidding_has_the_four_sol_fee() {
        let direct = job("direct");
        let project = job("project");
        let bidding = job("bidding");

        assert_eq!((direct.fee_amount, direct.fee_paid, direct.status), (0, true, JobStatus::Active));
        assert_eq!((project.fee_amount, project.fee_paid, project.status), (0, true, JobStatus::Active));
        assert_eq!((bidding.fee_amount, bidding.fee_paid, bidding.status), (4, false, JobStatus::Pending));
    }

    #[test]
    fn bidding_stays_pending_until_its_fee_is_paid() {
        let mut bidding = job("bidding");
        bidding.pay_fee().unwrap();
        assert!(bidding.fee_paid);
        assert_eq!(bidding.status, JobStatus::Active);
    }

    #[test]
    fn free_job_payment_retry_is_harmless() {
        let mut direct = job("direct");
        direct.pay_fee().unwrap();
        assert_eq!(direct.status, JobStatus::Active);
        assert_eq!(direct.timeline_step, 0);
    }

    #[test]
    fn rating_rejects_boundaries_and_duplicate_submissions() {
        let mut completed = job("direct");
        completed.status = JobStatus::Completed;
        completed.timeline_step = 3;

        assert!(completed.rate(0, None).is_err());
        assert!(completed.rate(6, None).is_err());
        completed.rate(5, Some("Excelente".to_string())).unwrap();
        assert!(completed.rate(1, None).is_err());
    }

    #[test]
    fn timeline_cannot_advance_after_completion() {
        let mut direct = job("direct");
        for _ in 0..3 {
            direct.advance_timeline().unwrap();
        }
        assert_eq!(direct.status, JobStatus::Completed);
        assert!(direct.advance_timeline().is_err());
    }
}
