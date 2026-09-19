//! Input validation helpers (GAP-02).
//!
//! Every per-feature use case validated *its own* business rules — a bid
//! price above zero, a known document key, a cancellable status — but
//! nothing validated the *shape* of what arrived. `TEXT` columns have no
//! length bound in Postgres, so a `title`, an address or a chat message
//! could be megabytes long, be stored, and come back to every client that
//! reads the row. Combined with no limit on the request body, that is
//! both a storage problem and an amplification one: send 10 MB once, have
//! it polled out to every participant forever.
//!
//! These are deliberately plain functions rather than a derive macro or a
//! validation crate: the rules are few, the messages want to be in the
//! same voice as the rest of the API, and a dependency would be the
//! largest thing in this module.

use crate::shared::AppError;

/// A text field that must be present and non-blank, with an upper bound.
///
/// Returns the trimmed value, so callers store what the user meant. The
/// length is measured in **characters**, not bytes: a 120-character
/// Spanish address with accents is 120 characters and may be well over
/// 120 bytes, and rejecting it would be a bug that only shows up for
/// people writing their own language.
pub fn required_text(
    field: &'static str,
    value: &str,
    max_chars: usize,
) -> Result<String, AppError> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        return Err(AppError::Validation(format!("{field} no puede estar vacío")));
    }
    if trimmed.chars().count() > max_chars {
        return Err(AppError::Validation(format!(
            "{field} no puede superar los {max_chars} caracteres"
        )));
    }
    Ok(trimmed.to_string())
}

/// An optional text field. Absent and blank both come back as `None`, so
/// "no value" has one representation in the database instead of two.
pub fn optional_text(
    field: &'static str,
    value: Option<&str>,
    max_chars: usize,
) -> Result<Option<String>, AppError> {
    let Some(raw) = value else {
        return Ok(None);
    };
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return Ok(None);
    }
    if trimmed.chars().count() > max_chars {
        return Err(AppError::Validation(format!(
            "{field} no puede superar los {max_chars} caracteres"
        )));
    }
    Ok(Some(trimmed.to_string()))
}

/// A value that must be one of a fixed set, compared exactly.
///
/// Exists so the *set* is declared next to the check rather than implied
/// by a chain of `!=` comparisons, which is where a forgotten case hides.
pub fn one_of(field: &'static str, value: &str, allowed: &[&str]) -> Result<(), AppError> {
    if allowed.contains(&value) {
        return Ok(());
    }
    Err(AppError::Validation(format!(
        "{field} debe ser uno de: {}",
        allowed.join(", ")
    )))
}

/// An integer inside an inclusive range.
pub fn in_range(field: &'static str, value: i64, min: i64, max: i64) -> Result<(), AppError> {
    if (min..=max).contains(&value) {
        return Ok(());
    }
    Err(AppError::Validation(format!(
        "{field} debe estar entre {min} y {max}"
    )))
}

/// Bounds every element of a list of short identifiers, and the list
/// itself. Used for the day/category arrays a technician profile carries,
/// which had no validation of any kind.
pub fn list_of_known(
    field: &'static str,
    values: &[String],
    allowed: &[&str],
    max_items: usize,
) -> Result<(), AppError> {
    if values.len() > max_items {
        return Err(AppError::Validation(format!(
            "{field} no puede tener más de {max_items} elementos"
        )));
    }
    for value in values {
        one_of(field, value, allowed)?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn required_text_trims_and_accepts() {
        assert_eq!(required_text("título", "  Fuga de agua  ", 120).unwrap(), "Fuga de agua");
    }

    #[test]
    fn required_text_rejects_blank() {
        assert!(required_text("título", "   ", 120).is_err());
        assert!(required_text("título", "", 120).is_err());
    }

    #[test]
    fn required_text_rejects_too_long() {
        let ok = "a".repeat(120);
        let too_long = "a".repeat(121);
        assert!(required_text("título", &ok, 120).is_ok());
        assert!(required_text("título", &too_long, 120).is_err());
    }

    /// The bound is characters, not bytes: a Spanish address of 120
    /// characters must pass even though it is longer than 120 bytes.
    #[test]
    fn length_is_counted_in_characters_not_bytes() {
        let accented = "á".repeat(120);
        assert!(accented.len() > 120, "the test needs a multi-byte string");
        assert!(
            required_text("dirección", &accented, 120).is_ok(),
            "120 accented characters is 120 characters, not 240"
        );
    }

    #[test]
    fn optional_text_collapses_absent_and_blank() {
        assert_eq!(optional_text("nota", None, 300).unwrap(), None);
        assert_eq!(optional_text("nota", Some("   "), 300).unwrap(), None);
        assert_eq!(
            optional_text("nota", Some("  hola "), 300).unwrap().as_deref(),
            Some("hola")
        );
    }

    #[test]
    fn one_of_is_exact() {
        assert!(one_of("rol", "client", &["client", "technician"]).is_ok());
        assert!(one_of("rol", "Client", &["client", "technician"]).is_err());
        assert!(one_of("rol", "", &["client", "technician"]).is_err());
    }

    #[test]
    fn in_range_is_inclusive() {
        assert!(in_range("cobertura", 1, 1, 500).is_ok());
        assert!(in_range("cobertura", 500, 1, 500).is_ok());
        assert!(in_range("cobertura", 0, 1, 500).is_err());
        assert!(in_range("cobertura", 501, 1, 500).is_err());
    }

    #[test]
    fn list_of_known_bounds_both_the_list_and_its_members() {
        let allowed = ["lun", "mar"];
        assert!(list_of_known("días", &["lun".to_string()], &allowed, 7).is_ok());
        assert!(list_of_known("días", &["lunes".to_string()], &allowed, 7).is_err());
        assert!(
            list_of_known(
                "días",
                &vec!["lun".to_string(); 8],
                &allowed,
                7
            )
            .is_err()
        );
    }
}
