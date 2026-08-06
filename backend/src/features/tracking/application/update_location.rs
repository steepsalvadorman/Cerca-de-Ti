use std::sync::Arc;
use uuid::Uuid;

use crate::features::job::domain::JobRepository;
use crate::features::technician::domain::TechnicianRepository;
use crate::features::tracking::domain::{TechnicianLocation, TrackingError, TrackingRepository};

pub struct UpdateLocationInput {
    pub job_request_id: Uuid,
    pub technician_user_id: Uuid,
    pub latitude: f64,
    pub longitude: f64,
}

pub struct UpdateLocationUseCase {
    tracking_repo: Arc<dyn TrackingRepository>,
    job_repo: Arc<dyn JobRepository>,
    technician_repo: Arc<dyn TechnicianRepository>,
}

impl UpdateLocationUseCase {
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

    pub async fn execute(&self, input: UpdateLocationInput) -> Result<(), TrackingError> {
        let job = self.job_repo
            .find_job_request_by_id(input.job_request_id)
            .await
            .map_err(|e| TrackingError::Repository(e.to_string()))?
            .ok_or(TrackingError::Unauthorized)?;

        let tech_profile = self.technician_repo
            .find_profile_by_user_id(input.technician_user_id)
            .await
            .map_err(|e| TrackingError::Repository(e.to_string()))?
            .ok_or(TrackingError::Unauthorized)?;

        // Ensure the technician is assigned to the job request
        if job.technician_profile_id != Some(tech_profile.id) {
            return Err(TrackingError::Unauthorized);
        }

        // Live location is part of what the contact fee buys; no point
        // collecting GPS for a job the client never paid for.
        if !job.fee_paid {
            return Err(TrackingError::FeeNotPaid);
        }

        let location = TechnicianLocation::new(
            input.job_request_id,
            input.latitude,
            input.longitude,
        );

        self.tracking_repo.update_location(&location).await?;
        Ok(())
    }
}
