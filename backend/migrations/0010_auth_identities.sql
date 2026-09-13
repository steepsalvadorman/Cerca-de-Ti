-- Sign-in with Google. A user who arrives through a provider never picks
-- a password, so `password_hash` stops being mandatory; `login_user`
-- answers `PasswordLoginUnavailable` for those accounts instead of
-- comparing against a hash that isn't there.
ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;

-- One row per (provider, account) pair pointing at our own user. Kept
-- separate from `users` so a second provider is another row rather than
-- another pair of columns, and so the provider's subject id — not the
-- email, which people change — is what identifies the account.
CREATE TABLE IF NOT EXISTS auth_identities (
    provider   TEXT NOT NULL CHECK (provider IN ('google')),
    subject    TEXT NOT NULL,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (provider, subject)
);

-- Looking up "which identities does this user have" (account settings,
-- and the cascade above) is the other direction of the primary key.
CREATE INDEX IF NOT EXISTS idx_auth_identities_user_id ON auth_identities (user_id);
