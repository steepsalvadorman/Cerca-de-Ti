use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::features::client::domain::{ClientAddress, ClientPaymentMethod};
use crate::shared::{validation, AppError};

pub const MAX_ADDRESS_LABEL_CHARS: usize = 60;
pub const MAX_ADDRESS_DETAIL_CHARS: usize = 300;
pub const MAX_PAYMENT_LABEL_CHARS: usize = 60;
pub const MAX_PAYMENT_DETAIL_CHARS: usize = 120;

#[derive(Serialize)]
pub struct AddressResponse {
    pub id: Uuid,
    pub label: String,
    pub detail: String,
}

impl From<ClientAddress> for AddressResponse {
    fn from(a: ClientAddress) -> Self {
        Self {
            id: a.id,
            label: a.label,
            detail: a.detail,
        }
    }
}

#[derive(Deserialize)]
pub struct AddAddressRequest {
    pub label: String,
    pub detail: String,
}

impl AddAddressRequest {
    /// Returns the request with its text normalised, so the caller stores
    /// what the user meant rather than the padding around it. Validating
    /// without using the result would accept `"  Casa  "` and store it,
    /// leaving "Casa" and "  Casa  " as two different labels.
    pub fn validated(self) -> Result<Self, AppError> {
        Ok(Self {
            label: validation::required_text("label", &self.label, MAX_ADDRESS_LABEL_CHARS)?,
            detail: validation::required_text("detail", &self.detail, MAX_ADDRESS_DETAIL_CHARS)?,
        })
    }
}

#[derive(Serialize)]
pub struct PaymentMethodResponse {
    pub id: Uuid,
    pub label: String,
    pub detail: String,
}

impl From<ClientPaymentMethod> for PaymentMethodResponse {
    fn from(m: ClientPaymentMethod) -> Self {
        Self {
            id: m.id,
            label: m.label,
            detail: m.detail,
        }
    }
}

#[derive(Deserialize)]
pub struct AddPaymentMethodRequest {
    pub label: String,
    pub detail: String,
}

impl AddPaymentMethodRequest {
    /// See [`AddAddressRequest::validated`].
    pub fn validated(self) -> Result<Self, AppError> {
        Ok(Self {
            label: validation::required_text("label", &self.label, MAX_PAYMENT_LABEL_CHARS)?,
            detail: validation::required_text("detail", &self.detail, MAX_PAYMENT_DETAIL_CHARS)?,
        })
    }
}

#[derive(Deserialize)]
pub struct SaveClientProfileRequest {
    pub saved: bool,
}

#[derive(Serialize)]
pub struct ClientProfileStatusResponse {
    pub profile_saved: bool,
}
