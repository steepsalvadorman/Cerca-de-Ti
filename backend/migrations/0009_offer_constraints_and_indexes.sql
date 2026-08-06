-- Business rules and access paths the schema was missing.
--
-- Two things here:
--   1. `job_offers` accepted unlimited duplicate bids from the same
--      technician on the same job, and any price including zero or
--      negative. Both are now impossible at the database level, so a
--      missed check in a use case cannot corrupt the data.
--   2. The schema had no secondary indexes at all. Every lookup below
--      matches a WHERE (and where relevant an ORDER BY) that the
--      Postgres repositories actually issue.

-- --------------------------------------------------------------------
-- 1. job_offers: one bid per technician per job, always a real price
-- --------------------------------------------------------------------

-- Existing data may already violate these, and a failing migration would
-- block startup. Keep the most recent bid per (job, technician) and drop
-- the rest.
DELETE FROM job_offers a
USING job_offers b
WHERE a.job_request_id = b.job_request_id
  AND a.technician_profile_id = b.technician_profile_id
  AND (a.created_at, a.id) < (b.created_at, b.id);

DELETE FROM job_offers WHERE price <= 0;

ALTER TABLE job_offers
    ADD CONSTRAINT job_offers_one_bid_per_technician
    UNIQUE (job_request_id, technician_profile_id);

ALTER TABLE job_offers
    ADD CONSTRAINT job_offers_price_positive
    CHECK (price > 0);

-- --------------------------------------------------------------------
-- 2. Indexes for the queries the repositories issue
-- --------------------------------------------------------------------

-- find_client_history: WHERE client_id = $1 ORDER BY created_at DESC
CREATE INDEX IF NOT EXISTS job_requests_client_id_created_at_idx
    ON job_requests (client_id, created_at DESC);

-- find_assigned_jobs: WHERE technician_profile_id = $1
CREATE INDEX IF NOT EXISTS job_requests_technician_profile_id_idx
    ON job_requests (technician_profile_id)
    WHERE technician_profile_id IS NOT NULL;

-- find_open_bidding_jobs: the open-bid feed every technician polls.
-- Partial, because only a small slice of rows ever matches.
CREATE INDEX IF NOT EXISTS job_requests_open_bidding_idx
    ON job_requests (created_at DESC)
    WHERE job_kind = 'bidding' AND status = 'pending' AND technician_profile_id IS NULL;

-- find_offers_by_job_id: WHERE job_request_id = $1
CREATE INDEX IF NOT EXISTS job_offers_job_request_id_idx
    ON job_offers (job_request_id);

-- find_messages_by_job_id: WHERE job_request_id = $1 ORDER BY created_at ASC
CREATE INDEX IF NOT EXISTS chat_messages_job_request_id_created_at_idx
    ON chat_messages (job_request_id, created_at);

-- Client account screen.
CREATE INDEX IF NOT EXISTS client_addresses_client_id_idx
    ON client_addresses (client_id);

CREATE INDEX IF NOT EXISTS client_payment_methods_client_id_idx
    ON client_payment_methods (client_id);

-- Not indexed on purpose, already covered:
--   users.email                              -> UNIQUE
--   technician_profiles.user_id              -> UNIQUE
--   technician_documents(profile_id, key)    -> UNIQUE, and its leading
--                                               column serves the
--                                               profile-only lookup
--   tracking_locations.job_request_id        -> PRIMARY KEY
--   job_offers.technician_profile_id         -> leading column of the
--                                               new UNIQUE above is
--                                               job_request_id, so the
--                                               NOT IN subquery still
--                                               needs its own index:
CREATE INDEX IF NOT EXISTS job_offers_technician_profile_id_idx
    ON job_offers (technician_profile_id);
