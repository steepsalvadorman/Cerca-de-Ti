//! Integration tests for technician document uploads, against a real
//! (ephemeral, per-test) Postgres. The bucket itself is faked: signing a
//! URL is pure arithmetic covered by unit tests in the R2 adapter, so
//! what matters here is the bookkeeping around it — which documents may
//! be uploaded, that a confirmation can't be faked, and when a
//! technician flips to verified.

use std::sync::Arc;

use sqlx::PgPool;
use uuid::Uuid;

use backend::features::technician::application::{
    ConfirmDocumentUploadInput, ConfirmDocumentUploadUseCase, CreateDocumentUploadUrlInput,
    CreateDocumentUploadUrlUseCase, ObjectStorage,
};
use backend::features::technician::domain::{DocStatus, TechnicianError, TechnicianRepository};
use backend::features::technician::infrastructure::PostgresTechnicianRepository;

/// Hands back a predictable URL so a test can assert the key it was
/// asked to sign without talking to Cloudflare.
struct FakeStorage;

impl ObjectStorage for FakeStorage {
    fn presign_put(&self, key: &str, _content_type: &str) -> Result<String, TechnicianError> {
        Ok(format!("https://bucket.test/{key}?signed=put"))
    }

    fn presign_get(&self, key: &str) -> Result<String, TechnicianError> {
        Ok(format!("https://bucket.test/{key}?signed=get"))
    }
}

async fn create_technician(pool: &PgPool) -> Uuid {
    let id = Uuid::new_v4();
    sqlx::query("INSERT INTO users (id, email, name, role, password_hash) VALUES ($1, $2, 'Test Tech', 'technician', 'hash')")
        .bind(id)
        .bind(format!("{id}@test.local"))
        .execute(pool)
        .await
        .unwrap();

    sqlx::query("INSERT INTO technician_profiles (user_id, oficio, pin_top, pin_left) VALUES ($1, 'Gasfitero', 0.5, 0.5)")
        .bind(id)
        .execute(pool)
        .await
        .unwrap();

    id
}

fn repo(pool: &PgPool) -> Arc<dyn TechnicianRepository> {
    Arc::new(PostgresTechnicianRepository::new(pool.clone()))
}

async fn upload_and_confirm(pool: &PgPool, user_id: Uuid, document_key: &str) {
    CreateDocumentUploadUrlUseCase::new(repo(pool), Arc::new(FakeStorage))
        .execute(CreateDocumentUploadUrlInput {
            user_id,
            document_key: document_key.to_string(),
            content_type: "image/jpeg".to_string(),
            original_filename: None,
        })
        .await
        .unwrap();

    ConfirmDocumentUploadUseCase::new(repo(pool))
        .execute(ConfirmDocumentUploadInput { user_id, document_key: document_key.to_string() })
        .await
        .unwrap();
}

#[sqlx::test(migrations = "./migrations")]
async fn requesting_a_slot_stages_the_document_as_pending(pool: PgPool) {
    let user_id = create_technician(&pool).await;

    let output = CreateDocumentUploadUrlUseCase::new(repo(&pool), Arc::new(FakeStorage))
        .execute(CreateDocumentUploadUrlInput {
            user_id,
            document_key: "cedula".to_string(),
            content_type: "application/pdf".to_string(),
            original_filename: Some("mi cedula.pdf".to_string()),
        })
        .await
        .unwrap();

    let profile = repo(&pool).find_profile_by_user_id(user_id).await.unwrap().unwrap();
    assert!(output.storage_key.starts_with(&format!("technicians/{}/cedula/", profile.id)));
    assert!(output.storage_key.ends_with(".pdf"), "extension must follow the content type");
    assert!(output.upload_url.contains(&output.storage_key));

    let documents = repo(&pool).find_documents(profile.id).await.unwrap();
    let document = documents.iter().find(|d| d.document_key == "cedula").unwrap();
    // Staged, not uploaded: no bytes have been confirmed yet.
    assert_eq!(document.status, DocStatus::Pending);
    assert_eq!(document.storage_key, Some(output.storage_key));
    assert_eq!(document.original_filename.as_deref(), Some("mi cedula.pdf"));
    assert!(document.uploaded_at.is_none());
}

