use axum::extract::{Query, State};
use axum::http::StatusCode;
use axum::Json;
use serde::Deserialize;

use crate::features::auth::interfaces::http::middleware::TechnicianUser;
use crate::features::technician::application::{
    GetProvidersUseCase, SaveTechnicianProfileInput, SaveTechnicianProfileUseCase, ToggleDocumentInput,
    ToggleDocumentUseCase,
};
use crate::features::technician::domain::{DocStatus, TechnicianError};
use crate::shared::AppError;
use crate::state::AppState;

use super::dto::{DocResponse, ListProvidersResponse, SaveProfileRequest, TechnicianResponse, ToggleDocRequest};

#[derive(Deserialize)]
pub struct CategoryQuery {
    category: Option<String>,
}

pub async fn get_providers(
    State(state): State<AppState>,
    Query(query): Query<CategoryQuery>,
) -> Result<Json<ListProvidersResponse>, AppError> {
    let use_case = GetProvidersUseCase::new(state.technician_repository.clone());
    let output = use_case.execute(query.category).await?;

    Ok(Json(ListProvidersResponse {
        technicians: output.technicians.into_iter().map(Into::into).collect(),
        teams: output.teams.into_iter().map(Into::into).collect(),
    }))
}

pub async fn get_my_profile(
    State(state): State<AppState>,
    current_user: TechnicianUser,
) -> Result<Json<TechnicianResponse>, AppError> {
    let profile = state
        .technician_repository
        .find_profile_by_user_id(current_user.user_id)
        .await?
        .ok_or(AppError::Technician(TechnicianError::TechnicianNotFound))?;

    Ok(Json(TechnicianResponse::from(profile)))
}

pub async fn save_profile(
    State(state): State<AppState>,
    current_user: TechnicianUser,
    Json(body): Json<SaveProfileRequest>,
) -> Result<StatusCode, AppError> {
    let use_case = SaveTechnicianProfileUseCase::new(
        state.technician_repository.clone(),
        state.user_repository.clone(),
    );

    use_case
        .execute(SaveTechnicianProfileInput {
            user_id: current_user.user_id,
            oficio: body.oficio,
            coverage_km: body.coverage_km,
            available_days: body.available_days,
            categories: body.categories,
        })
        .await?;

    Ok(StatusCode::OK)
}

pub async fn toggle_document(
    State(state): State<AppState>,
    current_user: TechnicianUser,
    Json(body): Json<ToggleDocRequest>,
) -> Result<StatusCode, AppError> {
    let use_case = ToggleDocumentUseCase::new(state.technician_repository.clone());
    let status = DocStatus::parse(&body.status)
        .map_err(|e| AppError::Technician(TechnicianError::InvalidDocumentStatus(e)))?;

    use_case
        .execute(ToggleDocumentInput {
            user_id: current_user.user_id,
            document_key: body.document_key,
            status,
        })
        .await?;

    Ok(StatusCode::OK)
}

pub async fn get_documents(
    State(state): State<AppState>,
    current_user: TechnicianUser,
) -> Result<Json<Vec<DocResponse>>, AppError> {
    let profile = state
        .technician_repository
        .find_profile_by_user_id(current_user.user_id)
        .await?
        .ok_or(AppError::Technician(TechnicianError::TechnicianNotFound))?;

    let docs = state.technician_repository.find_documents(profile.id).await?;

    Ok(Json(docs.into_iter().map(Into::into).collect()))
}
