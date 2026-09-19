use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::Json;
use serde_json::json;

use crate::features::auth::domain::AuthError;
use crate::features::chat::domain::ChatError;
use crate::features::client::domain::ClientError;
use crate::features::job::domain::JobError;
use crate::features::technician::domain::TechnicianError;
use crate::features::tracking::domain::TrackingError;

/// Root HTTP error type. Each feature's domain error gets a `From` impl
/// here so handlers can just use `?` and the interfaces layer stays the
/// only place that knows about status codes.
///
/// `Debug` is derived rather than hand-written so tests can `unwrap()` a
/// `Result<_, AppError>` and read the failure.
#[derive(Debug)]
pub enum AppError {
    Auth(AuthError),
    Technician(TechnicianError),
    Client(ClientError),
    Job(JobError),
    Chat(ChatError),
    Tracking(TrackingError),
    /// A request that is well-formed JSON but whose *contents* are not
    /// acceptable: a blank title, an address longer than the column is
    /// meant to hold, a value outside a known set.
    ///
    /// Distinct from the domain errors above on purpose. `422` tells the
    /// client "your form is wrong, fix the field", which is actionable,
    /// whereas the domain errors describe the state of the world ("that
    /// job is already taken"). Collapsing the two is how a validation
    /// failure ends up rendered as an English server message in a Spanish
    /// app (GAP-02, GAP-17).
    Validation(String),
}

impl From<AuthError> for AppError {
    fn from(error: AuthError) -> Self {
        AppError::Auth(error)
    }
}

impl From<TechnicianError> for AppError {
    fn from(error: TechnicianError) -> Self {
        AppError::Technician(error)
    }
}

impl From<ClientError> for AppError {
    fn from(error: ClientError) -> Self {
        AppError::Client(error)
    }
}

impl From<JobError> for AppError {
    fn from(error: JobError) -> Self {
        AppError::Job(error)
    }
}

impl From<ChatError> for AppError {
    fn from(error: ChatError) -> Self {
        AppError::Chat(error)
    }
}

