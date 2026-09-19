use std::sync::Arc;
use uuid::Uuid;

use crate::features::chat::domain::{ChatError, ChatMessage, ChatRepository};
use crate::features::job::application::job_participation::{
    ensure_chat_writable, is_job_participant,
};
use crate::features::job::domain::JobRepository;
use crate::features::technician::domain::TechnicianRepository;

pub struct SendMessageInput {
    pub job_request_id: Uuid,
    pub sender_id: Uuid,
    pub sender_role: String, // "client" | "technician"
    pub text: String,
}

pub struct SendMessageUseCase {
    chat_repo: Arc<dyn ChatRepository>,
    job_repo: Arc<dyn JobRepository>,
    technician_repo: Arc<dyn TechnicianRepository>,
}

impl SendMessageUseCase {
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

    pub async fn execute(&self, input: SendMessageInput) -> Result<ChatMessage, ChatError> {
        let job = self.job_repo
            .find_job_request_by_id(input.job_request_id)
            .await
            .map_err(|e| ChatError::Repository(e.to_string()))?
            .ok_or(ChatError::JobNotFound)?;

        if !is_job_participant(&job, input.sender_id, &self.technician_repo)
            .await
            .map_err(|e| ChatError::Repository(e.to_string()))?
        {
            return Err(ChatError::Unauthorized);
        }

        // The HTTP layer still labels the sender; double-check the role
        // matches who they actually are on this job.
        if input.sender_role == "client" && job.client_id != input.sender_id {
            return Err(ChatError::Unauthorized);
        } else if input.sender_role == "technician" {
            let tech_profile = self.technician_repo
                .find_profile_by_user_id(input.sender_id)
                .await
                .map_err(|e| ChatError::Repository(e.to_string()))?
                .ok_or(ChatError::Unauthorized)?;

            if job.technician_profile_id != Some(tech_profile.id) {
                return Err(ChatError::Unauthorized);
            }
        } else if input.sender_role != "client" {
            return Err(ChatError::Unauthorized);
        }

        ensure_chat_writable(&job.status)?;

        let message = ChatMessage::new(
            input.job_request_id,
            input.sender_id,
            input.sender_role,
            input.text,
        );

        self.chat_repo.add_message(&message).await?;
        Ok(message)
    }
}
