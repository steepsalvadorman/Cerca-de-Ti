use serde::{Deserialize, Serialize};

use super::errors::AuthError;

/// A validated email address. The only way to obtain one is through
/// `Email::parse`, so any `Email` in scope is guaranteed well-formed.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct Email(String);

impl Email {
    pub fn parse(raw: &str) -> Result<Self, AuthError> {
        let trimmed = raw.trim();
        let valid = trimmed.len() >= 3
            && trimmed.contains('@')
            && !trimmed.starts_with('@')
            && !trimmed.ends_with('@')
            && trimmed.split('@').nth(1).is_some_and(|domain| domain.contains('.'));

        if !valid {
            return Err(AuthError::InvalidEmail);
        }
        Ok(Self(trimmed.to_lowercase()))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl std::fmt::Display for Email {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

/// The two roles Cerca's domain distinguishes, mirroring the Flutter
/// app's "Soy Cliente" / "Soy Técnico" split.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Role {
    Client,
    Technician,
}

impl Role {
    pub fn as_str(&self) -> &'static str {
        match self {
            Role::Client => "client",
            Role::Technician => "technician",
        }
    }

    pub fn parse(raw: &str) -> Result<Self, AuthError> {
        match raw {
            "client" => Ok(Role::Client),
            "technician" => Ok(Role::Technician),
            _ => Err(AuthError::InvalidRole),
        }
    }
}

/// The external identity providers Cerca accepts. Only Google for now —
/// the `auth_identities.provider` CHECK constraint lists the same set.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum IdentityProvider {
    Google,
}

impl IdentityProvider {
    pub fn as_str(&self) -> &'static str {
        match self {
            IdentityProvider::Google => "google",
        }
    }
}

/// An already-hashed password (argon2 PHC string). Opaque on purpose —
/// nothing outside the hashing adapter should ever see or construct a
/// plaintext-adjacent value here.
#[derive(Debug, Clone)]
pub struct PasswordHash(String);

impl PasswordHash {
    pub fn new(hash: String) -> Self {
        Self(hash)
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}
