use serde::{Deserialize, Serialize};

use crate::features::technician::domain::{TechTeam, TechnicianDocument, TechnicianProfile};
use crate::shared::{validation, AppError};

#[derive(Serialize)]
pub struct TechnicianResponse {
    pub id: i32,
    pub name: String,
    pub mono: String,
    pub oficio: String,
    pub rating: f64,
    pub reviews: i32,
    pub distance: String,
    pub price_label: String,
    pub pin_top: f64,
    pub pin_left: f64,
    pub coverage_km: i32,
    pub available_days: Vec<String>,
    pub categories: Vec<String>,
    pub is_verified: bool,
}

impl From<TechnicianProfile> for TechnicianResponse {
    fn from(p: TechnicianProfile) -> Self {
        Self {
            id: p.id,
            name: p.name,
            mono: p.mono,
            oficio: p.oficio,
            rating: p.rating,
            reviews: p.reviews,
            distance: p.distance,
            price_label: p.price_label,
            pin_top: p.pin_top,
            pin_left: p.pin_left,
            coverage_km: p.coverage_km,
            available_days: p.available_days,
            categories: p.categories,
            is_verified: p.is_verified,
        }
    }
}

#[derive(Serialize)]
pub struct TechTeamResponse {
    pub id: i32,
    pub name: String,
    pub mono: String,
    pub oficio: String,
    pub rating: f64,
    pub reviews: i32,
    pub distance: String,
    pub price_label: String,
    pub pin_top: f64,
    pub pin_left: f64,
    pub crew: i32,
    pub projects: i32,
    pub labor_cost: i32,
    pub materials_cost: i32,
    pub mobility_cost: i32,
}

impl From<TechTeam> for TechTeamResponse {
    fn from(t: TechTeam) -> Self {
        Self {
            id: t.id,
            name: t.name,
            mono: t.mono,
            oficio: t.oficio,
            rating: t.rating,
            reviews: t.reviews,
            distance: t.distance,
            price_label: t.price_label,
            pin_top: t.pin_top,
            pin_left: t.pin_left,
            crew: t.crew,
            projects: t.projects,
            labor_cost: t.labor_cost,
            materials_cost: t.materials_cost,
            mobility_cost: t.mobility_cost,
        }
    }
}

#[derive(Serialize)]
pub struct ListProvidersResponse {
    pub technicians: Vec<TechnicianResponse>,
    pub teams: Vec<TechTeamResponse>,
}

#[derive(Deserialize)]
pub struct SaveProfileRequest {
    pub oficio: String,
    pub price_label: String,
    pub coverage_km: i32,
    pub available_days: Vec<String>,
    pub categories: Vec<String>,
}

pub const MAX_OFICIO_CHARS: usize = 80;
pub const MAX_PRICE_LABEL_CHARS: usize = 60;
pub const MIN_COVERAGE_KM: i32 = 1;
/// Roughly the width of Peru. A radius beyond this is not a coverage area,
/// it is a typo, and a `coverage_km` of `i32::MAX` was accepted before
/// (GAP-32).
pub const MAX_COVERAGE_KM: i32 = 500;
pub const WEEK_DAYS: [&str; 7] = ["lun", "mar", "mie", "jue", "vie", "sab", "dom"];
/// The canonical trade list. The client's own list is a copy of this one;
/// this is the copy that decides.
pub const TRADE_CATEGORIES: [&str; 12] = [
    "gasfiteria",
    "electricidad",
    "carpinteria",
    "pintura",
    "cerrajeria",
    "electrodomesticos",
    "jardineria",
    "climatizacion",
    "piscinas",
    "pozos",
    "tarrajeo",
    "construccion",
];

impl SaveProfileRequest {
    pub fn validate(&self) -> Result<(), AppError> {
        validation::required_text("oficio", &self.oficio, MAX_OFICIO_CHARS)?;
        validation::required_text("price_label", &self.price_label, MAX_PRICE_LABEL_CHARS)?;
        validation::in_range(
            "coverage_km",
            self.coverage_km as i64,
            MIN_COVERAGE_KM as i64,
            MAX_COVERAGE_KM as i64,
        )?;

        if self.available_days.is_empty() {
            return Err(AppError::Validation(
                "selecciona al menos un día disponible".to_string(),
            ));
        }
        validation::list_of_known("available_days", &self.available_days, &WEEK_DAYS, 7)?;

        if self.categories.is_empty() {
            return Err(AppError::Validation(
                "selecciona al menos una especialidad".to_string(),
            ));
        }
        // Without this a technician advertised `categories: ["xyz"]` and
        // appeared in `/providers` for a trade they do not work in.
        validation::list_of_known("categories", &self.categories, &TRADE_CATEGORIES, 12)?;

        Ok(())
    }
}

#[derive(Deserialize)]
pub struct DocumentUploadUrlRequest {
    /// MIME type of the file about to be uploaded, checked against the
    /// allowlist in `upload_document.rs`.
    pub content_type: String,
    /// Only kept so a reviewer sees what the technician picked; the
    /// object itself is stored under a generated key.
    pub original_filename: Option<String>,
}

/// Longest original filename kept. It is echoed back in any future review
/// screen, and was previously stored verbatim — including a 5 MB name, a
/// path, or a fragment of HTML (GAP-64).
pub const MAX_ORIGINAL_FILENAME_CHARS: usize = 255;

impl DocumentUploadUrlRequest {
    pub fn validate(&self) -> Result<(), AppError> {
        validation::optional_text(
            "original_filename",
            self.original_filename.as_deref(),
            MAX_ORIGINAL_FILENAME_CHARS,
        )?;
        Ok(())
    }
}

#[derive(Serialize)]
pub struct DocumentUploadUrlResponse {
    pub upload_url: String,
    pub storage_key: String,
}

#[derive(Serialize)]
pub struct DocResponse {
    pub document_key: String,
    pub status: String,
    pub uploaded_at: Option<String>,
}

impl From<TechnicianDocument> for DocResponse {
    fn from(d: TechnicianDocument) -> Self {
        Self {
            document_key: d.document_key,
            status: d.status.as_str().to_string(),
            uploaded_at: d.uploaded_at.map(|at| at.to_rfc3339()),
        }
    }
}
