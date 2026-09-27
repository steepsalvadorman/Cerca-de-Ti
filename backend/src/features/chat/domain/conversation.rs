use chrono::{DateTime, Utc};
use uuid::Uuid;

/// One row of the chat inbox: a job the caller takes part in, who is on
/// the other side, and where the thread stands.
#[derive(Debug, Clone)]
pub struct Conversation {
    pub job_request_id: Uuid,
    pub job_title: Option<String>,
    pub job_status: String,
    /// "client" or "technician" — the role of the *other* participant.
    pub counterpart_role: String,
    pub counterpart_name: String,
    pub last_message_text: Option<String>,
    pub last_message_at: Option<DateTime<Utc>>,
    pub last_message_sender_id: Option<Uuid>,
    /// Messages from the other participant newer than the caller's last read.
    pub unread_count: i64,
    /// Latest activity: the last message, or the job's creation if the
    /// thread is still empty. The inbox is ordered by this, newest first.
    pub updated_at: DateTime<Utc>,
}
