pub mod update_location;

use std::sync::Arc;
use uuid::Uuid;

pub use update_location::{UpdateLocationInput, UpdateLocationUseCase};

use crate::features::job::application::job_participation::{
    ensure_location_readable, is_job_participant,
};
use crate::features::job::domain::JobRepository;
use crate::features::technician::domain::TechnicianRepository;
use crate::features::tracking::domain::{TechnicianLocation, TrackingError, TrackingRepository};

pub struct GetLocationUseCase {
    tracking_repo: Arc<dyn TrackingRepository>,
    job_repo: Arc<dyn JobRepository>,
    technician_repo: Arc<dyn TechnicianRepository>,
}

impl GetLocationUseCase {
    pub fn new(
        tracking_repo: Arc<dyn TrackingRepository>,
        job_repo: Arc<dyn JobRepository>,
        technician_repo: Arc<dyn TechnicianRepository>,
    ) -> Self {
        Self {
            tracking_repo,
            job_repo,
            technician_repo,
        }
    }

    pub async fn execute(&self, job_request_id: Uuid, reader_id: Uuid) -> Result<TechnicianLocation, TrackingError> {
        let job = self.job_repo
            .find_job_request_by_id(job_request_id)
            .await
            .map_err(|e| TrackingError::Repository(e.to_string()))?
            .ok_or(TrackingError::JobNotFound)?;

        if !is_job_participant(&job, reader_id, &self.technician_repo)
            .await
            .map_err(|e| TrackingError::Repository(e.to_string()))?
        {
            return Err(TrackingError::Unauthorized);
        }

        ensure_location_readable(&job.status)?;

        self.tracking_repo
            .find_location_by_job_id(job_request_id)
            .await?
            .ok_or(TrackingError::LocationNotFound)
    }
}
