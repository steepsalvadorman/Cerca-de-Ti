use async_trait::async_trait;
use uuid::Uuid;

use crate::features::job::application::ports::{PaymentCapture, PaymentError, PaymentGateway};

/// Simulates a successful capture with a short delay so the client can
/// show a realistic "Procesando…" state. Must never be wired in production
/// (`main` panics if `PAYMENTS_MODE=fake` with `APP_ENV=production`).
pub struct FakePaymentGateway;

#[async_trait]
impl PaymentGateway for FakePaymentGateway {
    async fn capture_fee(
        &self,
        amount_soles: i32,
        payment_method: &str,
        idempotency_key: Uuid,
    ) -> Result<PaymentCapture, PaymentError> {
        // Enough to feel real in the UI without slowing tests noticeably.
        tokio::time::sleep(std::time::Duration::from_millis(350)).await;

        tracing::warn!(
            amount_soles,
            payment_method,
            %idempotency_key,
            "PAYMENTS_MODE=fake — no money was collected"
        );

        Ok(PaymentCapture {
            gateway: "fake".to_string(),
            gateway_reference: format!("fake-{idempotency_key}"),
            simulated: true,
        })
    }
}

/// Answers 503 until a real adapter exists.
pub struct UnconfiguredPaymentGateway;

#[async_trait]
impl PaymentGateway for UnconfiguredPaymentGateway {
    async fn capture_fee(
        &self,
        _amount_soles: i32,
        _payment_method: &str,
        _idempotency_key: Uuid,
    ) -> Result<PaymentCapture, PaymentError> {
        Err(PaymentError::Unavailable)
    }
}
