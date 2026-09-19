use async_trait::async_trait;
use uuid::Uuid;

use super::errors::JobError;
use super::job_offer::JobOffer;
use super::job_payment::JobPaymentRecord;
use super::job_request::JobRequest;

#[async_trait]
pub trait JobRepository: Send + Sync {
    async fn create_job_request(&self, job: &JobRequest) -> Result<(), JobError>;
    async fn find_job_request_by_id(&self, id: Uuid) -> Result<Option<JobRequest>, JobError>;
    async fn save_job_request(&self, job: &JobRequest) -> Result<(), JobError>;
    async fn find_offers_by_job_id(&self, job_request_id: Uuid) -> Result<Vec<JobOffer>, JobError>;
    async fn find_offer_by_id(&self, id: i32) -> Result<Option<JobOffer>, JobError>;
    async fn add_job_offer(&self, job_request_id: Uuid, technician_profile_id: i32, price: i32, eta: String) -> Result<(), JobError>;
    async fn find_client_history(&self, client_id: Uuid) -> Result<Vec<JobRequest>, JobError>;
    async fn find_assigned_jobs(&self, technician_profile_id: i32) -> Result<Vec<JobRequest>, JobError>;
    async fn find_open_bidding_jobs(&self, excluding_technician_profile_id: i32) -> Result<Vec<JobRequest>, JobError>;
    async fn record_job_payment(&self, payment: &JobPaymentRecord) -> Result<(), JobError>;
    async fn find_job_payment_by_idempotency_key(
        &self,
        idempotency_key: Uuid,
    ) -> Result<Option<JobPaymentRecord>, JobError>;
}
