use axum::extract::State;
use axum::http::StatusCode;
use axum::Json;

use crate::features::auth::application::{
    GetCurrentUserUseCase, LoginUserInput, LoginUserUseCase, RegisterUserInput, RegisterUserUseCase,
    SignInWithGoogleInput, SignInWithGoogleUseCase,
};
use crate::shared::AppError;
use crate::state::AppState;

use super::dto::{AuthResponse, GoogleSignInRequest, LoginRequest, RegisterRequest, UserResponse};
use super::middleware::CurrentUser;

pub async fn register(
    State(state): State<AppState>,
    Json(body): Json<RegisterRequest>,
) -> Result<(StatusCode, Json<AuthResponse>), AppError> {
    body.validate()?;

    let use_case = RegisterUserUseCase::new(
        state.user_repository.clone(),
        state.password_hasher.clone(),
        state.token_service.clone(),
    );

    let authenticated = use_case
        .execute(RegisterUserInput {
            email: body.email,
            password: body.password,
            name: body.name,
            role: body.role,
        })
        .await?;

    Ok((StatusCode::CREATED, Json(AuthResponse::from(authenticated))))
}

pub async fn login(
    State(state): State<AppState>,
    Json(body): Json<LoginRequest>,
) -> Result<Json<AuthResponse>, AppError> {
    body.validate()?;

    let use_case = LoginUserUseCase::new(
        state.user_repository.clone(),
        state.password_hasher.clone(),
        state.token_service.clone(),
    );

    let authenticated = use_case
        .execute(LoginUserInput { email: body.email, password: body.password })
        .await?;

    Ok(Json(AuthResponse::from(authenticated)))
}

pub async fn google_sign_in(
    State(state): State<AppState>,
    Json(body): Json<GoogleSignInRequest>,
) -> Result<(StatusCode, Json<AuthResponse>), AppError> {
    let use_case = SignInWithGoogleUseCase::new(
        state.user_repository.clone(),
        state.identity_verifier.clone(),
        state.token_service.clone(),
    );

    let result = use_case
        .execute(SignInWithGoogleInput { id_token: body.id_token, role: body.role })
        .await?;

    let status = if result.created { StatusCode::CREATED } else { StatusCode::OK };
    Ok((status, Json(AuthResponse::from(result.authenticated))))
}

pub async fn me(
    State(state): State<AppState>,
    current_user: CurrentUser,
) -> Result<Json<UserResponse>, AppError> {
    let use_case = GetCurrentUserUseCase::new(state.user_repository.clone());
    let user = use_case.execute(current_user.user_id).await?;
    Ok(Json(UserResponse::from(&user)))
}
