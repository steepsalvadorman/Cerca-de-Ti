//! A small in-process rate limiter for the credential endpoints.
//!
//! Why this exists (GAP-118): `/auth/register` and `/auth/login` each run
//! a full Argon2id evaluation — deliberately ~19 MiB and tens of
//! milliseconds, which is exactly what makes them worth attacking. The
//! hashing itself now happens on the blocking pool, so it no longer
//! occupies the async workers, but "expensive and unlimited" is still a
//! denial-of-service: an unauthenticated caller could keep the blocking
//! pool saturated indefinitely at no cost to themselves.
//!
//! ## What this is, and what it is not
//!
//! This is a **fixed-window counter held in memory**. It is honest about
//! its limits:
//!
//! * **Per process.** Two instances behind a load balancer each allow the
//!   full quota. Render runs a single free instance today, so this is
//!   correct now and a documented limitation rather than a silent one. A
//!   shared store (Redis) is the fix when the deployment grows.
//! * **Resets on restart.** A deploy hands every caller a fresh budget.
//! * **Keyed on the peer address only.** Behind a proxy that is the
//!   proxy's address unless `X-Forwarded-For` is trusted, so the key tries
//!   that header first. It is client-controlled, so this is a speed bump
//!   against casual abuse and a load-shedder against accidents, **not** a
//!   defence against a determined attacker with a pool of addresses. The
//!   real fix for that is at the edge.
//!
//! Given the above, the goal is to stop a single client from saturating
//! the server, and to make accidental request storms (a retry loop, a
//! double submit) harmless. It is deliberately simple enough to read in
//! one sitting: no background task, no dependency.
//!
//! Bounded memory: the map is capped, and the oldest windows are evicted
//! once it fills, so a flood of distinct addresses cannot grow it without
//! limit.

use std::collections::HashMap;
use std::net::{IpAddr, SocketAddr};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use axum::extract::{ConnectInfo, Request, State};
use axum::http::{HeaderMap, StatusCode};
use axum::middleware::Next;
use axum::response::{IntoResponse, Response};
use axum::Json;
use serde_json::json;

/// Longest a client may be made to wait before it is told to retry, so a
/// `Retry-After` header is never absurd.
const WINDOW: Duration = Duration::from_secs(60);

/// Ceiling on tracked keys. Beyond this the oldest windows are dropped, so
/// the structure cannot be grown without bound by rotating addresses.
const MAX_TRACKED_KEYS: usize = 20_000;

struct Window {
    started_at: Instant,
    count: u32,
}

pub struct RateLimiter {
    /// Requests allowed per [`WINDOW`], per key.
    limit: u32,
    windows: Mutex<HashMap<String, Window>>,
}

impl RateLimiter {
    pub fn new(limit: u32) -> Self {
        Self {
            limit,
            windows: Mutex::new(HashMap::new()),
        }
    }

    /// Records one request against `key` and reports whether it may
    /// proceed, plus how long until the window frees up.
    fn check(&self, key: &str, now: Instant) -> (bool, Duration) {
        // A poisoned lock must not take the server down: if a previous
        // caller panicked mid-update, the limiter degrades to "allow"
        // rather than refusing every login.
        let Ok(mut windows) = self.windows.lock() else {
            return (true, Duration::ZERO);
        };

        if windows.len() >= MAX_TRACKED_KEYS {
            // Drop everything whose window has already elapsed. If that
            // frees nothing, the table is all-live and we clear it: losing
            // counters is preferable to unbounded growth, and it only
            // happens under a flood of distinct keys.
            windows.retain(|_, window| now.duration_since(window.started_at) < WINDOW);
            if windows.len() >= MAX_TRACKED_KEYS {
                windows.clear();
            }
        }

        let window = windows.entry(key.to_string()).or_insert_with(|| Window {
            started_at: now,
            count: 0,
        });

        if now.duration_since(window.started_at) >= WINDOW {
            window.started_at = now;
            window.count = 0;
        }

        if window.count >= self.limit {
            let elapsed = now.duration_since(window.started_at);
            return (false, WINDOW.saturating_sub(elapsed));
        }

        window.count += 1;
        (true, Duration::ZERO)
    }
}

/// The caller's identity for limiting purposes.
///
/// `X-Forwarded-For` first (Render terminates TLS and forwards the real
/// client), then `X-Real-IP`, then the socket address. The first two are
/// client-controlled, which is why the module docs are explicit that this
/// is a speed bump and not a boundary.
fn client_key(headers: &HeaderMap, peer: Option<SocketAddr>) -> String {
    fn first_hop(value: &str) -> Option<&str> {
        value.split(',').map(str::trim).find(|part| !part.is_empty())
    }

    for header in ["x-forwarded-for", "x-real-ip"] {
        if let Some(value) = headers.get(header).and_then(|v| v.to_str().ok()) {
            if let Some(hop) = first_hop(value) {
                return hop.to_string();
            }
        }
    }

    match peer.map(|addr| addr.ip()) {
        Some(IpAddr::V4(ip)) => ip.to_string(),
        Some(IpAddr::V6(ip)) => ip.to_string(),
        None => "unknown".to_string(),
    }
}

