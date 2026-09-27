use async_trait::async_trait;
use chrono::{DateTime, Utc};
use uuid::Uuid;

use super::conversation::Conversation;
use super::errors::ChatError;
use super::message::ChatMessage;

#[async_trait]
pub trait ChatRepository: Send + Sync {
    async fn add_message(&self, message: &ChatMessage) -> Result<(), ChatError>;
    async fn find_messages_by_job_id(&self, job_request_id: Uuid) -> Result<Vec<ChatMessage>, ChatError>;

    /// Records that `user_id` has seen the thread up to `read_at`. Never
    /// moves backwards, so a slow, stale poll cannot resurrect unread
    /// messages a newer one already cleared.
    async fn mark_read(&self, job_request_id: Uuid, user_id: Uuid, read_at: DateTime<Utc>) -> Result<(), ChatError>;

    /// Every job `user_id` can chat on with someone else: as the client
    /// with an assigned technician, or as that technician. Cancelled jobs
    /// are left out because their thread can no longer be read.
    async fn find_conversations(&self, user_id: Uuid) -> Result<Vec<Conversation>, ChatError>;
}
