use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::Json;
use uuid::Uuid;

use crate::features::auth::interfaces::http::middleware::{ClientUser, CurrentUser, TechnicianUser};
use crate::features::job::application::{
    AdvanceProgressUseCase, ChooseOfferInput, ChooseOfferUseCase, CreateJobInput, CreateJobUseCase,
    GetClientHistoryUseCase, GetJobOffersUseCase, GetJobRequestUseCase, GetTechnicianJobsUseCase,
    PayFeeInput, PayFeeUseCase, RateJobInput, RateJobUseCase, SubmitOfferInput, SubmitOfferUseCase,
};
use crate::features::job::domain::JobError;
use crate::shared::AppError;
use crate::state::AppState;

use super::dto::{
    ChooseOfferRequest, CreateJobRequest, JobOfferResponse, JobRequestResponse, PayFeeRequest,
    RateJobRequest, SubmitOfferRequest, TechnicianJobsResponse,
};

pub async fn create_job(
    State(state): State<AppState>,
    current_user: ClientUser,
    Json(body): Json<CreateJobRequest>,
) -> Result<(StatusCode, Json<JobRequestResponse>), AppError> {
    let use_case = CreateJobUseCase::new(state.job_repository.clone());
    let job = use_case
        .execute(CreateJobInput {
            client_id: current_user.user_id,
            technician_profile_id: body.technician_profile_id,
            tech_team_id: body.tech_team_id,
            job_kind: body.job_kind,
            title: body.title,
            address: body.address,
            mobility_included: body.mobility_included,
        })
        .await?;

    Ok((StatusCode::CREATED, Json(JobRequestResponse::from(job))))
}

pub async fn get_job(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    current_user: CurrentUser,
) -> Result<Json<JobRequestResponse>, AppError> {
    let use_case = GetJobRequestUseCase::new(state.job_repository.clone(), state.technician_repository.clone());
    let job = use_case
        .execute(id, current_user.user_id)
        .await?
        .ok_or(AppError::Job(JobError::JobNotFound))?;

    Ok(Json(JobRequestResponse::from(job)))
}

pub async fn pay_fee(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    current_user: ClientUser,
    Json(body): Json<PayFeeRequest>,
) -> Result<StatusCode, AppError> {
    let use_case = PayFeeUseCase::new(state.job_repository.clone());
    use_case
        .execute(PayFeeInput {
            job_request_id: id,
            client_id: current_user.user_id,
            payment_method: body.payment_method,
        })
        .await?;

    Ok(StatusCode::OK)
}

pub async fn advance_progress(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    current_user: CurrentUser,
) -> Result<StatusCode, AppError> {
    let use_case = AdvanceProgressUseCase::new(state.job_repository.clone(), state.technician_repository.clone());
    use_case.execute(id, current_user.user_id).await?;

    Ok(StatusCode::OK)
}

pub async fn rate_job(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    current_user: ClientUser,
    Json(body): Json<RateJobRequest>,
) -> Result<StatusCode, AppError> {
    let use_case = RateJobUseCase::new(state.job_repository.clone());
    use_case
        .execute(RateJobInput {
            job_request_id: id,
            client_id: current_user.user_id,
            rating: body.rating,
            comment: body.comment,
        })
        .await?;

    Ok(StatusCode::OK)
}

pub async fn get_offers(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    current_user: CurrentUser,
) -> Result<Json<Vec<JobOfferResponse>>, AppError> {
    let use_case = GetJobOffersUseCase::new(state.job_repository.clone(), state.technician_repository.clone());
    let offers = use_case.execute(id, current_user.user_id).await?;

    Ok(Json(offers.into_iter().map(Into::into).collect()))
}

pub async fn submit_offer(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    current_user: TechnicianUser,
    Json(body): Json<SubmitOfferRequest>,
) -> Result<StatusCode, AppError> {
    let use_case = SubmitOfferUseCase::new(state.job_repository.clone(), state.technician_repository.clone());
    use_case
        .execute(SubmitOfferInput {
            job_request_id: id,
            technician_user_id: current_user.user_id,
            price: body.price,
            eta: body.eta,
        })
        .await?;

    Ok(StatusCode::CREATED)
}

pub async fn choose_offer(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    current_user: ClientUser,
    Json(body): Json<ChooseOfferRequest>,
) -> Result<StatusCode, AppError> {
    let use_case = ChooseOfferUseCase::new(state.job_repository.clone());
    use_case
        .execute(ChooseOfferInput {
            job_request_id: id,
            client_id: current_user.user_id,
            offer_id: body.offer_id,
        })
        .await?;

    Ok(StatusCode::OK)
}

pub async fn get_client_history(
    State(state): State<AppState>,
    current_user: ClientUser,
) -> Result<Json<Vec<JobRequestResponse>>, AppError> {
    let use_case = GetClientHistoryUseCase::new(state.job_repository.clone());
    let history = use_case.execute(current_user.user_id).await?;

    Ok(Json(history.into_iter().map(Into::into).collect()))
}

pub async fn get_technician_jobs(
    State(state): State<AppState>,
    current_user: TechnicianUser,
) -> Result<Json<TechnicianJobsResponse>, AppError> {
    let use_case = GetTechnicianJobsUseCase::new(state.job_repository.clone(), state.technician_repository.clone());
    let jobs = use_case.execute(current_user.user_id).await?;

    Ok(Json(TechnicianJobsResponse::from(jobs)))
}
