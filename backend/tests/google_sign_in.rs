//! Tests for the Sign-in with Google use case.
//!
//! Unlike the other suites here these need no Postgres: the branching
//! that matters (returning user, linking to an existing password
//! account, first-time signup) is all in the use case, and in-memory
//! doubles make each branch a three-line setup. Verifying a real Google
//! token is `GoogleIdentityVerifier`'s job and is not exercised here —
//! that would mean reaching Google's servers.

use std::sync::{Arc, Mutex};

use async_trait::async_trait;
use uuid::Uuid;

use backend::features::auth::application::{
    GoogleSignIn, IdentityVerifier, SignInWithGoogleInput, SignInWithGoogleUseCase, TokenClaims,
    TokenService, VerifiedIdentity,
};
use backend::features::auth::domain::{
    AuthError, Email, IdentityProvider, PasswordHash, Role, User, UserRepository,
};

#[derive(Default)]
struct InMemoryUsers {
    users: Mutex<Vec<User>>,
    identities: Mutex<Vec<(String, String, Uuid)>>,
}

#[async_trait]
impl UserRepository for InMemoryUsers {
    async fn insert(&self, user: &User) -> Result<(), AuthError> {
        self.users.lock().unwrap().push(user.clone());
        Ok(())
    }

    async fn find_by_email(&self, email: &Email) -> Result<Option<User>, AuthError> {
        Ok(self.users.lock().unwrap().iter().find(|u| u.email == *email).cloned())
    }

    async fn find_by_id(&self, id: Uuid) -> Result<Option<User>, AuthError> {
        Ok(self.users.lock().unwrap().iter().find(|u| u.id == id).cloned())
    }

    async fn find_by_identity(
        &self,
        provider: IdentityProvider,
        subject: &str,
    ) -> Result<Option<User>, AuthError> {
        let user_id = self
            .identities
            .lock()
            .unwrap()
            .iter()
            .find(|(p, s, _)| p == provider.as_str() && s == subject)
            .map(|(_, _, id)| *id);

        match user_id {
            Some(id) => self.find_by_id(id).await,
            None => Ok(None),
        }
    }

    async fn link_identity(
        &self,
        provider: IdentityProvider,
        subject: &str,
        user_id: Uuid,
    ) -> Result<(), AuthError> {
        let mut identities = self.identities.lock().unwrap();
        let already_linked = identities
            .iter()
            .any(|(p, s, _)| p == provider.as_str() && s == subject);
        if !already_linked {
            identities.push((provider.as_str().to_string(), subject.to_string(), user_id));
        }
        Ok(())
    }
}

/// Hands back whatever identity the test set up, standing in for a token
/// Google has already signed.
struct StubVerifier(VerifiedIdentity);

#[async_trait]
impl IdentityVerifier for StubVerifier {
    async fn verify_google_id_token(&self, _id_token: &str) -> Result<VerifiedIdentity, AuthError> {
        Ok(VerifiedIdentity {
            subject: self.0.subject.clone(),
            email: self.0.email.clone(),
            email_verified: self.0.email_verified,
            name: self.0.name.clone(),
        })
    }
}

struct StubTokens;

impl TokenService for StubTokens {
    fn issue(&self, user_id: Uuid, _role: Role) -> Result<String, ()> {
        Ok(format!("token-for-{user_id}"))
    }

    fn verify(&self, _token: &str) -> Result<TokenClaims, ()> {
        Err(())
    }
}

fn identity(subject: &str, email: &str, verified: bool, name: Option<&str>) -> VerifiedIdentity {
    VerifiedIdentity {
        subject: subject.to_string(),
        email: email.to_string(),
        email_verified: verified,
        name: name.map(str::to_string),
    }
}

fn use_case(users: Arc<InMemoryUsers>, identity: VerifiedIdentity) -> SignInWithGoogleUseCase {
    SignInWithGoogleUseCase::new(users, Arc::new(StubVerifier(identity)), Arc::new(StubTokens))
}

/// `Result::unwrap_err` would ask `GoogleSignIn` to implement `Debug`
/// purely so tests can print a value they never expect to get.
fn expect_error(result: Result<GoogleSignIn, AuthError>, what: &str) -> AuthError {
    match result {
        Err(error) => error,
        Ok(_) => panic!("expected the use case to refuse {what}"),
    }
}

