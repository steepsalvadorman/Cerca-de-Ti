use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::Json;
use uuid::Uuid;

use crate::features::auth::interfaces::http::middleware::CurrentUser;
use crate::features::chat::application::{GetMessagesUseCase, SendMessageInput, SendMessageUseCase};
use crate::shared::AppError;
use crate::state::AppState;

use super::dto::{ChatMessageResponse, SendMessageRequest};

pub async fn send_message(
    State(state): State<AppState>,
    Path(job_request_id): Path<Uuid>,
    current_user: CurrentUser,
    Json(body): Json<SendMessageRequest>,
) -> Result<(StatusCode, Json<ChatMessageResponse>), AppError> {
    body.validate()?;

    let use_case = SendMessageUseCase::new(
        state.chat_repository.clone(),
        state.job_repository.clone(),
        state.technician_repository.clone(),
    );

    let message = use_case
        .execute(SendMessageInput {
            job_request_id,
            sender_id: current_user.user_id,
            sender_role: current_user.role.as_str().to_string(),
            text: body.text,
        })
        .await?;

    Ok((StatusCode::CREATED, Json(ChatMessageResponse::from(message))))
}

pub async fn get_messages(
    State(state): State<AppState>,
    Path(job_request_id): Path<Uuid>,
    current_user: CurrentUser,
) -> Result<Json<Vec<ChatMessageResponse>>, AppError> {
    let use_case = GetMessagesUseCase::new(
        state.chat_repository.clone(),
        state.job_repository.clone(),
        state.technician_repository.clone(),
    );

    let messages = use_case.execute(job_request_id, current_user.user_id).await?;

    Ok(Json(messages.into_iter().map(Into::into).collect()))
}
