use uuid::Uuid;

#[derive(Debug, Clone)]
pub struct JobPaymentRecord {
    pub job_request_id: Uuid,
    pub gateway: String,
    pub gateway_reference: String,
    pub amount_soles: i32,
    pub payment_method: String,
    pub idempotency_key: Uuid,
    pub simulated: bool,
}
