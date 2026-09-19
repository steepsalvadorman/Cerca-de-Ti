-- Removes the demo credentials that the old migration 0002 seeded.
--
-- 0002 used to insert five accounts (4 technicians + 1 client) sharing the
-- Argon2 hash of `password123`, which `backend/README.md` documented. Since
-- `sqlx::migrate!` runs at every startup, any deployed database had a
-- working `client@cerca.com` / `password123` login handing out a 7-day
-- session. The seed block is gone from 0002 (migrations describe the
-- schema; demo data lives in `seeds/demo.sql`), but a database that
-- already applied the old 0002 still holds those rows, so this migration
-- neutralises them.
--
-- Deliberately *only* the password hash is cleared:
--   * `login_user` answers `PasswordLoginUnavailable` for an account with
--     a NULL hash, so password sign-in ends here and without a 500.
--   * The rows themselves stay, because `job_requests`,
--     `technician_documents`, `job_offers` and the client address/payment
--     tables all reference them. Deleting the users would cascade real
--     jobs away. Losing the demo data is not worth losing live rows.
--
-- The hash is matched exactly rather than by id, so an account whose
-- password was since changed is left alone.
UPDATE users
SET password_hash = NULL
WHERE password_hash = '$argon2id$v=19$m=19456,t=2,p=1$k8CqEmfoRpEwkTszAlG5Hw$0r40UshfbvLQaYGu0089358JjzidfPdV/aebyH3MaPA';
