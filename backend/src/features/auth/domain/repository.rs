use async_trait::async_trait;
use uuid::Uuid;

use super::errors::AuthError;
use super::user::User;
use super::value_objects::{Email, IdentityProvider};

/// Port for `User` persistence, owned by the domain (classic DDD
/// repository pattern) and implemented by an infrastructure adapter.
#[async_trait]
pub trait UserRepository: Send + Sync {
    async fn insert(&self, user: &User) -> Result<(), AuthError>;
    async fn find_by_email(&self, email: &Email) -> Result<Option<User>, AuthError>;
    async fn find_by_id(&self, id: Uuid) -> Result<Option<User>, AuthError>;

    /// Looks a user up by the provider's own account id (the `sub` claim
    /// for Google), which is what stays stable when someone renames or
    /// changes the email on their provider account.
    async fn find_by_identity(
        &self,
        provider: IdentityProvider,
        subject: &str,
    ) -> Result<Option<User>, AuthError>;

    /// Records that a provider account belongs to one of our users.
    /// Idempotent: linking the same pair twice is not an error.
    async fn link_identity(
        &self,
        provider: IdentityProvider,
        subject: &str,
        user_id: Uuid,
    ) -> Result<(), AuthError>;
}
