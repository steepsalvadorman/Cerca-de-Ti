//! S3-compatible presigned URLs (AWS Signature Version 4, query-string
//! flavour).
//!
//! Deliberately not tied to one vendor: the signing below is the same
//! for Cloudflare R2, Backblaze B2, Supabase Storage, MinIO or AWS
//! itself, so switching providers is a change of environment variables,
//! not of code.
//!
//! Signing a URL is pure local arithmetic — no network call — so this
//! adapter needs no HTTP client at all. That is why the signing is
//! written out here instead of depending on `aws-sdk-s3`.

use chrono::{DateTime, Utc};
use hmac::{Hmac, Mac};
use sha2::{Digest, Sha256};

use crate::features::technician::application::ObjectStorage;
use crate::features::technician::domain::TechnicianError;

type HmacSha256 = Hmac<Sha256>;

const ALGORITHM: &str = "AWS4-HMAC-SHA256";
const SERVICE: &str = "s3";
/// Long enough for a technician to pick a file and for the upload to
/// finish on a slow connection, short enough that a leaked URL is not a
/// standing invitation.
const EXPIRES_SECONDS: u64 = 15 * 60;

pub struct S3Config {
    /// Base endpoint of the storage account, e.g.
    /// `https://<account>.r2.cloudflarestorage.com` (R2),
    /// `https://s3.us-west-004.backblazeb2.com` (B2) or
    /// `https://<project>.supabase.co/storage/v1/s3` (Supabase).
    /// A path suffix, as Supabase needs, is preserved.
    pub endpoint: String,
    /// R2 wants `auto`; B2 and AWS want their real region, and getting
    /// it wrong shows up as an opaque signature error.
    pub region: String,
    pub access_key_id: String,
    pub secret_access_key: String,
    pub bucket: String,
}

pub struct S3ObjectStorage {
    host: String,
    base_path: String,
    config: S3Config,
}

impl S3ObjectStorage {
    pub fn new(config: S3Config) -> Self {
        let (host, base_path) = split_endpoint(&config.endpoint);
        Self { host, base_path, config }
    }

    fn presign(&self, method: &str, key: &str) -> String {
        presign_url(
            method,
            &self.host,
            &format!("{}/{}/{}", self.base_path, self.config.bucket, key),
            &self.config.region,
            &self.config.access_key_id,
            &self.config.secret_access_key,
            EXPIRES_SECONDS,
            Utc::now(),
        )
    }
}

impl ObjectStorage for S3ObjectStorage {
    fn presign_put(&self, key: &str, _content_type: &str) -> Result<String, TechnicianError> {
        // `content_type` is deliberately not part of the signature: doing
        // so would force the client's `Content-Type` header to match
        // byte-for-byte, and any charset suffix an HTTP client tacks on
        // turns into an opaque 403. The declared type is validated
        // against an allowlist and recorded in Postgres instead.
        Ok(self.presign("PUT", key))
    }

    fn presign_get(&self, key: &str) -> Result<String, TechnicianError> {
        Ok(self.presign("GET", key))
    }
}

/// Stand-in used when no bucket is configured. Rather than handing out
/// URLs that would fail deep inside an upload, it fails immediately and
/// says why — a missing deploy step, not a bug in the caller.
pub struct UnconfiguredObjectStorage;

impl ObjectStorage for UnconfiguredObjectStorage {
    fn presign_put(&self, _key: &str, _content_type: &str) -> Result<String, TechnicianError> {
        Err(TechnicianError::StorageUnavailable)
    }

    fn presign_get(&self, _key: &str) -> Result<String, TechnicianError> {
        Err(TechnicianError::StorageUnavailable)
    }
}

/// Splits `https://host/some/prefix` into `("host", "/some/prefix")`,
/// with an empty path for a bare host. Hand-rolled rather than pulling
/// in a URL crate for one split.
fn split_endpoint(endpoint: &str) -> (String, String) {
    let without_scheme = endpoint
        .trim()
        .trim_end_matches('/')
        .trim_start_matches("https://")
        .trim_start_matches("http://");

    match without_scheme.split_once('/') {
        Some((host, path)) => (host.to_string(), format!("/{path}")),
        None => (without_scheme.to_string(), String::new()),
    }
}

