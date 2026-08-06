pub mod update_location;

use std::sync::Arc;
use uuid::Uuid;

pub use update_location::{UpdateLocationInput, UpdateLocationUseCase};

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
            .ok_or(TrackingError::Unauthorized)?;

        let mut is_authorized = job.client_id == reader_id;

        if !is_authorized {
            if let Some(tech_id) = job.technician_profile_id {
                if let Some(tech_profile) = self.technician_repo
                    .find_profile_by_user_id(reader_id)
                    .await
                    .map_err(|e| TrackingError::Repository(e.to_string()))?
                {
                    if tech_profile.id == tech_id {
                        is_authorized = true;
                    }
                }
            }
        }

        if !is_authorized {
            return Err(TrackingError::Unauthorized);
        }

        if !job.fee_paid {
            return Err(TrackingError::FeeNotPaid);
        }

        self.tracking_repo
            .find_location_by_job_id(job_request_id)
            .await?
            .ok_or(TrackingError::LocationNotFound)
    }
}
