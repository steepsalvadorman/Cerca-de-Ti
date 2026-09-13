use std::sync::Arc;

use crate::features::auth::domain::{AuthError, Email, UserRepository};

use super::ports::{PasswordHasher, TokenService};
use super::register_user::AuthenticatedUser;

pub struct LoginUserInput {
    pub email: String,
    pub password: String,
}

/// Use case: verify credentials and issue a session token.
pub struct LoginUserUseCase {
    repository: Arc<dyn UserRepository>,
    hasher: Arc<dyn PasswordHasher>,
    tokens: Arc<dyn TokenService>,
}

impl LoginUserUseCase {
    pub fn new(
        repository: Arc<dyn UserRepository>,
        hasher: Arc<dyn PasswordHasher>,
        tokens: Arc<dyn TokenService>,
    ) -> Self {
        Self { repository, hasher, tokens }
    }

    pub async fn execute(&self, input: LoginUserInput) -> Result<AuthenticatedUser, AuthError> {
        let email = Email::parse(&input.email).map_err(|_| AuthError::InvalidCredentials)?;

        let user = self
            .repository
            .find_by_email(&email)
            .await?
            .ok_or(AuthError::InvalidCredentials)?;

        // Accounts created through Google have no hash to compare
        // against. Saying so beats a generic "invalid credentials" that
        // would send someone hunting for a password they never set.
        let hash = user
            .password_hash
            .as_ref()
            .ok_or(AuthError::PasswordLoginUnavailable)?;

        let matches = self
            .hasher
            .verify(&input.password, hash.as_str())
            .map_err(|_| AuthError::InvalidCredentials)?;

        if !matches {
            return Err(AuthError::InvalidCredentials);
        }

        let token = self
            .tokens
            .issue(user.id, user.role)
            .map_err(|_| AuthError::Token)?;

        Ok(AuthenticatedUser { user, token })
    }
}
