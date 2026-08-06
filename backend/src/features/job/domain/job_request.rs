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
        "direct" => 12,
        "bidding" => 20,
        "project" => 20,
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
    pub fee_paid: bool,
    pub payment_method: Option<String>,
    pub payment_done: bool,
    pub mobility_included: bool,
    pub agreed_price: Option<i32>,
    pub rating: Option<i32>,
    pub title: Option<String>,
    pub address: Option<String>,
    pub comment: Option<String>,
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
        Self {
            id: Uuid::new_v4(),
            client_id,
            technician_profile_id,
            tech_team_id,
            job_kind,
            status: JobStatus::Pending,
            timeline_step: 0,
            fee_amount: fee_amount_for(&fee_type),
            fee_type,
            fee_paid: false,
            payment_method: None,
            payment_done: false,
            mobility_included,
            agreed_price: None,
            rating: None,
            title,
            address,
            comment: None,
            created_at: Utc::now(),
        }
    }

    /// Records the contact fee as paid and starts the job.
    ///
    /// Idempotent on purpose: a retried request (flaky network, an
    /// impatient double tap) must not be an error, but it must also not
    /// replay the state change — without the early return, paying twice
    /// on a finished job would reset it to `Active` at step 0, undoing
    /// a completed job.
    pub fn pay_fee(&mut self) -> Result<(), JobError> {
        if self.fee_paid {
            return Ok(());
        }
        if self.status != JobStatus::Pending {
            return Err(JobError::InvalidStatusTransition);
        }

        self.fee_paid = true;
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
        if !(1..=5).contains(&rating) {
            return Err(JobError::InvalidStatusTransition);
        }
        self.rating = Some(rating);
        self.comment = comment;
        Ok(())
    }
}
