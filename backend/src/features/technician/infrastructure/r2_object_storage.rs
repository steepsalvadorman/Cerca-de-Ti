//! S3-compatible presigned URLs (AWS Signature Version 4, query-string
//! flavour), targeting Cloudflare R2.
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
/// R2 ignores the region but SigV4 requires one in the credential scope.
const REGION: &str = "auto";
const SERVICE: &str = "s3";
/// Long enough for a technician to pick a file and for the upload to
/// finish on a slow connection, short enough that a leaked URL is not a
/// standing invitation.
const EXPIRES_SECONDS: u64 = 15 * 60;

pub struct R2Config {
    pub account_id: String,
    pub access_key_id: String,
    pub secret_access_key: String,
    pub bucket: String,
}

pub struct R2ObjectStorage {
    config: R2Config,
}

impl R2ObjectStorage {
    pub fn new(config: R2Config) -> Self {
        Self { config }
    }

    fn presign(&self, method: &str, key: &str) -> String {
        presign_url(
            method,
            &format!("{}.r2.cloudflarestorage.com", self.config.account_id),
            &format!("/{}/{}", self.config.bucket, key),
            &self.config.access_key_id,
            &self.config.secret_access_key,
            EXPIRES_SECONDS,
            Utc::now(),
        )
    }
}

impl ObjectStorage for R2ObjectStorage {
    fn presign_put(&self, key: &str, _content_type: &str) -> Result<String, TechnicianError> {
        // `content_type` is deliberately not part of the signature: doing
        // so would force the client's `Content-Type` header to match
        // byte-for-byte, and any charset suffix an HTTP client tacks on
        // turns into an opaque 403. The declared type is validated
        // against an allowlist and recorded in Postgres instead.
        Ok(self.presign(&"PUT", key))
    }

    fn presign_get(&self, key: &str) -> Result<String, TechnicianError> {
        Ok(self.presign(&"GET", key))
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

/// Builds a SigV4 presigned URL. Every input is explicit (including
/// `now`) so the signing itself can be checked against AWS's published
/// example without a bucket, a clock, or a network.
#[allow(clippy::too_many_arguments)]
fn presign_url(
    method: &str,
    host: &str,
    canonical_uri: &str,
    access_key_id: &str,
    secret_access_key: &str,
    expires_seconds: u64,
    now: DateTime<Utc>,
) -> String {
    let amz_date = now.format("%Y%m%dT%H%M%SZ").to_string();
    let date_stamp = now.format("%Y%m%d").to_string();
    let scope = format!("{date_stamp}/{REGION}/{SERVICE}/aws4_request");

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

    let canonical_request = format!(
        "{method}\n{}\n{canonical_query_string}\nhost:{host}\n\nhost\nUNSIGNED-PAYLOAD",
        uri_encode(canonical_uri, false),
    );

    let string_to_sign = format!(
        "{ALGORITHM}\n{amz_date}\n{scope}\n{}",
        hex::encode(Sha256::digest(canonical_request.as_bytes())),
    );

    let signature = hex::encode(sign(
        &signing_key(secret_access_key, &date_stamp),
        string_to_sign.as_bytes(),
    ));

    format!(
        "https://{host}{}?{canonical_query_string}&X-Amz-Signature={signature}",
        uri_encode(canonical_uri, false),
    )
}

fn signing_key(secret_access_key: &str, date_stamp: &str) -> Vec<u8> {
    let date_key = sign(format!("AWS4{secret_access_key}").as_bytes(), date_stamp.as_bytes());
    let region_key = sign(&date_key, REGION.as_bytes());
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

    #[test]
    fn uri_encoding_follows_the_aws_rules() {
        assert_eq!(uri_encode("a/b c", false), "a/b%20c");
        assert_eq!(uri_encode("a/b c", true), "a%2Fb%20c");
        assert_eq!(uri_encode("-_.~", true), "-_.~");
    }

    #[test]
    fn presigned_url_carries_every_parameter_s3_requires() {
        let url = presign_url(
            "PUT",
            "acct.r2.cloudflarestorage.com",
            "/cerca-docs/technicians/7/cedula/abc.jpg",
            "key-id",
            "secret",
            900,
            Utc::now(),
        );

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