impl From<TrackingError> for AppError {
    fn from(error: TrackingError) -> Self {
        AppError::Tracking(error)
    }
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, public_message) = match &self {
            AppError::Auth(AuthError::EmailAlreadyExists) => (StatusCode::CONFLICT, self.to_string()),
            AppError::Auth(AuthError::InvalidCredentials)
            | AppError::Auth(AuthError::InvalidProviderToken) => (StatusCode::UNAUTHORIZED, self.to_string()),
            // The caller is who they say they are; what is missing is a
            // usable email on the provider side, which no retry fixes.
            AppError::Auth(AuthError::ProviderEmailUnverified) => (StatusCode::FORBIDDEN, self.to_string()),
            // Password login against an account that only has Google.
            AppError::Auth(AuthError::PasswordLoginUnavailable) => (StatusCode::CONFLICT, self.to_string()),
            // Google sign-in found a local account with its own password.
            // Adopting it silently is how an account gets pre-hijacked, so
            // the caller is told to prove ownership instead. 409 rather
            // than 401: the Google token was fine, the *link* is what
            // cannot proceed unattended.
            AppError::Auth(AuthError::LinkRequiresPassword) => (StatusCode::CONFLICT, self.to_string()),
            // The request is well-formed but cannot complete until the
            // app asks whether this is a client or a technician and
            // sends the answer back. 422 is what the app keys on.
            AppError::Auth(AuthError::RoleRequired) => (StatusCode::UNPROCESSABLE_ENTITY, self.to_string()),
            // Same shape as the storage case below: a deploy step is
            // missing, not a bad request.
            AppError::Auth(AuthError::ProviderUnavailable) => {
                tracing::error!("sign-in with Google is unavailable — is GOOGLE_CLIENT_IDS set?");
                (StatusCode::SERVICE_UNAVAILABLE, self.to_string())
            }
            AppError::Auth(AuthError::InvalidEmail)
            | AppError::Auth(AuthError::InvalidRole)
            | AppError::Auth(AuthError::WeakPassword) => (StatusCode::BAD_REQUEST, self.to_string()),
            AppError::Auth(AuthError::Hashing)
            | AppError::Auth(AuthError::Token)
            | AppError::Auth(AuthError::Repository(_)) => {
                tracing::error!(error = %self, "internal error handling request");
                (StatusCode::INTERNAL_SERVER_ERROR, "internal server error".to_string())
            }

            AppError::Technician(TechnicianError::TechnicianNotFound)
            | AppError::Technician(TechnicianError::TeamNotFound)
            | AppError::Technician(TechnicianError::DocumentNotFound) => (StatusCode::NOT_FOUND, self.to_string()),
            AppError::Technician(TechnicianError::InvalidDocumentStatus(_))
            | AppError::Technician(TechnicianError::InvalidDocumentKey(_))
            | AppError::Technician(TechnicianError::InvalidContentType(_))
            | AppError::Technician(TechnicianError::DocumentContentMismatch(_))
            | AppError::Technician(TechnicianError::DocumentTooLarge { .. }) => {
                (StatusCode::BAD_REQUEST, self.to_string())
            }
            // Not the caller's fault and not a bug either: the server is
            // missing its bucket credentials, so uploads cannot proceed
            // until that deploy step is done.
            AppError::Technician(TechnicianError::StorageUnavailable) => {
                tracing::error!("document storage is not configured — set the R2_* environment variables");
                (StatusCode::SERVICE_UNAVAILABLE, self.to_string())
            }
            AppError::Technician(TechnicianError::Repository(_)) => {
                tracing::error!(error = %self, "technician internal error");
                (StatusCode::INTERNAL_SERVER_ERROR, "internal server error".to_string())
            }

            AppError::Client(ClientError::ClientNotFound)
            | AppError::Client(ClientError::AddressNotFound)
            | AppError::Client(ClientError::PaymentMethodNotFound) => (StatusCode::NOT_FOUND, self.to_string()),
            AppError::Client(ClientError::Repository(_)) => {
                tracing::error!(error = %self, "client internal error");
                (StatusCode::INTERNAL_SERVER_ERROR, "internal server error".to_string())
            }

            AppError::Job(JobError::JobNotFound)
            | AppError::Job(JobError::OfferNotFound) => (StatusCode::NOT_FOUND, self.to_string()),
            AppError::Job(JobError::Unauthorized) => (StatusCode::FORBIDDEN, self.to_string()),
            // 403 rather than 400: the caller is a legitimate technician,
            // they simply have not finished verification. The client keys
            // its "completa tu verificación" screen on this.
            AppError::Job(JobError::TechnicianNotVerified) => (StatusCode::FORBIDDEN, self.to_string()),
            AppError::Job(JobError::InvalidStatusTransition)
            | AppError::Job(JobError::InvalidOffer) => (StatusCode::BAD_REQUEST, self.to_string()),
            AppError::Job(JobError::OfferAlreadySubmitted) => (StatusCode::CONFLICT, self.to_string()),
            // 409: the request was valid, the world moved. The client should
            // re-read the job and decide again, which is exactly what the
            // message says.
            AppError::Job(JobError::ConcurrentModification) => (StatusCode::CONFLICT, self.to_string()),
            AppError::Job(JobError::PaymentFailed) => (StatusCode::PAYMENT_REQUIRED, self.to_string()),
            AppError::Job(JobError::PaymentUnavailable) => {
                tracing::error!("payment gateway is unavailable — check PAYMENTS_MODE");
                (StatusCode::SERVICE_UNAVAILABLE, self.to_string())
            }
            AppError::Job(JobError::Repository(_)) => {
                tracing::error!(error = %self, "job internal error");
                (StatusCode::INTERNAL_SERVER_ERROR, "internal server error".to_string())
            }

            AppError::Chat(ChatError::JobNotFound) => (StatusCode::NOT_FOUND, self.to_string()),
            AppError::Chat(ChatError::Unauthorized) => (StatusCode::FORBIDDEN, self.to_string()),
            AppError::Chat(ChatError::JobClosed) | AppError::Chat(ChatError::ReadOnly) => {
                (StatusCode::BAD_REQUEST, self.to_string())
            }
            AppError::Chat(ChatError::Repository(_)) => {
                tracing::error!(error = %self, "chat internal error");
                (StatusCode::INTERNAL_SERVER_ERROR, "internal server error".to_string())
            }

            AppError::Tracking(TrackingError::JobNotFound) => (StatusCode::NOT_FOUND, self.to_string()),
            AppError::Tracking(TrackingError::LocationNotFound) => (StatusCode::NOT_FOUND, self.to_string()),
            AppError::Tracking(TrackingError::Unauthorized) => (StatusCode::FORBIDDEN, self.to_string()),
            AppError::Tracking(TrackingError::JobClosed) | AppError::Tracking(TrackingError::NotActive) => {
                (StatusCode::BAD_REQUEST, self.to_string())
            }
            AppError::Tracking(TrackingError::Repository(_)) => {
                tracing::error!(error = %self, "tracking internal error");
                (StatusCode::INTERNAL_SERVER_ERROR, "internal server error".to_string())
            }

            // The message is the point here: it names the field and what
            // is wrong with it, so the app can show it next to the input.
            AppError::Validation(message) => {
                (StatusCode::UNPROCESSABLE_ENTITY, message.clone())
            }
        };

        (status, Json(json!({ "error": public_message }))).into_response()
    }
}

impl std::fmt::Display for AppError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            AppError::Auth(e) => write!(f, "{e}"),
            AppError::Technician(e) => write!(f, "{e}"),
            AppError::Client(e) => write!(f, "{e}"),
            AppError::Job(e) => write!(f, "{e}"),
            AppError::Chat(e) => write!(f, "{e}"),
            AppError::Tracking(e) => write!(f, "{e}"),
            AppError::Validation(message) => write!(f, "{message}"),
        }
    }
}
