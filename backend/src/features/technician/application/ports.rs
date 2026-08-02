use crate::features::technician::domain::TechnicianError;

/// Technical capability for storing verification documents, kept as an
/// application-level port for the same reason `PasswordHasher` is one:
/// which bucket (or none at all) is a delivery detail.
///
/// Both methods hand back a time-limited signed URL instead of moving
/// bytes through this process — the device uploads straight to the
/// bucket, so the API stays a thin control plane.
pub trait ObjectStorage: Send + Sync {
    /// URL the client may `PUT` the file to, valid for a few minutes.
    fn presign_put(&self, key: &str, content_type: &str) -> Result<String, TechnicianError>;

    /// URL to read the object back. Documents are identity papers, so the
    /// bucket is private and even reads go through a short-lived URL.
    fn presign_get(&self, key: &str) -> Result<String, TechnicianError>;
}
