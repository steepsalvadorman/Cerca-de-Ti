-- Cancellation: the domain has always had a `cancelled` status and the
-- `job_requests.status` CHECK has always allowed it, but no use case ever
-- wrote it — there was no way out of a job. A client whose auction got no
-- bids, or who no longer wants the work, was stuck with it forever, and an
-- abandoned job sat in `active` for good (GAP-19).
--
-- These columns record who ended it and why, which a bare status flip
-- cannot: "cancelled by the client before anyone bid" and "the technician
-- walked away mid-job" are the same status and very different facts, and
-- the second one is what a rating or a suspension would need later.
--
-- All nullable: every existing row predates cancellation, and the columns
-- stay NULL for jobs that run to completion.

ALTER TABLE job_requests
    ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS cancelled_by UUID REFERENCES users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;

-- `cancelled_at` must be set exactly when the status is `cancelled`, so a
-- status flip that forgets the timestamp cannot slip through. Expressed as
-- two CHECKs rather than one biconditional so the failure names which side
-- is wrong.
--
-- Written defensively: a database may already hold rows cancelled by hand
-- before this migration existed. Those are backfilled from `created_at`
-- rather than failing the migration, since a failed migration blocks
-- startup.
UPDATE job_requests
SET cancelled_at = created_at
WHERE status = 'cancelled' AND cancelled_at IS NULL;

ALTER TABLE job_requests
    ADD CONSTRAINT job_requests_cancelled_at_matches_status
    CHECK ((status = 'cancelled') = (cancelled_at IS NOT NULL));

-- The open-bidding feed and the client's history both filter on status;
-- this keeps the "what is still open" query cheap as cancellations
-- accumulate.
CREATE INDEX IF NOT EXISTS job_requests_cancelled_idx
    ON job_requests (cancelled_at DESC)
    WHERE status = 'cancelled';
