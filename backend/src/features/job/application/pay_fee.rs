use std::sync::Arc;
use uuid::Uuid;

use crate::features::job::application::ports::{PaymentError, PaymentGateway};
use crate::features::job::domain::{JobError, JobPaymentRecord, JobRepository};

pub struct PayFeeInput {
    pub job_request_id: Uuid,
    pub client_id: Uuid,
    pub payment_method: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PayFeeResult {
    pub gateway_reference: String,
    pub simulated: bool,
}

pub struct PayFeeUseCase {
    job_repo: Arc<dyn JobRepository>,
    payment_gateway: Arc<dyn PaymentGateway>,
}

impl PayFeeUseCase {
    pub fn new(job_repo: Arc<dyn JobRepository>, payment_gateway: Arc<dyn PaymentGateway>) -> Self {
        Self {
            job_repo,
            payment_gateway,
        }
    }

    pub async fn execute(&self, input: PayFeeInput) -> Result<PayFeeResult, JobError> {
        let mut job = self.job_repo
            .find_job_request_by_id(input.job_request_id)
            .await?
            .ok_or(JobError::JobNotFound)?;

        if job.client_id != input.client_id {
            return Err(JobError::Unauthorized);
        }

        if job.fee_amount > 0 && job.technician_profile_id.is_none() {
            return Err(JobError::InvalidStatusTransition);
        }

        if let Some(existing) = self
            .job_repo
            .find_job_payment_by_idempotency_key(input.job_request_id)
            .await?
        {
            job.payment_method = Some(existing.payment_method);
            job.pay_fee()?;
            self.job_repo.save_job_request(&job).await?;
            return Ok(PayFeeResult {
                gateway_reference: existing.gateway_reference,
                simulated: existing.simulated,
            });
        }

        if job.fee_paid {
            job.pay_fee()?;
            self.job_repo.save_job_request(&job).await?;
            return Ok(PayFeeResult {
                gateway_reference: format!("already-paid-{}", input.job_request_id),
                simulated: false,
            });
        }

        let capture = if job.fee_amount > 0 {
            Some(
                self.payment_gateway
                    .capture_fee(job.fee_amount, &input.payment_method, input.job_request_id)
                    .await
                    .map_err(|error| match error {
                        PaymentError::Unavailable => JobError::PaymentUnavailable,
                        PaymentError::Declined | PaymentError::Internal(_) => JobError::PaymentFailed,
                    })?,
            )
        } else {
            None
        };

        if let Some(ref capture) = capture {
            self.job_repo
                .record_job_payment(&JobPaymentRecord {
                    job_request_id: input.job_request_id,
                    gateway: capture.gateway.clone(),
                    gateway_reference: capture.gateway_reference.clone(),
                    amount_soles: job.fee_amount,
                    payment_method: input.payment_method.clone(),
                    idempotency_key: input.job_request_id,
                    simulated: capture.simulated,
                })
                .await?;
        }

        job.payment_method = Some(input.payment_method);
        job.pay_fee()?;

        self.job_repo.save_job_request(&job).await?;

        Ok(PayFeeResult {
            gateway_reference: capture
                .as_ref()
                .map(|c| c.gateway_reference.clone())
                .unwrap_or_else(|| format!("free-{}", input.job_request_id)),
            simulated: capture.as_ref().is_some_and(|c| c.simulated),
        })
    }
}
