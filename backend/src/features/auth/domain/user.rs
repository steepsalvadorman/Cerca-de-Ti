use chrono::{DateTime, Utc};
use uuid::Uuid;

use super::value_objects::{Email, PasswordHash, Role};

/// The `User` aggregate root for the auth feature: identity plus the
/// invariants around it (always has a valid email, a role, and — when it
/// has a password at all — a hash, never a bare plaintext password).
#[derive(Debug, Clone)]
pub struct User {
    pub id: Uuid,
    pub email: Email,
    pub name: String,
    pub role: Role,
    /// `None` for accounts created through an identity provider: those
    /// users never chose a password, so there is nothing to compare
    /// against and password login is refused for them.
    pub password_hash: Option<PasswordHash>,
    pub created_at: DateTime<Utc>,
}

impl User {
    /// Registers a brand-new user with a password. Existing users are
    /// reconstructed by infrastructure (from a DB row), never through
    /// this constructor.
    pub fn register(email: Email, name: String, role: Role, password_hash: PasswordHash) -> Self {
        Self {
            id: Uuid::new_v4(),
            email,
            name,
            role,
            password_hash: Some(password_hash),
            created_at: Utc::now(),
        }
    }

    /// Registers a user who arrived through an identity provider. The
    /// provider vouched for the email, so there is no password to set and
    /// no verification step of our own to run.
    pub fn register_with_provider(email: Email, name: String, role: Role) -> Self {
        Self {
            id: Uuid::new_v4(),
            email,
            name,
            role,
            password_hash: None,
            created_at: Utc::now(),
        }
    }
}
