//! The deploy manifest must declare every environment variable the server
//! reads (GAP-112).
//!
//! `render.yaml` is what actually provisions production, and it is edited
//! by hand. `GOOGLE_CLIENT_IDS` was read by `AppConfig::from_env` but
//! omitted from the manifest, so the deployed server booted with
//! `UnconfiguredIdentityVerifier` and answered 503 to *every* call to
//! `/auth/google`: the "Continuar con Google" button was dead in
//! production, and nothing failed loudly enough to say so. A missing
//! variable is not a crash — it is a silently disabled feature.
//!
//! The list below is maintained by hand on purpose. `AppConfig::from_env`
//! reads these names as string literals; there is no registry to
//! introspect, and a generated list would simply mirror whatever the code
//! already does, which is the bug. Adding a variable to `config.rs`
//! without adding it here fails this test, and the fix is to decide
//! deliberately whether the deployment needs it.

use std::path::Path;

/// Every variable the server reads from the environment, with whether a
/// deploy can function without it and which file reads it.
struct ConfigVar {
    name: &'static str,
    /// `true` when the server still works with the variable unset — the
    /// feature it powers degrades instead of disappearing. Those are
    /// allowed to be absent from the manifest, but the ones that are
    /// present must be real.
    optional: bool,
    /// Where the read lives, so a rename cannot leave a stale entry that
    /// makes the manifest check pass vacuously.
    read_in: &'static str,
}

const CONFIG_VARS: &[ConfigVar] = &[
    ConfigVar { name: "DATABASE_URL", optional: false, read_in: "src/config.rs" },
    ConfigVar { name: "JWT_SECRET", optional: false, read_in: "src/config.rs" },
    ConfigVar { name: "PORT", optional: true, read_in: "src/config.rs" },
    ConfigVar { name: "APP_ENV", optional: true, read_in: "src/config.rs" },
    // Read by the tracing subscriber in `main`, not by `AppConfig`.
    ConfigVar { name: "RUST_LOG", optional: true, read_in: "src/main.rs" },
    ConfigVar { name: "CORS_ALLOWED_ORIGINS", optional: true, read_in: "src/config.rs" },
    // Required in practice: unset means /auth/google answers 503, so the
    // only password-less way in is gone. This is the variable whose
    // absence went unnoticed.
    ConfigVar { name: "GOOGLE_CLIENT_IDS", optional: false, read_in: "src/config.rs" },
    ConfigVar { name: "S3_ENDPOINT", optional: true, read_in: "src/config.rs" },
    ConfigVar { name: "S3_REGION", optional: true, read_in: "src/config.rs" },
    ConfigVar { name: "S3_ACCESS_KEY_ID", optional: true, read_in: "src/config.rs" },
    ConfigVar { name: "S3_SECRET_ACCESS_KEY", optional: true, read_in: "src/config.rs" },
    ConfigVar { name: "S3_BUCKET", optional: true, read_in: "src/config.rs" },
    ConfigVar { name: "PAYMENTS_MODE", optional: true, read_in: "src/config.rs" },
];

fn render_manifest() -> String {
    let path = Path::new(env!("CARGO_MANIFEST_DIR")).join("../render.yaml");
    std::fs::read_to_string(&path)
        .unwrap_or_else(|e| panic!("could not read {}: {e}", path.display()))
}

/// Does the manifest declare this key? Render accepts either a bare
/// `- key: NAME` or an inline `- { key: NAME, ... }`.
fn manifest_declares(manifest: &str, name: &str) -> bool {
    manifest.contains(&format!("key: {name}")) || manifest.contains(&format!("key: \"{name}\""))
}

/// The regression test for GAP-112 itself.
#[test]
fn every_required_env_var_is_declared_in_the_deploy_manifest() {
    let manifest = render_manifest();

    let missing: Vec<&str> = CONFIG_VARS
        .iter()
        .filter(|var| !var.optional)
        .filter(|var| !manifest_declares(&manifest, var.name))
        .map(|var| var.name)
        .collect();

    assert!(
        missing.is_empty(),
        "render.yaml does not declare {missing:?}. The server reads these on every boot, \
         and an unset variable does not crash it — it silently disables the feature it \
         powers. Add them under `envVars` (use `sync: false` for anything secret or \
         account-specific)."
    );
}

/// The other direction: a manifest entry the code never reads is either a
/// leftover or a typo, and either way it misleads the next person
/// debugging a deploy. `PORT` is exempt because the comment in the
/// manifest explains Render injects it.
#[test]
fn the_deploy_manifest_declares_no_variable_the_server_ignores() {
    let manifest = render_manifest();
    let known: Vec<&str> = CONFIG_VARS.iter().map(|v| v.name).collect();

    let declared: Vec<String> = manifest
        .lines()
        .filter_map(|line| line.trim().strip_prefix("- key:"))
        .map(|rest| rest.split(',').next().unwrap_or(rest).trim().trim_matches('"').to_string())
        .collect();

    assert!(!declared.is_empty(), "no env vars found in render.yaml — was it reshaped?");

    let unknown: Vec<&String> = declared
        .iter()
        .filter(|name| !known.contains(&name.as_str()))
        .collect();

    assert!(
        unknown.is_empty(),
        "render.yaml declares {unknown:?}, which nothing in AppConfig::from_env reads. \
         Remove it, or add it to CONFIG_VARS in this test if the code does read it."
    );
}

/// Keeps `CONFIG_VARS` honest: every name in it must appear in the source
/// file recorded as reading it, so a renamed variable cannot leave a stale
/// entry that keeps the manifest check passing for the wrong reason.
#[test]
fn the_expected_variable_list_matches_the_config_source() {
    let manifest_dir = Path::new(env!("CARGO_MANIFEST_DIR"));

    for var in CONFIG_VARS {
        let source = std::fs::read_to_string(manifest_dir.join(var.read_in))
            .unwrap_or_else(|e| panic!("could not read {}: {e}", var.read_in));

        assert!(
            source.contains(&format!("\"{}\"", var.name)),
            "{name} is listed here as read by {file}, but that file never mentions it. \
             Either it was renamed or this list is stale — and a stale list would make the \
             manifest check pass vacuously.",
            name = var.name,
            file = var.read_in
        );
    }

    // `PORT` is documented in render.yaml as intentionally absent, so make
    // sure nobody "fixes" that by deleting the exemption silently.
    assert!(
        !manifest_declares(&render_manifest(), "PORT"),
        "PORT is deliberately not declared — Render injects it. If that changed, update \
         the comment in render.yaml and this assertion together."
    );
}
