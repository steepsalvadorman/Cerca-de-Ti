//! Integration tests for technician document uploads, against a real
//! (ephemeral, per-test) Postgres. The bucket itself is faked: signing a
//! URL is pure arithmetic covered by unit tests in the R2 adapter, so
//! what matters here is the bookkeeping around it — which documents may
//! be uploaded, that a confirmation can't be faked, and when a
//! technician flips to verified.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use sqlx::PgPool;
use uuid::Uuid;

use backend::features::technician::application::{
    ConfirmDocumentUploadInput, ConfirmDocumentUploadUseCase, CreateDocumentUploadUrlInput,
    CreateDocumentUploadUrlUseCase, ObjectMetadata, ObjectStorage,
};
use backend::features::technician::domain::{DocStatus, TechnicianError, TechnicianRepository};
use backend::features::technician::infrastructure::PostgresTechnicianRepository;

/// A bucket that behaves like one, in memory.
///
/// It hands back predictable URLs *and* answers `head_object`/
/// `read_prefix`, which is what lets these tests distinguish "the client
/// said it uploaded" from "the bytes are actually there". An object only
/// exists here if a test put it there via [`FakeStorage::store`], so a
/// test that never uploads models exactly the forged-confirmation case.
#[derive(Clone, Default)]
struct FakeStorage {
    objects: Arc<Mutex<HashMap<String, (Vec<u8>, String)>>>,
}

impl FakeStorage {
    /// Simulates the device's `PUT`: records real bytes under `key`.
    fn store(&self, key: &str, bytes: impl Into<Vec<u8>>, content_type: &str) {
        self.objects
            .lock()
            .unwrap()
            .insert(key.to_string(), (bytes.into(), content_type.to_string()));
    }

    /// Records bytes whose declared content type is a lie — what a client
    /// uploading a mismatched file would produce.
    fn store_mismatched(&self, key: &str, bytes: impl Into<Vec<u8>>, declared: &str) {
        self.objects
            .lock()
            .unwrap()
            .insert(key.to_string(), (bytes.into(), declared.to_string()));
    }
}

/// Minimal leading bytes that satisfy the magic-byte check for each type.
fn valid_bytes_for(content_type: &str) -> Vec<u8> {
    match content_type {
        "image/jpeg" => vec![0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46],
        "image/png" => vec![0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D],
        "image/webp" => {
            let mut bytes = b"RIFF".to_vec();
            bytes.extend_from_slice(&[0x00, 0x00, 0x00, 0x00]);
            bytes.extend_from_slice(b"WEBP");
            bytes
        }
        "application/pdf" => b"%PDF-1.7\n%...".to_vec(),
        _ => vec![0x00; 12],
    }
}

#[async_trait::async_trait]
impl ObjectStorage for FakeStorage {
    fn presign_put(
        &self,
        key: &str,
        _content_type: &str,
        _max_bytes: u64,
    ) -> Result<String, TechnicianError> {
        Ok(format!("https://bucket.test/{key}?signed=put"))
    }

    fn presign_get(&self, key: &str) -> Result<String, TechnicianError> {
        Ok(format!("https://bucket.test/{key}?signed=get"))
    }

    async fn head_object(&self, key: &str) -> Result<Option<ObjectMetadata>, TechnicianError> {
        Ok(self
            .objects
            .lock()
            .unwrap()
            .get(key)
            .map(|(bytes, content_type)| ObjectMetadata {
                size_bytes: bytes.len() as u64,
                content_type: Some(content_type.clone()),
            }))
    }

