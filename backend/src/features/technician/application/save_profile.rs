use std::sync::Arc;
use uuid::Uuid;

use crate::features::auth::domain::UserRepository;
use crate::features::technician::domain::{TechnicianError, TechnicianProfile, TechnicianRepository};

pub struct SaveTechnicianProfileInput {
    pub user_id: Uuid,
    pub oficio: String,
    pub coverage_km: i32,
    pub available_days: Vec<String>,
    pub categories: Vec<String>,
}

pub struct SaveTechnicianProfileUseCase {
    technician_repo: Arc<dyn TechnicianRepository>,
    user_repo: Arc<dyn UserRepository>,
}

impl SaveTechnicianProfileUseCase {
    pub fn new(
        technician_repo: Arc<dyn TechnicianRepository>,
        user_repo: Arc<dyn UserRepository>,
    ) -> Self {
        Self { technician_repo, user_repo }
    }

    pub async fn execute(&self, input: SaveTechnicianProfileInput) -> Result<(), TechnicianError> {
        let existing = self.technician_repo.find_profile_by_user_id(input.user_id).await?;
        
        let user = self.user_repo
            .find_by_id(input.user_id)
            .await
            .map_err(|e| TechnicianError::Repository(e.to_string()))?
            .ok_or(TechnicianError::TechnicianNotFound)?;

        let profile = match existing {
            Some(mut p) => {
                p.oficio = input.oficio;
                p.coverage_km = input.coverage_km;
                p.available_days = input.available_days;
                p.categories = input.categories;
                p
            }
            None => {
                // Create a new technician profile
                TechnicianProfile {
                    id: 0, // database will assign this
                    user_id: input.user_id,
                    name: user.name.clone(),
                    mono: TechnicianProfile::get_mono(&user.name),
                    oficio: input.oficio,
                    rating: 5.0,
                    reviews: 0,
                    distance: "0.5 km".to_string(),
                    price_label: "Desde S/ 15".to_string(),
                    pin_top: 0.45, // Default mock coordinate pin position
                    pin_left: 0.35,
                    coverage_km: input.coverage_km,
                    available_days: input.available_days,
                    categories: input.categories,
                    is_verified: false,
                }
            }
        };

        self.technician_repo.save_profile(&profile).await?;
        Ok(())
    }
}
