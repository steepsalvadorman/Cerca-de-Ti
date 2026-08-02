use axum::extract::{Path, Query, State};
use axum::http::StatusCode;
use axum::Json;
use serde::Deserialize;

use crate::features::auth::interfaces::http::middleware::TechnicianUser;
use crate::features::technician::application::{
    ConfirmDocumentUploadInput, ConfirmDocumentUploadUseCase, CreateDocumentUploadUrlInput,
    CreateDocumentUploadUrlUseCase, GetProvidersUseCase, SaveTechnicianProfileInput,
    SaveTechnicianProfileUseCase,
};
use crate::features::technician::domain::TechnicianError;
use crate::shared::AppError;
use crate::state::AppState;

use super::dto::{
    DocResponse, DocumentUploadUrlRequest, DocumentUploadUrlResponse, ListProvidersResponse,
    SaveProfileRequest, TechnicianResponse,
};

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

pub async fn create_document_upload_url(
    State(state): State<AppState>,
    Path(document_key): Path<String>,
    current_user: TechnicianUser,
    Json(body): Json<DocumentUploadUrlRequest>,
) -> Result<Json<DocumentUploadUrlResponse>, AppError> {
    let use_case = CreateDocumentUploadUrlUseCase::new(
        state.technician_repository.clone(),
        state.object_storage.clone(),
    );

    let output = use_case
        .execute(CreateDocumentUploadUrlInput {
            user_id: current_user.user_id,
            document_key,
            content_type: body.content_type,
            original_filename: body.original_filename,
        })
        .await?;

    Ok(Json(DocumentUploadUrlResponse {
        upload_url: output.upload_url,
        storage_key: output.storage_key,
    }))
}

pub async fn confirm_document_upload(
    State(state): State<AppState>,
    Path(document_key): Path<String>,
    current_user: TechnicianUser,
) -> Result<StatusCode, AppError> {
    let use_case = ConfirmDocumentUploadUseCase::new(state.technician_repository.clone());

    use_case
        .execute(ConfirmDocumentUploadInput {
            user_id: current_user.user_id,
            document_key,
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