/// Axum middleware enforcing `limiter` on every request it wraps.
///
/// Answers `429` with `Retry-After` and the same `{"error": ...}` envelope
/// the rest of the API uses, so the Flutter client's error mapping — which
/// keys on that shape — keeps working.
///
/// The peer address is read straight out of the request extensions rather
/// than through a `ConnectInfo` extractor. `ConnectInfo` is only inserted
/// when the server is built with `into_make_service_with_connect_info`, so
/// a required extractor would answer 500 to every request driven through
/// the router directly (tests, and any future embedding). Reading the
/// extension is optional by construction. Without a peer address the
/// limiter falls back to the forwarded headers, and to one shared bucket
/// if those are absent too — the conservative direction, since it limits
/// more rather than less.
pub async fn enforce(
    State(limiter): State<Arc<RateLimiter>>,
    request: Request,
    next: Next,
) -> Response {
    let peer = request
        .extensions()
        .get::<ConnectInfo<SocketAddr>>()
        .map(|ConnectInfo(addr)| *addr);

    let key = client_key(request.headers(), peer);

    match limiter.check(&key, Instant::now()) {
        (true, _) => next.run(request).await,
        (false, retry_after) => {
            let seconds = retry_after.as_secs().max(1);
            (
                StatusCode::TOO_MANY_REQUESTS,
                [(axum::http::header::RETRY_AFTER, seconds.to_string())],
                Json(json!({
                    "error": "too many attempts — wait a moment and try again"
                })),
            )
                .into_response()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn allows_up_to_the_limit_then_refuses() {
        let limiter = RateLimiter::new(3);
        let now = Instant::now();

        for attempt in 1..=3 {
            let (allowed, _) = limiter.check("1.2.3.4", now);
            assert!(allowed, "attempt {attempt} should be allowed");
        }

        let (allowed, retry_after) = limiter.check("1.2.3.4", now);
        assert!(!allowed, "the fourth attempt must be refused");
        assert!(retry_after <= WINDOW && retry_after > Duration::ZERO);
    }

    #[test]
    fn keys_are_independent() {
        let limiter = RateLimiter::new(1);
        let now = Instant::now();

        assert!(limiter.check("1.2.3.4", now).0);
        assert!(!limiter.check("1.2.3.4", now).0, "same key is exhausted");
        assert!(
            limiter.check("5.6.7.8", now).0,
            "one caller's exhausted budget must not lock out another"
        );
    }

    #[test]
    fn the_window_resets() {
        let limiter = RateLimiter::new(1);
        let start = Instant::now();

        assert!(limiter.check("1.2.3.4", start).0);
        assert!(!limiter.check("1.2.3.4", start).0);

        let later = start + WINDOW + Duration::from_millis(1);
        assert!(
            limiter.check("1.2.3.4", later).0,
            "a caller must recover once the window elapses"
        );
    }

    #[test]
    fn forwarded_addresses_are_used_before_the_socket() {
        let mut headers = HeaderMap::new();
        headers.insert("x-forwarded-for", "203.0.113.7, 10.0.0.1".parse().unwrap());
        let peer: SocketAddr = "10.0.0.1:5000".parse().unwrap();

        assert_eq!(
            client_key(&headers, Some(peer)),
            "203.0.113.7",
            "the first hop is the real client, not the proxy chain"
        );
    }

    #[test]
    fn falls_back_to_the_socket_address() {
        let headers = HeaderMap::new();
        let peer: SocketAddr = "198.51.100.9:5000".parse().unwrap();
        assert_eq!(client_key(&headers, Some(peer)), "198.51.100.9");
    }

    #[test]
    fn a_header_with_only_separators_falls_through_to_the_socket() {
        let mut headers = HeaderMap::new();
        headers.insert("x-forwarded-for", " , ".parse().unwrap());
        let peer: SocketAddr = "198.51.100.9:5000".parse().unwrap();

        assert_eq!(client_key(&headers, Some(peer)), "198.51.100.9");
    }

    /// The table must not grow without bound when every request carries a
    /// different address.
    #[test]
    fn the_tracked_key_table_stays_bounded() {
        let limiter = RateLimiter::new(5);
        let now = Instant::now();

        for i in 0..(MAX_TRACKED_KEYS + 500) {
            limiter.check(&format!("10.0.{}.{}", i / 256, i % 256), now);
        }

        let tracked = limiter.windows.lock().unwrap().len();
        assert!(
            tracked <= MAX_TRACKED_KEYS,
            "the limiter tracked {tracked} keys, past its {MAX_TRACKED_KEYS} ceiling"
        );
    }
}
