use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::features::chat::domain::ChatMessage;

#[derive(Serialize)]
pub struct ChatMessageResponse {
    pub id: Uuid,
    pub job_request_id: Uuid,
    pub sender_id: Uuid,
    pub sender_role: String,
    pub text: String,
    pub created_at: String,
}

impl From<ChatMessage> for ChatMessageResponse {
    fn from(m: ChatMessage) -> Self {
        Self {
            id: m.id,
            job_request_id: m.job_request_id,
            sender_id: m.sender_id,
            sender_role: m.sender_role,
            text: m.text,
            created_at: m.created_at.to_rfc3339(),
        }
    }
}

/// Note there is no `sender_role` here on purpose: the role comes from
/// the caller's JWT, never from the request body, so a caller cannot
/// claim to be posting as the other party.
#[derive(Deserialize)]
pub struct SendMessageRequest {
    pub text: String,
}
