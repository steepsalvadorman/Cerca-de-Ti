-- Development demo fixture. NOT a migration — nothing runs this
-- automatically. Load it explicitly:
--
--     cd backend
--     cargo run --bin seed
--
-- Why this is separate from migrations (GAP-113): `sqlx::migrate!` runs at
-- every startup, so when this data lived in migration 0002 the five
-- accounts below — all sharing the Argon2 hash of `password123` — existed
-- in every environment, production included, and `client@cerca.com`
-- handed out a valid 7-day session to anyone who read the repository.
-- Migrations describe the schema; fixtures are opt-in.
--
-- Every account below has a NULL password_hash on purpose. That keeps the
-- app browsable locally (technicians, teams, a client with addresses and
-- payment methods) without shipping a usable credential: `login_user`
-- answers `PasswordLoginUnavailable` for a hash-less account instead of
-- granting a session. To sign in as one of them, generate a hash for a
-- password of your choosing:
--
--     cargo run --bin seed -- --hash 'my-local-password'
--
-- and set it with `UPDATE users SET password_hash = '...' WHERE email = ...`.
-- Never commit that value.

-- Idempotent: safe to run repeatedly against the same database.
INSERT INTO users (id, email, name, role, password_hash, created_at)
VALUES
    ('00000000-0000-0000-0000-000000000001', 'marcelo@cerca.com', 'Marcelo Reyes', 'technician', NULL, now()),
    ('00000000-0000-0000-0000-000000000002', 'ana@cerca.com', 'Ana Fuentes', 'technician', NULL, now()),
    ('00000000-0000-0000-0000-000000000003', 'jorge@cerca.com', 'Jorge Salinas', 'technician', NULL, now()),
    ('00000000-0000-0000-0000-000000000004', 'patricia@cerca.com', 'Patricia Vega', 'technician', NULL, now()),
    ('00000000-0000-0000-0000-000000000005', 'client@cerca.com', 'Cliente Demo', 'client', NULL, now())
ON CONFLICT (id) DO NOTHING;

-- Overwrite anything the old migration 0002 left behind, so re-running
-- this fixture after migrating an existing database restores the
-- intended (password-less) state rather than leaving `password123` live.
UPDATE users
SET password_hash = NULL
WHERE id IN (
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000005'
)
AND email LIKE '%@cerca.com';

-- Technician profiles. Prices are in SOLES, matching migration
-- 0007_peru_currency_seed_data.sql (the CLP figures in the original
-- 0002 are gone; see GAP-95 for the same bug on the Flutter side).
INSERT INTO technician_profiles (id, user_id, oficio, rating, reviews, distance, price_label, pin_top, pin_left, coverage_km, available_days, categories, is_verified)
VALUES
    (1, '00000000-0000-0000-0000-000000000001', 'Gasfitero', 4.9, 132, '0.6 km', 'Desde S/ 60', 0.30, 0.60, 10, ARRAY['lun','mar','mie','jue','vie'], ARRAY['gasfiteria'], TRUE),
    (2, '00000000-0000-0000-0000-000000000002', 'Electricista', 4.8, 97, '1.1 km', 'Desde S/ 70', 0.55, 0.25, 8, ARRAY['lun','mar','mie','jue','vie','sab'], ARRAY['electricidad'], TRUE),
    (3, '00000000-0000-0000-0000-000000000003', 'Carpintero', 4.7, 64, '1.4 km', 'Desde S/ 80', 0.20, 0.20, 12, ARRAY['lun','mar','mie','jue','vie'], ARRAY['carpinteria'], TRUE),
    (4, '00000000-0000-0000-0000-000000000004', 'Cerrajera', 4.9, 210, '2.0 km', 'Desde S/ 50', 0.65, 0.75, 15, ARRAY['lun','mar','mie','jue','vie','sab','dom'], ARRAY['cerrajeria'], TRUE)
ON CONFLICT (id) DO NOTHING;

-- Advance the technician sequence past the explicit ids above, or the next
-- auto-assigned insert collides with a seeded pk. Mirrors migration 0004.
SELECT setval('technician_profiles_id_seq', (SELECT COALESCE(MAX(id), 0) FROM technician_profiles));

-- Project teams, also in soles (costs are the sum behind each price_label).
INSERT INTO tech_teams (id, name, mono, oficio, rating, reviews, distance, price_label, pin_top, pin_left, crew, projects, labor_cost, materials_cost, mobility_cost)
VALUES
    (1, 'Equipo AquaBuild', 'AB', 'Piscinas y obras de agua', 4.9, 41, '3.2 km', 'Desde S/ 5,110', 0.35, 0.58, 5, 118, 3150, 1700, 260),
    (2, 'Equipo Terra Sur', 'TS', 'Pozos y conexiones', 4.8, 29, '5.8 km', 'Desde S/ 2,320', 0.22, 0.28, 4, 76, 1360, 600, 360),
    (3, 'Equipo Muro Firme', 'MF', 'Tarrajeo y construcción', 4.7, 53, '4.1 km', 'Desde S/ 1,700', 0.62, 0.70, 6, 94, 1040, 440, 220)
ON CONFLICT (id) DO NOTHING;

SELECT setval('tech_teams_id_seq', (SELECT COALESCE(MAX(id), 0) FROM tech_teams));

-- Default client profile, addresses and payment methods.
INSERT INTO client_profiles (user_id, profile_saved) VALUES ('00000000-0000-0000-0000-000000000005', TRUE) ON CONFLICT (user_id) DO NOTHING;

INSERT INTO client_addresses (id, client_id, label, detail)
VALUES
    ('a0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000005', 'Casa', 'Av. Providencia 1234, depto 502'),
    ('a0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000005', 'Oficina', 'Av. Apoquindo 4500, piso 8')
ON CONFLICT (id) DO NOTHING;

INSERT INTO client_payment_methods (id, client_id, label, detail)
VALUES
    ('f0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000005', 'Tarjeta terminada en 4231', 'Visa · vence 08/28'),
    ('f0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000005', 'Efectivo', 'Pago directo al técnico')
ON CONFLICT (id) DO NOTHING;
