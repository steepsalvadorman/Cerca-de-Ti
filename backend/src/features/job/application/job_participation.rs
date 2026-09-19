//! Shared rules for who may use chat and tracking on a job, and when.
//!
//! The contact fee (`fee_paid`) used to gate both features, which meant a
//! chosen technician could not reach the client until after payment — the
//! opposite of "direct contact is free at launch" (GAP-38). Participation
//! is now gated by *assignment* and *job status* instead.

use std::sync::Arc;
use uuid::Uuid;

use crate::features::chat::domain::ChatError;
use crate::features::job::domain::{JobError, JobRequest, JobStatus};
use crate::features::technician::domain::TechnicianRepository;
use crate::features::tracking::domain::TrackingError;

/// True when the caller is the job's client or its assigned technician.
pub(crate) async fn is_job_participant(
    job: &JobRequest,
    caller_id: Uuid,
    technician_repo: &Arc<dyn TechnicianRepository>,
) -> Result<bool, JobError> {
    if job.client_id == caller_id {
        return Ok(true);
    }

    let Some(assigned_id) = job.technician_profile_id else {
        return Ok(false);
    };

    let profile = technician_repo
        .find_profile_by_user_id(caller_id)
        .await
        .map_err(|e| JobError::Repository(e.to_string()))?;

    Ok(profile.is_some_and(|p| p.id == assigned_id))
}

pub(crate) fn ensure_chat_readable(status: &JobStatus) -> Result<(), ChatError> {
    match status {
        JobStatus::Cancelled => Err(ChatError::JobClosed),
        JobStatus::Pending | JobStatus::Active | JobStatus::Completed => Ok(()),
    }
}

pub(crate) fn ensure_chat_writable(status: &JobStatus) -> Result<(), ChatError> {
    match status {
        JobStatus::Pending | JobStatus::Active => Ok(()),
        JobStatus::Completed => Err(ChatError::ReadOnly),
        JobStatus::Cancelled => Err(ChatError::JobClosed),
    }
}

pub(crate) fn ensure_location_readable(status: &JobStatus) -> Result<(), TrackingError> {
    match status {
        JobStatus::Cancelled => Err(TrackingError::JobClosed),
        JobStatus::Pending | JobStatus::Active | JobStatus::Completed => Ok(()),
    }
}

/// Live GPS only makes sense while the job is under way.
pub(crate) fn ensure_location_publishable(status: &JobStatus) -> Result<(), TrackingError> {
    match status {
        JobStatus::Active => Ok(()),
        JobStatus::Cancelled => Err(TrackingError::JobClosed),
        JobStatus::Pending | JobStatus::Completed => Err(TrackingError::NotActive),
    }
}
