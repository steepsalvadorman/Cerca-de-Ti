use std::sync::Arc;

use crate::features::auth::application::{IdentityVerifier, PasswordHasher, TokenService};
use crate::features::auth::domain::UserRepository;
use crate::features::technician::application::ObjectStorage;
use crate::features::technician::domain::TechnicianRepository;
use crate::features::client::domain::ClientRepository;
use crate::features::job::domain::JobRepository;
use crate::features::chat::domain::ChatRepository;
use crate::features::tracking::domain::TrackingRepository;

/// Shared application state injected into every handler via axum's
/// `State` extractor. Holds ports as trait objects so infrastructure
/// (Postgres, argon2, JWT) stays swappable behind the interfaces.
#[derive(Clone)]
pub struct AppState {
    pub user_repository: Arc<dyn UserRepository>,
    pub password_hasher: Arc<dyn PasswordHasher>,
    pub token_service: Arc<dyn TokenService>,
    pub identity_verifier: Arc<dyn IdentityVerifier>,
    pub technician_repository: Arc<dyn TechnicianRepository>,
    pub client_repository: Arc<dyn ClientRepository>,
    pub job_repository: Arc<dyn JobRepository>,
    pub chat_repository: Arc<dyn ChatRepository>,
    pub tracking_repository: Arc<dyn TrackingRepository>,
    pub object_storage: Arc<dyn ObjectStorage>,
}
