use async_trait::async_trait;

use crate::features::technician::domain::TechnicianError;

/// What the bucket reports about a stored object. Only the fields the
/// confirmation step needs to make a decision.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ObjectMetadata {
    pub size_bytes: u64,
    /// The type the bucket actually recorded, which is what the upload
    /// really was — not what the client declared when it asked for a URL.
    pub content_type: Option<String>,
}

/// Technical capability for storing verification documents, kept as an
/// application-level port for the same reason `PasswordHasher` is one:
/// which bucket (or none at all) is a delivery detail.
///
/// `presign_put`/`presign_get` hand back a time-limited signed URL instead
/// of moving bytes through this process — the device uploads straight to
/// the bucket, so the API stays a thin control plane.
///
/// `head_object` exists because that thinness had a cost: the signed URL
/// carried no constraint on size or type, and nothing ever looked at what
/// landed in the bucket, so a client could declare `image/jpeg`, upload
/// anything at all (or nothing), and have the server believe it. See
/// GAP-30/GAP-62/GAP-63.
#[async_trait]
pub trait ObjectStorage: Send + Sync {
    /// URL the client may `PUT` the file to, valid for a few minutes.
    ///
    /// `content_type` and `max_bytes` are inputs to the signature: a
    /// provider that supports a POST policy can refuse a mismatched
    /// upload outright, and one that does not still lets the caller
    /// enforce both after the fact via [`Self::head_object`].
    fn presign_put(
        &self,
        key: &str,
        content_type: &str,
        max_bytes: u64,
    ) -> Result<String, TechnicianError>;

    /// URL to read the object back. Documents are identity papers, so the
    /// bucket is private and even reads go through a short-lived URL.
    fn presign_get(&self, key: &str) -> Result<String, TechnicianError>;

    /// Asks the bucket what is actually stored under `key`.
    ///
    /// `Ok(None)` means the object does not exist — which is the normal,
    /// expected answer when a client requests an upload URL and never
    /// uses it. An `Err` means the question could not be answered
    /// (network, credentials), and must not be confused with "absent".
    async fn head_object(&self, key: &str) -> Result<Option<ObjectMetadata>, TechnicianError>;

    /// Reads at most the first `first_bytes` of the object, so the caller
    /// can check what the file really is rather than trusting the type the
    /// client declared. `Ok(None)` means it does not exist.
    ///
    /// A verification document is capped at a few megabytes, so this is a
    /// small ranged read, not a download of the whole object.
    async fn read_prefix(
        &self,
        key: &str,
        first_bytes: usize,
    ) -> Result<Option<Vec<u8>>, TechnicianError>;
}