    async fn read_prefix(
        &self,
        key: &str,
        first_bytes: usize,
    ) -> Result<Option<Vec<u8>>, TechnicianError> {
        Ok(self.objects.lock().unwrap().get(key).map(|(bytes, _)| {
            bytes.iter().take(first_bytes).copied().collect()
        }))
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

/// The full two-step flow, with the device really uploading bytes.
///
/// Staging the object *between* the two calls is what makes this a
/// faithful stand-in for the app: the URL is handed out first, then the
/// bytes land, then the device reports back.
async fn upload_and_confirm(pool: &PgPool, storage: &FakeStorage, user_id: Uuid, document_key: &str) {
    upload_and_confirm_as(pool, storage, user_id, document_key, "image/jpeg").await;
}

async fn upload_and_confirm_as(
    pool: &PgPool,
    storage: &FakeStorage,
    user_id: Uuid,
    document_key: &str,
    content_type: &str,
) {
    let output = CreateDocumentUploadUrlUseCase::new(repo(pool), Arc::new(storage.clone()))
        .execute(CreateDocumentUploadUrlInput {
            user_id,
            document_key: document_key.to_string(),
            content_type: content_type.to_string(),
            original_filename: None,
        })
        .await
        .unwrap();

    // The device PUTs. Until this happens the object does not exist, which
    // is precisely the state a forged confirmation tries to skip past.
    storage.store(&output.storage_key, valid_bytes_for(content_type), content_type);

    ConfirmDocumentUploadUseCase::new(repo(pool), Arc::new(storage.clone()))
        .execute(ConfirmDocumentUploadInput { user_id, document_key: document_key.to_string() })
        .await
        .unwrap();
}

#[sqlx::test(migrations = "./migrations")]
async fn requesting_a_slot_stages_the_document_as_pending(pool: PgPool) {
    let user_id = create_technician(&pool).await;

    let output = CreateDocumentUploadUrlUseCase::new(repo(&pool), Arc::new(FakeStorage::default()))
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
    let storage = FakeStorage::default();
    upload_and_confirm(&pool, &storage, user_id, "cedula").await;

    let profile = repo(&pool).find_profile_by_user_id(user_id).await.unwrap().unwrap();
    let documents = repo(&pool).find_documents(profile.id).await.unwrap();
    let document = documents.iter().find(|d| d.document_key == "cedula").unwrap();

    assert_eq!(document.status, DocStatus::Uploaded);
    assert!(document.uploaded_at.is_some());
}

#[sqlx::test(migrations = "./migrations")]
async fn a_document_cannot_be_confirmed_without_an_upload(pool: PgPool) {
    // No upload slot was ever handed out for this document.
    let user_id = create_technician(&pool).await;

    let result = ConfirmDocumentUploadUseCase::new(repo(&pool), Arc::new(FakeStorage::default()))
        .execute(ConfirmDocumentUploadInput { user_id, document_key: "cedula".to_string() })
        .await;

    assert!(matches!(result, Err(TechnicianError::DocumentNotFound)));
}

/// The regression test for GAP-30.
///
/// This is the whole exploit, and it used to succeed: ask for an upload
/// URL, never `PUT` anything, call confirm. Three of those and the
/// technician was verified against an empty bucket, because `confirm` only
/// checked that a row existed with a `storage_key` — a column the earlier
/// step had already written.
#[sqlx::test(migrations = "./migrations")]
async fn confirming_without_uploading_does_not_verify(pool: PgPool) {
    let user_id = create_technician(&pool).await;
    let storage = FakeStorage::default();

    for document_key in ["cedula", "antecedentes", "especialidad"] {
        // Request the slot, then deliberately skip the PUT.
        CreateDocumentUploadUrlUseCase::new(repo(&pool), Arc::new(storage.clone()))
            .execute(CreateDocumentUploadUrlInput {
                user_id,
                document_key: document_key.to_string(),
                content_type: "image/jpeg".to_string(),
                original_filename: None,
            })
            .await
            .unwrap();

        let result = ConfirmDocumentUploadUseCase::new(repo(&pool), Arc::new(storage.clone()))
            .execute(ConfirmDocumentUploadInput {
                user_id,
                document_key: document_key.to_string(),
            })
            .await;

        assert!(
            matches!(result, Err(TechnicianError::DocumentNotFound)),
            "{document_key}: confirming with nothing in the bucket must fail, got {result:?}"
        );
    }

    let profile = repo(&pool).find_profile_by_user_id(user_id).await.unwrap().unwrap();
    assert!(
        !profile.is_verified,
        "an empty bucket must never produce a verified technician"
    );
}

/// GAP-63: the files that are not what they claim to be.
#[sqlx::test(migrations = "./migrations")]
async fn a_file_whose_content_does_not_match_its_type_is_rejected(pool: PgPool) {
    let user_id = create_technician(&pool).await;
    let storage = FakeStorage::default();

    let output = CreateDocumentUploadUrlUseCase::new(repo(&pool), Arc::new(storage.clone()))
        .execute(CreateDocumentUploadUrlInput {
            user_id,
            document_key: "cedula".to_string(),
            content_type: "image/jpeg".to_string(),
            original_filename: None,
        })
        .await
        .unwrap();

    // An HTML document wearing a .jpg key, with the declared type echoed
    // back so only the magic bytes give it away.
    storage.store_mismatched(
        &output.storage_key,
        b"<html><script>alert(1)</script></html>",
        "image/jpeg",
    );

    let result = ConfirmDocumentUploadUseCase::new(repo(&pool), Arc::new(storage.clone()))
        .execute(ConfirmDocumentUploadInput { user_id, document_key: "cedula".to_string() })
        .await;

    assert!(
        matches!(result, Err(TechnicianError::DocumentContentMismatch(_))),
        "a file that is not a JPEG must not be confirmed as one, got {result:?}"
    );
}

/// GAP-62: the size cap is now enforced server-side, since the signed URL
/// cannot carry one and the app's own 10 MB check is not binding on any
/// other client.
#[sqlx::test(migrations = "./migrations")]
async fn an_oversized_document_is_rejected(pool: PgPool) {
    let user_id = create_technician(&pool).await;
    let storage = FakeStorage::default();

    let output = CreateDocumentUploadUrlUseCase::new(repo(&pool), Arc::new(storage.clone()))
        .execute(CreateDocumentUploadUrlInput {
            user_id,
            document_key: "cedula".to_string(),
            content_type: "image/jpeg".to_string(),
            original_filename: None,
        })
        .await
        .unwrap();

    // A real JPEG header, then far too many bytes.
    let mut bytes = valid_bytes_for("image/jpeg");
    bytes.resize((10 * 1024 * 1024) + 1, 0x00);
    storage.store(&output.storage_key, bytes, "image/jpeg");

    let result = ConfirmDocumentUploadUseCase::new(repo(&pool), Arc::new(storage.clone()))
        .execute(ConfirmDocumentUploadInput { user_id, document_key: "cedula".to_string() })
        .await;

    assert!(
        matches!(result, Err(TechnicianError::DocumentTooLarge { .. })),
        "an 10 MB+ document must be refused, got {result:?}"
    );
}

/// An empty object is not a document.
#[sqlx::test(migrations = "./migrations")]
async fn an_empty_upload_is_rejected(pool: PgPool) {
    let user_id = create_technician(&pool).await;
    let storage = FakeStorage::default();

    let output = CreateDocumentUploadUrlUseCase::new(repo(&pool), Arc::new(storage.clone()))
        .execute(CreateDocumentUploadUrlInput {
            user_id,
            document_key: "cedula".to_string(),
            content_type: "application/pdf".to_string(),
            original_filename: None,
        })
        .await
        .unwrap();

    storage.store(&output.storage_key, Vec::<u8>::new(), "application/pdf");

    let result = ConfirmDocumentUploadUseCase::new(repo(&pool), Arc::new(storage.clone()))
        .execute(ConfirmDocumentUploadInput { user_id, document_key: "cedula".to_string() })
        .await;

    assert!(matches!(result, Err(TechnicianError::DocumentContentMismatch(_))));
}

#[sqlx::test(migrations = "./migrations")]
async fn unknown_document_keys_and_file_types_are_rejected(pool: PgPool) {
    let user_id = create_technician(&pool).await;
    let use_case =
        CreateDocumentUploadUrlUseCase::new(repo(&pool), Arc::new(FakeStorage::default()));

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

/// Every allowlisted type must round-trip, so the magic-byte check does
/// not quietly reject a legitimate format.
#[sqlx::test(migrations = "./migrations")]
async fn every_allowed_format_can_be_uploaded(pool: PgPool) {
    for (content_type, document_key) in [
        ("image/jpeg", "cedula"),
        ("image/png", "antecedentes"),
        ("image/webp", "especialidad"),
        ("application/pdf", "seguro"),
    ] {
        let user_id = create_technician(&pool).await;
        let storage = FakeStorage::default();

        upload_and_confirm_as(&pool, &storage, user_id, document_key, content_type).await;

        let profile = repo(&pool).find_profile_by_user_id(user_id).await.unwrap().unwrap();
        let documents = repo(&pool).find_documents(profile.id).await.unwrap();
        let document = documents.iter().find(|d| d.document_key == document_key).unwrap();
        assert_eq!(
            document.status,
            DocStatus::Uploaded,
            "{content_type} must be accepted as a {document_key}"
        );
    }
}

#[sqlx::test(migrations = "./migrations")]
async fn a_technician_is_verified_once_every_mandatory_document_lands(pool: PgPool) {
    let user_id = create_technician(&pool).await;
    let storage = FakeStorage::default();

    upload_and_confirm(&pool, &storage, user_id, "cedula").await;
    upload_and_confirm(&pool, &storage, user_id, "antecedentes").await;

    let halfway = repo(&pool).find_profile_by_user_id(user_id).await.unwrap().unwrap();
    assert!(!halfway.is_verified, "two of three mandatory documents is not enough");

    upload_and_confirm(&pool, &storage, user_id, "especialidad").await;

    let verified = repo(&pool).find_profile_by_user_id(user_id).await.unwrap().unwrap();
    // `seguro` is optional, so verification must not wait for it.
    assert!(verified.is_verified);
}

#[sqlx::test(migrations = "./migrations")]
async fn re_uploading_a_document_sends_it_back_to_pending(pool: PgPool) {
    let user_id = create_technician(&pool).await;
    let storage = FakeStorage::default();
    upload_and_confirm(&pool, &storage, user_id, "cedula").await;

    // Replacing a file must not leave the old one counting as verified
    // while the new upload is still in flight.
    CreateDocumentUploadUrlUseCase::new(repo(&pool), Arc::new(storage.clone()))
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
