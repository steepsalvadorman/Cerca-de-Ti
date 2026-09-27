use axum::routing::get;
use axum::Router;

use crate::state::AppState;

use super::handlers::{get_conversations, get_messages, send_message};

pub fn chat_routes() -> Router<AppState> {
    Router::new()
        .route("/chats", get(get_conversations))
        .route("/jobs/{id}/messages", get(get_messages).post(send_message))
}
