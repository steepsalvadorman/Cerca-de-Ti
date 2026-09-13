use std::sync::Arc;

use crate::features::auth::domain::{
    AuthError, Email, IdentityProvider, Role, User, UserRepository,
};

use super::ports::{IdentityVerifier, TokenService};
use super::register_user::AuthenticatedUser;

pub struct SignInWithGoogleInput {
    /// The ID token the Google Sign-In SDK handed the app.
    pub id_token: String,
    /// Only consulted the first time we see this person: an existing
    /// account keeps the role it already has. `None` means the client
    /// has not asked yet, and a brand-new account answers `RoleRequired`
    /// so the app can show the client/technician picker and retry.
    pub role: Option<String>,
}

pub struct GoogleSignIn {
    pub authenticated: AuthenticatedUser,
    /// True when this call created the account, so the interface can
    /// answer 201 instead of 200.
    pub created: bool,
}

/// Use case: turn a Google ID token into one of our sessions, creating
/// the account on first sign-in.
///
/// Three cases, in order:
/// 1. We already know this Google account → sign in.
/// 2. We know the (Google-verified) email from a password signup → link
///    the identity to that account rather than creating a duplicate.
/// 3. Nobody matches → create the account, once we know the role.
pub struct SignInWithGoogleUseCase {
    repository: Arc<dyn UserRepository>,
    verifier: Arc<dyn IdentityVerifier>,
    tokens: Arc<dyn TokenService>,
}

impl SignInWithGoogleUseCase {
    pub fn new(
        repository: Arc<dyn UserRepository>,
        verifier: Arc<dyn IdentityVerifier>,
        tokens: Arc<dyn TokenService>,
    ) -> Self {
        Self { repository, verifier, tokens }
    }

    pub async fn execute(&self, input: SignInWithGoogleInput) -> Result<GoogleSignIn, AuthError> {
        let identity = self.verifier.verify_google_id_token(&input.id_token).await?;

        // An unverified address would let someone claim an email they do
        // not control, and step 2 below turns that into taking over an
        // existing account. Google marks its own accounts verified; this
        // guards the edge cases where it does not.
        if !identity.email_verified {
            return Err(AuthError::ProviderEmailUnverified);
        }

        let email = Email::parse(&identity.email)?;

        // 1. Returning user.
        if let Some(user) = self
            .repository
            .find_by_identity(IdentityProvider::Google, &identity.subject)
            .await?
        {
            return self.session_for(user, false);
        }

        // 2. Same person, signed up with a password earlier.
        if let Some(user) = self.repository.find_by_email(&email).await? {
            self.repository
                .link_identity(IdentityProvider::Google, &identity.subject, user.id)
                .await?;
            return self.session_for(user, false);
        }

        // 3. First time here — the role decides which half of the app
        //    they land in, and only the client can answer that.
        let role = Role::parse(input.role.as_deref().ok_or(AuthError::RoleRequired)?)?;

        let name = identity
            .name
            .map(|n| n.trim().to_string())
            .filter(|n| !n.is_empty())
            // Google can withhold the profile name; the local part of the
            // address beats showing an empty name all over the app.
            .unwrap_or_else(|| email.as_str().split('@').next().unwrap_or("").to_string());

        let user = User::register_with_provider(email, name, role);
        self.repository.insert(&user).await?;
        self.repository
            .link_identity(IdentityProvider::Google, &identity.subject, user.id)
            .await?;

        self.session_for(user, true)
    }

    fn session_for(&self, user: User, created: bool) -> Result<GoogleSignIn, AuthError> {
        let token = self
            .tokens
            .issue(user.id, user.role)
            .map_err(|_| AuthError::Token)?;

        Ok(GoogleSignIn { authenticated: AuthenticatedUser { user, token }, created })
    }
}
