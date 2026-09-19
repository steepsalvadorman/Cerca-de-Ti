use async_trait::async_trait;
use thiserror::Error;
use uuid::Uuid;

#[derive(Debug, Error, Clone)]
pub enum PaymentError {
    #[error("el proveedor de pagos no está disponible")]
    Unavailable,

    #[error("el pago fue rechazado")]
    Declined,

    #[error("error interno de pagos: {0}")]
    Internal(String),
}

#[derive(Debug, Clone)]
pub struct PaymentCapture {
    pub gateway: String,
    pub gateway_reference: String,
    /// True when no real money moved (`PAYMENTS_MODE=fake`).
    pub simulated: bool,
}

/// Port for charging Cerca's contact fee. Production will plug in a real
/// PSP; development and tests use `FakePaymentGateway` (GAP-14).
#[async_trait]
pub trait PaymentGateway: Send + Sync {
    async fn capture_fee(
        &self,
        amount_soles: i32,
        payment_method: &str,
        idempotency_key: Uuid,
    ) -> Result<PaymentCapture, PaymentError>;
}