fn input(role: Option<&str>) -> SignInWithGoogleInput {
    SignInWithGoogleInput {
        id_token: "signed-by-google".to_string(),
        role: role.map(str::to_string),
    }
}

#[tokio::test]
async fn first_sign_in_creates_the_account_with_the_requested_role() {
    let users = Arc::new(InMemoryUsers::default());
    let use_case = use_case(
        users.clone(),
        identity("google-sub-1", "ana@example.com", true, Some("Ana Quispe")),
    );

    let result = use_case.execute(input(Some("technician"))).await.unwrap();

    assert!(result.created, "a brand-new account should report as created");
    assert_eq!(result.authenticated.user.email.as_str(), "ana@example.com");
    assert_eq!(result.authenticated.user.name, "Ana Quispe");
    assert_eq!(result.authenticated.user.role, Role::Technician);
    assert!(
        result.authenticated.user.password_hash.is_none(),
        "a Google account never sets a password"
    );
}

#[tokio::test]
async fn a_new_account_without_a_role_asks_for_one_instead_of_guessing() {
    let users = Arc::new(InMemoryUsers::default());
    let use_case = use_case(
        users.clone(),
        identity("google-sub-1", "ana@example.com", true, Some("Ana")),
    );

    let error = expect_error(use_case.execute(input(None)).await, "a signup with no role");

    assert!(matches!(error, AuthError::RoleRequired));
    assert!(
        users.users.lock().unwrap().is_empty(),
        "nothing should be persisted until the role is known"
    );
}

#[tokio::test]
async fn signing_in_again_reuses_the_same_account() {
    let users = Arc::new(InMemoryUsers::default());
    let first = use_case(
        users.clone(),
        identity("google-sub-1", "ana@example.com", true, Some("Ana")),
    )
    .execute(input(Some("client")))
    .await
    .unwrap();

    // The second call arrives without a role, the way the login screen
    // sends it, and must not create a second account.
    let second = use_case(
        users.clone(),
        identity("google-sub-1", "ana@example.com", true, Some("Ana")),
    )
    .execute(input(None))
    .await
    .unwrap();

    assert!(!second.created);
    assert_eq!(first.authenticated.user.id, second.authenticated.user.id);
    assert_eq!(users.users.lock().unwrap().len(), 1);
}

#[tokio::test]
async fn google_links_to_the_account_that_already_owns_the_email() {
    let users = Arc::new(InMemoryUsers::default());
    let existing = User::register(
        Email::parse("ana@example.com").unwrap(),
        "Ana Quispe".to_string(),
        Role::Client,
        PasswordHash::new("argon2-hash".to_string()),
    );
    users.insert(&existing).await.unwrap();

    let result = use_case(
        users.clone(),
        identity("google-sub-1", "ana@example.com", true, Some("Ana")),
    )
    .execute(input(Some("technician")))
    .await
    .unwrap();

    assert!(!result.created, "linking is not account creation");
    assert_eq!(result.authenticated.user.id, existing.id);
    // The role travelling with the request must not quietly re-cast an
    // existing client as a technician.
    assert_eq!(result.authenticated.user.role, Role::Client);
    assert_eq!(users.users.lock().unwrap().len(), 1);
}

#[tokio::test]
async fn an_unverified_google_email_is_refused() {
    let users = Arc::new(InMemoryUsers::default());
    let use_case = use_case(
        users.clone(),
        identity("google-sub-1", "ana@example.com", false, Some("Ana")),
    );

    let error = expect_error(
        use_case.execute(input(Some("client"))).await,
        "an unverified provider email",
    );

    assert!(matches!(error, AuthError::ProviderEmailUnverified));
    assert!(users.users.lock().unwrap().is_empty());
}

#[tokio::test]
async fn a_missing_profile_name_falls_back_to_the_email_local_part() {
    let users = Arc::new(InMemoryUsers::default());
    let use_case = use_case(users.clone(), identity("google-sub-1", "ana@example.com", true, None));

    let result = use_case.execute(input(Some("client"))).await.unwrap();

    assert_eq!(result.authenticated.user.name, "ana");
}
