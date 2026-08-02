use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::Json;
use uuid::Uuid;

use crate::features::auth::interfaces::http::middleware::{CurrentUser, TechnicianUser};
use crate::features::tracking::application::{GetLocationUseCase, UpdateLocationInput, UpdateLocationUseCase};
use crate::shared::AppError;
use crate::state::AppState;

use super::dto::{LocationResponse, UpdateLocationRequest};

pub async fn update_location(
    State(state): State<AppState>,
    Path(job_request_id): Path<Uuid>,
    current_user: TechnicianUser,
    Json(body): Json<UpdateLocationRequest>,
) -> Result<StatusCode, AppError> {
    let use_case = UpdateLocationUseCase::new(
        state.tracking_repository.clone(),
        state.job_repository.clone(),
        state.technician_repository.clone(),
    );

    use_case
        .execute(UpdateLocationInput {
            job_request_id,
            technician_user_id: current_user.user_id,
            latitude: body.latitude,
            longitude: body.longitude,
        })
        .await?;

    Ok(StatusCode::OK)
}

pub async fn get_location(
    State(state): State<AppState>,
    Path(job_request_id): Path<Uuid>,
    current_user: CurrentUser,
) -> Result<Json<LocationResponse>, AppError> {
    let use_case = GetLocationUseCase::new(
        state.tracking_repository.clone(),
        state.job_repository.clone(),
        state.technician_repository.clone(),
    );

    let location = use_case.execute(job_request_id, current_user.user_id).await?;

    Ok(Json(LocationResponse::from(location)))
}
