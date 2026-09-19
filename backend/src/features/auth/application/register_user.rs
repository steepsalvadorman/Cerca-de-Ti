use std::sync::Arc;

use crate::features::auth::domain::{AuthError, Email, PasswordHash, Role, User, UserRepository};

use super::ports::{PasswordHasher, TokenService};

pub struct RegisterUserInput {
    pub email: String,
    pub password: String,
    pub name: String,
    pub role: String,
}

pub struct AuthenticatedUser {
    pub user: User,
    pub token: String,
}

/// Use case: register a new user and hand back a session token,
/// orchestrating the domain (`User`, `Email`) against the ports
/// (repository, hasher, token service) — no HTTP, no SQL in here.
pub struct RegisterUserUseCase {
    repository: Arc<dyn UserRepository>,
    hasher: Arc<dyn PasswordHasher>,
    tokens: Arc<dyn TokenService>,
}

impl RegisterUserUseCase {
    pub fn new(
        repository: Arc<dyn UserRepository>,
        hasher: Arc<dyn PasswordHasher>,
        tokens: Arc<dyn TokenService>,
    ) -> Self {
        Self { repository, hasher, tokens }
    }

    pub async fn execute(&self, input: RegisterUserInput) -> Result<AuthenticatedUser, AuthError> {
        let email = Email::parse(&input.email)?;
        let role = Role::parse(&input.role)?;

        if input.password.len() < 8 {
            return Err(AuthError::WeakPassword);
        }

        if self.repository.find_by_email(&email).await?.is_some() {
            return Err(AuthError::EmailAlreadyExists);
        }

        // Off the async runtime: Argon2id is deliberately expensive, and
        // hashing inline let a registration flood occupy every worker.
        let hash = super::ports::hash_password(self.hasher.clone(), input.password.clone())
            .await
            .map_err(|_| AuthError::Hashing)?;
        let user = User::register(email, input.name, role, PasswordHash::new(hash));

        self.repository.insert(&user).await?;

        let token = self
            .tokens
            .issue(user.id, user.role)
            .map_err(|_| AuthError::Token)?;

        Ok(AuthenticatedUser { user, token })
    }
}