/// Builds a SigV4 presigned URL. Every input is explicit (including
/// `now`) so the signing itself can be exercised without a bucket, a
/// clock, or a network.
#[allow(clippy::too_many_arguments)]
fn presign_url(
    method: &str,
    host: &str,
    canonical_uri: &str,
    region: &str,
    access_key_id: &str,
    secret_access_key: &str,
    expires_seconds: u64,
    now: DateTime<Utc>,
) -> String {
    let amz_date = now.format("%Y%m%dT%H%M%SZ").to_string();
    let date_stamp = now.format("%Y%m%d").to_string();
    let scope = format!("{date_stamp}/{region}/{SERVICE}/aws4_request");

    // Already in the order SigV4 requires (query parameters sorted by
    // name): Algorithm, Credential, Date, Expires, SignedHeaders.
    let canonical_query_string = [
        ("X-Amz-Algorithm", ALGORITHM.to_string()),
        ("X-Amz-Credential", format!("{access_key_id}/{scope}")),
        ("X-Amz-Date", amz_date.clone()),
        ("X-Amz-Expires", expires_seconds.to_string()),
        ("X-Amz-SignedHeaders", "host".to_string()),
    ]
    .iter()
    .map(|(name, value)| format!("{}={}", uri_encode(name, true), uri_encode(value, true)))
    .collect::<Vec<_>>()
    .join("&");

    let encoded_uri = uri_encode(canonical_uri, false);

    let canonical_request = format!(
        "{method}\n{encoded_uri}\n{canonical_query_string}\nhost:{host}\n\nhost\nUNSIGNED-PAYLOAD",
    );

    let string_to_sign = format!(
        "{ALGORITHM}\n{amz_date}\n{scope}\n{}",
        hex::encode(Sha256::digest(canonical_request.as_bytes())),
    );

    let signature = hex::encode(sign(
        &signing_key(secret_access_key, &date_stamp, region),
        string_to_sign.as_bytes(),
    ));

    format!("https://{host}{encoded_uri}?{canonical_query_string}&X-Amz-Signature={signature}")
}

fn signing_key(secret_access_key: &str, date_stamp: &str, region: &str) -> Vec<u8> {
    let date_key = sign(format!("AWS4{secret_access_key}").as_bytes(), date_stamp.as_bytes());
    let region_key = sign(&date_key, region.as_bytes());
    let service_key = sign(&region_key, SERVICE.as_bytes());
    sign(&service_key, b"aws4_request")
}

fn sign(key: &[u8], message: &[u8]) -> Vec<u8> {
    let mut mac = HmacSha256::new_from_slice(key).expect("HMAC accepts keys of any length");
    mac.update(message);
    mac.finalize().into_bytes().to_vec()
}

/// AWS's own percent-encoding rules, which are stricter than a URL
/// library's: everything outside the unreserved set is escaped, and `/`
/// survives in paths but not in query values.
fn uri_encode(input: &str, encode_slash: bool) -> String {
    let mut encoded = String::with_capacity(input.len());
    for byte in input.bytes() {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                encoded.push(byte as char)
            }
            b'/' if !encode_slash => encoded.push('/'),
            _ => encoded.push_str(&format!("%{byte:02X}")),
        }
    }
    encoded
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The worked example from AWS's own SigV4 documentation. If this
    /// passes, the signing math matches what every S3-compatible
    /// provider verifies against.
    #[test]
    fn matches_the_aws_reference_presigned_url() {
        let url = presign_url(
            "GET",
            "examplebucket.s3.amazonaws.com",
            "/test.txt",
            "us-east-1",
            "AKIAIOSFODNN7EXAMPLE",
            "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            86400,
            "2013-05-24T00:00:00Z".parse::<DateTime<Utc>>().unwrap(),
        );

        assert!(
            url.ends_with("&X-Amz-Signature=aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404"),
            "signature does not match the AWS reference: {url}"
        );
    }

    #[test]
    fn uri_encoding_follows_the_aws_rules() {
        assert_eq!(uri_encode("a/b c", false), "a/b%20c");
        assert_eq!(uri_encode("a/b c", true), "a%2Fb%20c");
        assert_eq!(uri_encode("-_.~", true), "-_.~");
    }

    #[test]
    fn endpoints_split_into_host_and_optional_prefix() {
        // R2 / B2: bare host, no prefix.
        assert_eq!(
            split_endpoint("https://acct.r2.cloudflarestorage.com"),
            ("acct.r2.cloudflarestorage.com".to_string(), String::new())
        );
        // Supabase serves S3 under a path, which has to survive into the
        // signed URI or every request 404s.
        assert_eq!(
            split_endpoint("https://proj.supabase.co/storage/v1/s3/"),
            ("proj.supabase.co".to_string(), "/storage/v1/s3".to_string())
        );
    }

    #[test]
    fn presigned_url_carries_every_parameter_s3_requires() {
        let storage = S3ObjectStorage::new(S3Config {
            endpoint: "https://acct.r2.cloudflarestorage.com".to_string(),
            region: "auto".to_string(),
            access_key_id: "key-id".to_string(),
            secret_access_key: "secret".to_string(),
            bucket: "cerca-docs".to_string(),
        });

        let url = storage.presign_put("technicians/7/cedula/abc.jpg", "image/jpeg").unwrap();

        assert!(url.starts_with("https://acct.r2.cloudflarestorage.com/cerca-docs/technicians/7/cedula/abc.jpg?"));
        for parameter in [
            "X-Amz-Algorithm=AWS4-HMAC-SHA256",
            "X-Amz-Credential=key-id%2F",
            "X-Amz-Date=",
            "X-Amz-Expires=900",
            "X-Amz-SignedHeaders=host",
            "X-Amz-Signature=",
        ] {
            assert!(url.contains(parameter), "presigned URL is missing {parameter}: {url}");
        }
    }

    #[test]
    fn an_unconfigured_bucket_fails_loudly() {
        assert!(matches!(
            UnconfiguredObjectStorage.presign_put("k", "image/jpeg"),
            Err(TechnicianError::StorageUnavailable)
        ));
    }
}
