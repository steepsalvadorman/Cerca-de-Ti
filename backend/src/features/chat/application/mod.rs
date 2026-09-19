pub mod send_message;

use std::sync::Arc;
use uuid::Uuid;

pub use send_message::{SendMessageInput, SendMessageUseCase};

use crate::features::chat::domain::{ChatError, ChatMessage, ChatRepository};
use crate::features::job::application::job_participation::{
    ensure_chat_readable, is_job_participant,
};
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
            .ok_or(ChatError::JobNotFound)?;

        if !is_job_participant(&job, reader_id, &self.technician_repo)
            .await
            .map_err(|e| ChatError::Repository(e.to_string()))?
        {
            return Err(ChatError::Unauthorized);
        }

        ensure_chat_readable(&job.status)?;

        self.chat_repo.find_messages_by_job_id(job_request_id).await
    }
}
