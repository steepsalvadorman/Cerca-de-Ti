use async_trait::async_trait;
use chrono::{DateTime, Utc};
use sqlx::PgPool;
use uuid::Uuid;

use crate::features::auth::domain::{
    AuthError, Email, IdentityProvider, PasswordHash, Role, User, UserRepository,
};

/// Raw shape of the `users` row. Kept private and separate from the
/// `User` aggregate so the domain never depends on sqlx/row layout.
#[derive(sqlx::FromRow)]
struct UserRow {
    id: Uuid,
    email: String,
    name: String,
    role: String,
    /// Null for accounts that sign in through an identity provider.
    password_hash: Option<String>,
    created_at: DateTime<Utc>,
}

impl TryFrom<UserRow> for User {
    type Error = AuthError;

    fn try_from(row: UserRow) -> Result<Self, Self::Error> {
        Ok(User {
            id: row.id,
            email: Email::parse(&row.email)?,
            name: row.name,
            role: Role::parse(&row.role)?,
            password_hash: row.password_hash.map(PasswordHash::new),
            created_at: row.created_at,
        })
    }
}

pub struct PostgresUserRepository {
    pool: PgPool,
}

impl PostgresUserRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl UserRepository for PostgresUserRepository {
    async fn insert(&self, user: &User) -> Result<(), AuthError> {
        sqlx::query(
            "INSERT INTO users (id, email, name, role, password_hash, created_at) \
             VALUES ($1, $2, $3, $4, $5, $6)",
        )
        .bind(user.id)
        .bind(user.email.as_str())
        .bind(&user.name)
        .bind(user.role.as_str())
        .bind(user.password_hash.as_ref().map(|hash| hash.as_str()))
        .bind(user.created_at)
        .execute(&self.pool)
        .await
        .map_err(|e| AuthError::Repository(e.to_string()))?;

        Ok(())
    }

    async fn find_by_email(&self, email: &Email) -> Result<Option<User>, AuthError> {
        let row = sqlx::query_as::<_, UserRow>(
            "SELECT id, email, name, role, password_hash, created_at FROM users WHERE email = $1",
        )
        .bind(email.as_str())
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| AuthError::Repository(e.to_string()))?;

        row.map(User::try_from).transpose()
    }

    async fn find_by_id(&self, id: Uuid) -> Result<Option<User>, AuthError> {
        let row = sqlx::query_as::<_, UserRow>(
            "SELECT id, email, name, role, password_hash, created_at FROM users WHERE id = $1",
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| AuthError::Repository(e.to_string()))?;

        row.map(User::try_from).transpose()
    }

    async fn find_by_identity(
        &self,
        provider: IdentityProvider,
        subject: &str,
    ) -> Result<Option<User>, AuthError> {
        let row = sqlx::query_as::<_, UserRow>(
            "SELECT u.id, u.email, u.name, u.role, u.password_hash, u.created_at \
             FROM users u JOIN auth_identities i ON i.user_id = u.id \
             WHERE i.provider = $1 AND i.subject = $2",
        )
        .bind(provider.as_str())
        .bind(subject)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| AuthError::Repository(e.to_string()))?;

        row.map(User::try_from).transpose()
    }

    async fn link_identity(
        &self,
        provider: IdentityProvider,
        subject: &str,
        user_id: Uuid,
    ) -> Result<(), AuthError> {
        // Two sign-ins racing on the same brand-new account would both
        // try to insert this pair; the second one is a no-op, not a 500.
        sqlx::query(
            "INSERT INTO auth_identities (provider, subject, user_id) \
             VALUES ($1, $2, $3) ON CONFLICT (provider, subject) DO NOTHING",
        )
        .bind(provider.as_str())
        .bind(subject)
        .bind(user_id)
        .execute(&self.pool)
        .await
        .map_err(|e| AuthError::Repository(e.to_string()))?;

        Ok(())
    }

    async fn count_with_password_hash(&self, hash: &str) -> Result<i64, AuthError> {
        let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM users WHERE password_hash = $1")
            .bind(hash)
            .fetch_one(&self.pool)
            .await
            .map_err(|e| AuthError::Repository(e.to_string()))?;

        Ok(count.0)
    }
}
