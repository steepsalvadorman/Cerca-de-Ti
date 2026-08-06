use std::sync::Arc;
use uuid::Uuid;

use crate::features::chat::domain::{ChatError, ChatMessage, ChatRepository};
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
            .ok_or(ChatError::Unauthorized)?;

        // Verify that the sender is authorized to chat in this room
        if input.sender_role == "client" {
            if job.client_id != input.sender_id {
                return Err(ChatError::Unauthorized);
            }
        } else if input.sender_role == "technician" {
            // Find technician profile by user_id to compare with job.technician_profile_id
            let tech_profile = self.technician_repo
                .find_profile_by_user_id(input.sender_id)
                .await
                .map_err(|e| ChatError::Repository(e.to_string()))?
                .ok_or(ChatError::Unauthorized)?;

            if job.technician_profile_id != Some(tech_profile.id) {
                return Err(ChatError::Unauthorized);
            }
        } else {
            return Err(ChatError::Unauthorized);
        }

        // Cerca's whole business model is the contact fee, so the channel
        // that hands over contact details stays shut until it is paid.
        if !job.fee_paid {
            return Err(ChatError::FeeNotPaid);
        }

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
