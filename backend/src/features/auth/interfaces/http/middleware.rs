use axum::extract::{FromRef, FromRequestParts};
use axum::http::request::Parts;
use axum::http::StatusCode;
use uuid::Uuid;

use crate::features::auth::domain::Role;
use crate::state::AppState;

/// Axum extractor that verifies the `Authorization: Bearer <token>`
/// header via the `TokenService` port and yields the caller's identity.
/// Any handler that takes `CurrentUser` as an argument is, by
/// construction, a protected route.
pub struct CurrentUser {
    pub user_id: Uuid,
    pub role: Role,
}

impl<S> FromRequestParts<S> for CurrentUser
where
    AppState: FromRef<S>,
    S: Send + Sync,
{
    type Rejection = (StatusCode, &'static str);

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let app_state = AppState::from_ref(state);

        let header = parts
            .headers
            .get(axum::http::header::AUTHORIZATION)
            .and_then(|value| value.to_str().ok())
            .ok_or((StatusCode::UNAUTHORIZED, "missing authorization header"))?;

        let token = header
            .strip_prefix("Bearer ")
            .ok_or((StatusCode::UNAUTHORIZED, "expected a Bearer token"))?;

        let claims = app_state
            .token_service
            .verify(token)
            .map_err(|_| (StatusCode::UNAUTHORIZED, "invalid or expired token"))?;

        Ok(CurrentUser { user_id: claims.user_id, role: claims.role })
    }
}

/// Role-gated variants of [`CurrentUser`]. A handler that takes one of
/// these is, by construction, reachable only by that role — the check is
/// enforced by the type system instead of an `if` each handler could
/// forget. Both `Deref` to the inner `CurrentUser`, so handler bodies
/// keep using `current_user.user_id` unchanged.
///
/// Note these are for *role* gating only: ownership checks (is this
/// client the owner of this job?) still live in the use cases, e.g.
/// `job::application::authorize_job_access`.
pub struct ClientUser(pub CurrentUser);

pub struct TechnicianUser(pub CurrentUser);

impl std::ops::Deref for ClientUser {
    type Target = CurrentUser;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl std::ops::Deref for TechnicianUser {
    type Target = CurrentUser;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl<S> FromRequestParts<S> for ClientUser
where
    AppState: FromRef<S>,
    S: Send + Sync,
{
    type Rejection = (StatusCode, &'static str);

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let user = CurrentUser::from_request_parts(parts, state).await?;

        if user.role != Role::Client {
            return Err((StatusCode::FORBIDDEN, "this action requires a client account"));
        }

        Ok(ClientUser(user))
    }
}

impl<S> FromRequestParts<S> for TechnicianUser
where
    AppState: FromRef<S>,
    S: Send + Sync,
{
    type Rejection = (StatusCode, &'static str);

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let user = CurrentUser::from_request_parts(parts, state).await?;

        if user.role != Role::Technician {
            return Err((StatusCode::FORBIDDEN, "this action requires a technician account"));
        }

        Ok(TechnicianUser(user))
    }
}
