use async_trait::async_trait;
use chrono::{DateTime, Utc};
use sqlx::PgPool;
use uuid::Uuid;

use crate::features::chat::domain::{ChatError, ChatMessage, ChatRepository, Conversation};

#[derive(sqlx::FromRow)]
struct ChatMessageRow {
    id: Uuid,
    job_request_id: Uuid,
    sender_id: Uuid,
    sender_role: String,
    text: String,
    created_at: DateTime<Utc>,
}

impl From<ChatMessageRow> for ChatMessage {
    fn from(row: ChatMessageRow) -> Self {
        Self {
            id: row.id,
            job_request_id: row.job_request_id,
            sender_id: row.sender_id,
            sender_role: row.sender_role,
            text: row.text,
            created_at: row.created_at,
        }
    }
}

#[derive(sqlx::FromRow)]
struct ConversationRow {
    job_request_id: Uuid,
    job_title: Option<String>,
    job_status: String,
    counterpart_role: String,
    counterpart_name: String,
    last_message_text: Option<String>,
    last_message_at: Option<DateTime<Utc>>,
    last_message_sender_id: Option<Uuid>,
    unread_count: i64,
    updated_at: DateTime<Utc>,
}

impl From<ConversationRow> for Conversation {
    fn from(row: ConversationRow) -> Self {
        Self {
            job_request_id: row.job_request_id,
            job_title: row.job_title,
            job_status: row.job_status,
            counterpart_role: row.counterpart_role,
            counterpart_name: row.counterpart_name,
            last_message_text: row.last_message_text,
            last_message_at: row.last_message_at,
            last_message_sender_id: row.last_message_sender_id,
            unread_count: row.unread_count,
            updated_at: row.updated_at,
        }
    }
}

pub struct PostgresChatRepository {
    pool: PgPool,
}

impl PostgresChatRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl ChatRepository for PostgresChatRepository {
    async fn add_message(&self, message: &ChatMessage) -> Result<(), ChatError> {
        sqlx::query(
            "INSERT INTO chat_messages (id, job_request_id, sender_id, sender_role, text, created_at) \
             VALUES ($1, $2, $3, $4, $5, $6)",
        )
        .bind(message.id)
        .bind(message.job_request_id)
        .bind(message.sender_id)
        .bind(&message.sender_role)
        .bind(&message.text)
        .bind(message.created_at)
        .execute(&self.pool)
        .await
        .map_err(|e| ChatError::Repository(e.to_string()))?;

        Ok(())
    }

    async fn find_messages_by_job_id(&self, job_request_id: Uuid) -> Result<Vec<ChatMessage>, ChatError> {
        let rows = sqlx::query_as::<_, ChatMessageRow>(
            "SELECT id, job_request_id, sender_id, sender_role, text, created_at \
             FROM chat_messages WHERE job_request_id = $1 ORDER BY created_at ASC",
        )
        .bind(job_request_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| ChatError::Repository(e.to_string()))?;

        Ok(rows.into_iter().map(ChatMessage::from).collect())
    }

    async fn mark_read(&self, job_request_id: Uuid, user_id: Uuid, read_at: DateTime<Utc>) -> Result<(), ChatError> {
        sqlx::query(
            "INSERT INTO chat_reads (job_request_id, user_id, last_read_at) VALUES ($1, $2, $3) \
             ON CONFLICT (job_request_id, user_id) \
             DO UPDATE SET last_read_at = GREATEST(chat_reads.last_read_at, EXCLUDED.last_read_at)",
        )
        .bind(job_request_id)
        .bind(user_id)
        .bind(read_at)
        .execute(&self.pool)
        .await
        .map_err(|e| ChatError::Repository(e.to_string()))?;

        Ok(())
    }

    async fn find_conversations(&self, user_id: Uuid) -> Result<Vec<Conversation>, ChatError> {
        // Team jobs are absent on purpose: a team has no user account, so
        // there is nobody on the other side to talk to.
        let rows = sqlx::query_as::<_, ConversationRow>(
            "SELECT j.id AS job_request_id, j.title AS job_title, j.status AS job_status, \
                    CASE WHEN j.client_id = $1 THEN 'technician' ELSE 'client' END AS counterpart_role, \
                    CASE WHEN j.client_id = $1 THEN tu.name ELSE cu.name END AS counterpart_name, \
                    lm.text AS last_message_text, lm.created_at AS last_message_at, \
                    lm.sender_id AS last_message_sender_id, \
                    (SELECT COUNT(*) FROM chat_messages m \
                      WHERE m.job_request_id = j.id AND m.sender_id <> $1 \
                        AND m.created_at > COALESCE(r.last_read_at, '-infinity'::timestamptz)) AS unread_count, \
                    COALESCE(lm.created_at, j.created_at) AS updated_at \
             FROM job_requests j \
             JOIN technician_profiles tp ON tp.id = j.technician_profile_id \
             JOIN users tu ON tu.id = tp.user_id \
             JOIN users cu ON cu.id = j.client_id \
             LEFT JOIN chat_reads r ON r.job_request_id = j.id AND r.user_id = $1 \
             LEFT JOIN LATERAL ( \
                 SELECT text, created_at, sender_id FROM chat_messages \
                 WHERE job_request_id = j.id ORDER BY created_at DESC LIMIT 1 \
             ) lm ON TRUE \
             WHERE (j.client_id = $1 OR tp.user_id = $1) AND j.status <> 'cancelled' \
             ORDER BY updated_at DESC",
        )
        .bind(user_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| ChatError::Repository(e.to_string()))?;

        Ok(rows.into_iter().map(Conversation::from).collect())
    }
}
