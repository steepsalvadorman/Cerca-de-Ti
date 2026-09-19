use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::Json;
use uuid::Uuid;

use crate::features::auth::interfaces::http::middleware::{ClientUser, CurrentUser, TechnicianUser};
use crate::features::job::application::{
    AdvanceProgressUseCase, CancelJobInput, CancelJobUseCase, ChooseOfferInput, ChooseOfferUseCase,
    CreateJobInput, CreateJobUseCase, GetClientHistoryUseCase, GetJobOffersUseCase,
    GetJobRequestUseCase, GetTechnicianJobsUseCase, PayFeeInput, PayFeeUseCase, RateJobInput,
    RateJobUseCase, SubmitOfferInput, SubmitOfferUseCase,
};
use crate::features::job::domain::JobError;
use crate::shared::AppError;
use crate::state::AppState;

use super::dto::{
    CancelJobRequest, ChooseOfferRequest, CreateJobRequest, JobOfferResponse, JobRequestResponse,
    JobView, PayFeeRequest, PayFeeResponse, RateJobRequest, SubmitOfferRequest, TechnicianJobsResponse,
};

pub async fn create_job(
    State(state): State<AppState>,
    current_user: ClientUser,
    Json(body): Json<CreateJobRequest>,
) -> Result<(StatusCode, Json<JobView>), AppError> {
    body.validate()?;

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

    // The creator is the owning client by construction.
    Ok((StatusCode::CREATED, Json(JobView::Full(Box::new(job.into())))))
}

pub async fn get_job(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    current_user: CurrentUser,
) -> Result<Json<JobView>, AppError> {
    let use_case = GetJobRequestUseCase::new(state.job_repository.clone(), state.technician_repository.clone());
    let found = use_case
        .execute(id, current_user.user_id)
        .await?
        .ok_or(AppError::Job(JobError::JobNotFound))?;

    // The payload depends on *how* the caller is related to the job: a
    // technician who may bid on it gets the restricted view, never the
    // client's identity or address.
    Ok(Json(JobView::for_access(found.job, found.access)))
}

pub async fn pay_fee(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    current_user: ClientUser,
    Json(body): Json<PayFeeRequest>,
) -> Result<Json<PayFeeResponse>, AppError> {
    let payment_method = body.validate()?;

    let use_case = PayFeeUseCase::new(state.job_repository.clone(), state.payment_gateway.clone());
    let result = use_case
        .execute(PayFeeInput {
            job_request_id: id,
            client_id: current_user.user_id,
            payment_method,
        })
        .await?;

    Ok(Json(PayFeeResponse {
        gateway_reference: result.gateway_reference,
        simulated: result.simulated,
    }))
}

/// Moves the job along its timeline. Technician-only: a client closing
/// their own job would be marking work complete that they cannot verify,
/// and rating it straight afterwards (GAP-15). The role gate lives in the
/// extractor so the rejection is a clean 403 before the use case runs.
pub async fn advance_progress(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    current_user: TechnicianUser,
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
    body.validate()?;

    let use_case = RateJobUseCase::new(
        state.job_repository.clone(),
        state.technician_repository.clone(),
    );
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

/// Ends an open or in-progress job. Client-only: the client is the one who
/// posted the work, and a technician walking away is an abandonment rather
/// than a cancellation (GAP-19).
pub async fn cancel_job(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    current_user: ClientUser,
    Json(body): Json<CancelJobRequest>,
) -> Result<StatusCode, AppError> {
    let use_case = CancelJobUseCase::new(state.job_repository.clone());
    use_case
        .execute(CancelJobInput {
            job_request_id: id,
            client_id: current_user.user_id,
            reason: body.reason,
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
