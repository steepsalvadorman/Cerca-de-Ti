use axum::extract::State;
use axum::http::StatusCode;
use axum::Json;

use crate::features::auth::interfaces::http::middleware::ClientUser;
use crate::features::client::application::{
    AddAddressInput, AddAddressUseCase, AddPaymentMethodInput, AddPaymentMethodUseCase, GetClientAddressesUseCase,
    GetClientPaymentMethodsUseCase, GetClientProfileStatusUseCase, SaveClientProfileUseCase,
};
use crate::shared::AppError;
use crate::state::AppState;

use super::dto::{
    AddAddressRequest, AddPaymentMethodRequest, AddressResponse, ClientProfileStatusResponse,
    PaymentMethodResponse, SaveClientProfileRequest,
};

pub async fn save_profile(
    State(state): State<AppState>,
    current_user: ClientUser,
    Json(body): Json<SaveClientProfileRequest>,
) -> Result<StatusCode, AppError> {
    let use_case = SaveClientProfileUseCase::new(state.client_repository.clone());
    use_case.execute(current_user.user_id, body.saved).await?;
    Ok(StatusCode::OK)
}

pub async fn get_profile_status(
    State(state): State<AppState>,
    current_user: ClientUser,
) -> Result<Json<ClientProfileStatusResponse>, AppError> {
    let use_case = GetClientProfileStatusUseCase::new(state.client_repository.clone());
    let profile_saved = use_case.execute(current_user.user_id).await?;
    Ok(Json(ClientProfileStatusResponse { profile_saved }))
}

pub async fn get_addresses(
    State(state): State<AppState>,
    current_user: ClientUser,
) -> Result<Json<Vec<AddressResponse>>, AppError> {
    let use_case = GetClientAddressesUseCase::new(state.client_repository.clone());
    let addresses = use_case.execute(current_user.user_id).await?;
    Ok(Json(addresses.into_iter().map(Into::into).collect()))
}

pub async fn add_address(
    State(state): State<AppState>,
    current_user: ClientUser,
    Json(body): Json<AddAddressRequest>,
) -> Result<(StatusCode, Json<AddressResponse>), AppError> {
    let body = body.validated()?;

    let use_case = AddAddressUseCase::new(state.client_repository.clone());
    let address = use_case
        .execute(AddAddressInput {
            client_id: current_user.user_id,
            label: body.label,
            detail: body.detail,
        })
        .await?;
    Ok((StatusCode::CREATED, Json(AddressResponse::from(address))))
}

pub async fn get_payment_methods(
    State(state): State<AppState>,
    current_user: ClientUser,
) -> Result<Json<Vec<PaymentMethodResponse>>, AppError> {
    let use_case = GetClientPaymentMethodsUseCase::new(state.client_repository.clone());
    let methods = use_case.execute(current_user.user_id).await?;
    Ok(Json(methods.into_iter().map(Into::into).collect()))
}

pub async fn add_payment_method(
    State(state): State<AppState>,
    current_user: ClientUser,
    Json(body): Json<AddPaymentMethodRequest>,
) -> Result<(StatusCode, Json<PaymentMethodResponse>), AppError> {
    let body = body.validated()?;

    let use_case = AddPaymentMethodUseCase::new(state.client_repository.clone());
    let method = use_case
        .execute(AddPaymentMethodInput {
            client_id: current_user.user_id,
            label: body.label,
            detail: body.detail,
        })
        .await?;
    Ok((StatusCode::CREATED, Json(PaymentMethodResponse::from(method))))
}
