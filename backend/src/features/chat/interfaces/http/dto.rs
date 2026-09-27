use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::features::chat::domain::{ChatMessage, Conversation};
use crate::shared::{validation, AppError};

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

#[derive(Serialize)]
pub struct ConversationResponse {
    pub job_request_id: Uuid,
    pub job_title: Option<String>,
    pub job_status: String,
    pub counterpart_role: String,
    pub counterpart_name: String,
    pub last_message_text: Option<String>,
    pub last_message_at: Option<String>,
    pub last_message_sender_id: Option<Uuid>,
    pub unread_count: i64,
    pub updated_at: String,
}

impl From<Conversation> for ConversationResponse {
    fn from(c: Conversation) -> Self {
        Self {
            job_request_id: c.job_request_id,
            job_title: c.job_title,
            job_status: c.job_status,
            counterpart_role: c.counterpart_role,
            counterpart_name: c.counterpart_name,
            last_message_text: c.last_message_text,
            last_message_at: c.last_message_at.map(|at| at.to_rfc3339()),
            last_message_sender_id: c.last_message_sender_id,
            unread_count: c.unread_count,
            updated_at: c.updated_at.to_rfc3339(),
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

/// Longest message accepted (GAP-02).
///
/// Bounded because the thread is polled: every message is re-sent to both
/// participants on a timer, so one huge message is not a one-off cost but
/// a recurring one. A blank message is rejected too — "send" with an empty
/// box is a mis-tap, and storing it fills the thread with noise.
pub const MAX_MESSAGE_CHARS: usize = 2000;

impl SendMessageRequest {
    pub fn validate(&self) -> Result<(), AppError> {
        validation::required_text("text", &self.text, MAX_MESSAGE_CHARS)?;
        Ok(())
    }
}