#[sqlx::test(migrations = "./migrations")]
async fn confirming_marks_the_document_uploaded(pool: PgPool) {
    let user_id = create_technician(&pool).await;
    upload_and_confirm(&pool, user_id, "cedula").await;

    let profile = repo(&pool).find_profile_by_user_id(user_id).await.unwrap().unwrap();
    let documents = repo(&pool).find_documents(profile.id).await.unwrap();
    let document = documents.iter().find(|d| d.document_key == "cedula").unwrap();

    assert_eq!(document.status, DocStatus::Uploaded);
    assert!(document.uploaded_at.is_some());
}

#[sqlx::test(migrations = "./migrations")]
async fn a_document_cannot_be_confirmed_without_an_upload(pool: PgPool) {
    // The whole point of the two-step flow: without this, a client could
    // mark itself verified by calling confirm for every document.
    let user_id = create_technician(&pool).await;

    let result = ConfirmDocumentUploadUseCase::new(repo(&pool))
        .execute(ConfirmDocumentUploadInput { user_id, document_key: "cedula".to_string() })
        .await;

    assert!(matches!(result, Err(TechnicianError::DocumentNotFound)));
}

#[sqlx::test(migrations = "./migrations")]
async fn unknown_document_keys_and_file_types_are_rejected(pool: PgPool) {
    let user_id = create_technician(&pool).await;
    let use_case = CreateDocumentUploadUrlUseCase::new(repo(&pool), Arc::new(FakeStorage));

    let bad_key = use_case
        .execute(CreateDocumentUploadUrlInput {
            user_id,
            document_key: "pasaporte".to_string(),
            content_type: "image/jpeg".to_string(),
            original_filename: None,
        })
        .await;
    assert!(matches!(bad_key, Err(TechnicianError::InvalidDocumentKey(_))));

    let bad_type = use_case
        .execute(CreateDocumentUploadUrlInput {
            user_id,
            document_key: "cedula".to_string(),
            content_type: "application/x-msdownload".to_string(),
            original_filename: None,
        })
        .await;
    assert!(matches!(bad_type, Err(TechnicianError::InvalidContentType(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn a_technician_is_verified_once_every_mandatory_document_lands(pool: PgPool) {
    let user_id = create_technician(&pool).await;

    upload_and_confirm(&pool, user_id, "cedula").await;
    upload_and_confirm(&pool, user_id, "antecedentes").await;

    let halfway = repo(&pool).find_profile_by_user_id(user_id).await.unwrap().unwrap();
    assert!(!halfway.is_verified, "two of three mandatory documents is not enough");

    upload_and_confirm(&pool, user_id, "especialidad").await;

    let verified = repo(&pool).find_profile_by_user_id(user_id).await.unwrap().unwrap();
    // `seguro` is optional, so verification must not wait for it.
    assert!(verified.is_verified);
}

#[sqlx::test(migrations = "./migrations")]
async fn re_uploading_a_document_sends_it_back_to_pending(pool: PgPool) {
    let user_id = create_technician(&pool).await;
    upload_and_confirm(&pool, user_id, "cedula").await;

    // Replacing a file must not leave the old one counting as verified
    // while the new upload is still in flight.
    CreateDocumentUploadUrlUseCase::new(repo(&pool), Arc::new(FakeStorage))
        .execute(CreateDocumentUploadUrlInput {
            user_id,
            document_key: "cedula".to_string(),
            content_type: "image/png".to_string(),
            original_filename: None,
        })
        .await
        .unwrap();

    let profile = repo(&pool).find_profile_by_user_id(user_id).await.unwrap().unwrap();
    let documents = repo(&pool).find_documents(profile.id).await.unwrap();
    let document = documents.iter().find(|d| d.document_key == "cedula").unwrap();

    assert_eq!(document.status, DocStatus::Pending);
    assert!(document.uploaded_at.is_none());
}
