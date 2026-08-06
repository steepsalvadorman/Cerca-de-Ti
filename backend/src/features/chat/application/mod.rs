pub mod send_message;

use std::sync::Arc;
use uuid::Uuid;

pub use send_message::{SendMessageInput, SendMessageUseCase};

use crate::features::chat::domain::{ChatError, ChatMessage, ChatRepository};
use crate::features::job::domain::JobRepository;
use crate::features::technician::domain::TechnicianRepository;

pub struct GetMessagesUseCase {
    chat_repo: Arc<dyn ChatRepository>,
    job_repo: Arc<dyn JobRepository>,
    technician_repo: Arc<dyn TechnicianRepository>,
}

impl GetMessagesUseCase {
    pub fn new(
        chat_repo: Arc<dyn ChatRepository>,
        job_repo: Arc<dyn JobRepository>,
        technician_repo: Arc<dyn TechnicianRepository>,
    ) -> Self {
        Self {
            chat_repo,
            job_repo,
            technician_repo,
        }
    }

    pub async fn execute(&self, job_request_id: Uuid, reader_id: Uuid) -> Result<Vec<ChatMessage>, ChatError> {
        let job = self.job_repo
            .find_job_request_by_id(job_request_id)
            .await
            .map_err(|e| ChatError::Repository(e.to_string()))?
            .ok_or(ChatError::Unauthorized)?;

        let mut is_authorized = job.client_id == reader_id;

        if !is_authorized {
            if let Some(tech_id) = job.technician_profile_id {
                if let Some(tech_profile) = self.technician_repo
                    .find_profile_by_user_id(reader_id)
                    .await
                    .map_err(|e| ChatError::Repository(e.to_string()))?
                {
                    if tech_profile.id == tech_id {
                        is_authorized = true;
                    }
                }
            }
        }

        if !is_authorized {
            return Err(ChatError::Unauthorized);
        }

        // Same gate as sending: reading the thread would expose whatever
        // contact details were already exchanged.
        if !job.fee_paid {
            return Err(ChatError::FeeNotPaid);
        }

        self.chat_repo.find_messages_by_job_id(job_request_id).await
    }
}
