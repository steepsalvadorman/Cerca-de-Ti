use std::sync::Arc;
use uuid::Uuid;

use crate::features::job::domain::{JobError, JobRepository};

pub struct PayFeeInput {
    pub job_request_id: Uuid,
    pub client_id: Uuid,
    pub payment_method: String,
}

pub struct PayFeeUseCase {
    job_repo: Arc<dyn JobRepository>,
}

impl PayFeeUseCase {
    pub fn new(job_repo: Arc<dyn JobRepository>) -> Self {
        Self { job_repo }
    }

    pub async fn execute(&self, input: PayFeeInput) -> Result<(), JobError> {
        let mut job = self.job_repo
            .find_job_request_by_id(input.job_request_id)
            .await?
            .ok_or(JobError::JobNotFound)?;

        if job.client_id != input.client_id {
            return Err(JobError::Unauthorized);
        }

        job.payment_method = Some(input.payment_method);
        job.pay_fee()?;

        self.job_repo.save_job_request(&job).await?;
        Ok(())
    }
}
