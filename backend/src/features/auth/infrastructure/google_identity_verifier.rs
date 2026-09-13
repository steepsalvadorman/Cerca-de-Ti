use std::sync::{Arc, RwLock};
use std::time::{Duration, Instant};

use async_trait::async_trait;
use jsonwebtoken::jwk::JwkSet;
use jsonwebtoken::{decode, decode_header, Algorithm, DecodingKey, Validation};
use serde::Deserialize;

use crate::features::auth::application::{IdentityVerifier, VerifiedIdentity};
use crate::features::auth::domain::AuthError;

/// Google's public signing keys. Fetched over HTTPS and cached: the set
/// rotates every few days, not every request.
const GOOGLE_CERTS_URL: &str = "https://www.googleapis.com/oauth2/v3/certs";

/// Google signs ID tokens under both spellings of its issuer and has
/// never settled on one, so both are accepted.
const GOOGLE_ISSUERS: [&str; 2] = ["https://accounts.google.com", "accounts.google.com"];

const JWKS_TTL: Duration = Duration::from_secs(60 * 60);

/// Floor between refreshes triggered by an unknown `kid`. Without it, a
/// stream of tokens carrying a bogus key id would turn into a stream of
/// requests to Google from our server.
const JWKS_MIN_REFRESH_INTERVAL: Duration = Duration::from_secs(60);

/// The subset of Google's ID token payload we use. `aud`, `iss` and
/// `exp` are checked by `jsonwebtoken` through `Validation`, so they do
/// not need to appear here.
#[derive(Deserialize)]
struct GoogleClaims {
    sub: String,
    email: Option<String>,
    #[serde(default)]
    email_verified: bool,
    name: Option<String>,
}

struct CachedJwks {
    keys: Arc<JwkSet>,
    fetched_at: Instant,
}

/// Verifies Google ID tokens against Google's published keys.
///
/// `audiences` are the OAuth client ids that may appear in `aud` — the
/// Android, iOS and web client ids of this project. A token minted for
/// somebody else's app is signed by the very same Google keys, so this
/// check is what stops one being replayed against Cerca.
pub struct GoogleIdentityVerifier {
    http: reqwest::Client,
    audiences: Vec<String>,
    cache: RwLock<Option<CachedJwks>>,
}

impl GoogleIdentityVerifier {
    pub fn new(audiences: Vec<String>) -> Self {
        Self {
            http: reqwest::Client::builder()
                // Google being slow must not tie up a request handler.
                .timeout(Duration::from_secs(10))
                .build()
                .unwrap_or_default(),
            audiences,
            cache: RwLock::new(None),
        }
    }

    fn cached(&self) -> Option<(Arc<JwkSet>, Instant)> {
        let guard = self.cache.read().ok()?;
        let cached = guard.as_ref()?;
        Some((cached.keys.clone(), cached.fetched_at))
    }

    async fn fetch_jwks(&self) -> Result<Arc<JwkSet>, AuthError> {
        let keys: JwkSet = self
            .http
            .get(GOOGLE_CERTS_URL)
            .send()
            .await
            .and_then(|response| response.error_for_status())
            .map_err(|e| {
                tracing::error!(error = %e, "could not fetch Google's signing keys");
                AuthError::ProviderUnavailable
            })?
            .json()
            .await
            .map_err(|e| {
                tracing::error!(error = %e, "Google's signing keys did not parse as a JWK set");
                AuthError::ProviderUnavailable
            })?;

        let keys = Arc::new(keys);
        if let Ok(mut guard) = self.cache.write() {
            *guard = Some(CachedJwks { keys: keys.clone(), fetched_at: Instant::now() });
        }
        Ok(keys)
    }

    /// The cached set, refetched when it has expired.
    async fn jwks(&self) -> Result<Arc<JwkSet>, AuthError> {
        match self.cached() {
            Some((keys, fetched_at)) if fetched_at.elapsed() < JWKS_TTL => Ok(keys),
            _ => self.fetch_jwks().await,
        }
    }

    /// Looks up one key, refetching once if the `kid` is unknown — that
    /// is what a rotation looks like from here, and waiting out the TTL
    /// would mean an hour of failed sign-ins.
    async fn decoding_key(&self, kid: &str) -> Result<DecodingKey, AuthError> {
        let keys = self.jwks().await?;

        if let Some(jwk) = keys.find(kid) {
            return DecodingKey::from_jwk(jwk).map_err(|e| {
                tracing::error!(error = %e, "Google's JWK did not convert to a decoding key");
                AuthError::ProviderUnavailable
            });
        }

        let stale = self
            .cached()
            .is_some_and(|(_, fetched_at)| fetched_at.elapsed() >= JWKS_MIN_REFRESH_INTERVAL);
        if !stale {
            return Err(AuthError::InvalidProviderToken);
        }

        let keys = self.fetch_jwks().await?;
        let jwk = keys.find(kid).ok_or(AuthError::InvalidProviderToken)?;
        DecodingKey::from_jwk(jwk).map_err(|e| {
            tracing::error!(error = %e, "Google's JWK did not convert to a decoding key");
            AuthError::ProviderUnavailable
        })
    }
}

#[async_trait]
impl IdentityVerifier for GoogleIdentityVerifier {
    async fn verify_google_id_token(&self, id_token: &str) -> Result<VerifiedIdentity, AuthError> {
        let header = decode_header(id_token).map_err(|_| AuthError::InvalidProviderToken)?;
        let kid = header.kid.ok_or(AuthError::InvalidProviderToken)?;

        let key = self.decoding_key(&kid).await?;

        let mut validation = Validation::new(Algorithm::RS256);
        validation.set_audience(&self.audiences);
        validation.set_issuer(&GOOGLE_ISSUERS);

        let token = decode::<GoogleClaims>(id_token, &key, &validation)
            .map_err(|_| AuthError::InvalidProviderToken)?;
        let claims = token.claims;

        Ok(VerifiedIdentity {
            subject: claims.sub,
            // A token minted without the `email` scope carries no address;
            // reporting it as unverified lets the use case answer with
            // the same message it uses for an unverified one.
            email_verified: claims.email_verified && claims.email.is_some(),
            email: claims.email.unwrap_or_default(),
            name: claims.name,
        })
    }
}

/// Stands in when no Google client id is configured, so the server still
/// boots and every other endpoint keeps working — `/auth/google` answers
/// 503 instead.
pub struct UnconfiguredIdentityVerifier;

#[async_trait]
impl IdentityVerifier for UnconfiguredIdentityVerifier {
    async fn verify_google_id_token(&self, _id_token: &str) -> Result<VerifiedIdentity, AuthError> {
        Err(AuthError::ProviderUnavailable)
    }
}
