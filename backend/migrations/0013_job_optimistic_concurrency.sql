-- Optimistic concurrency for job_requests (GAP-07).
--
-- Every mutating use case follows the same read-modify-write shape:
-- `find_job_request_by_id` → change fields → `save_job_request`. The UPDATE
-- is unconditional on anything but `id`, so two requests that read the same
-- row both write, and whichever commits last silently discards the other's
-- change. Concretely:
--
--   * two `choose_offer` calls on the same auction both see "pending, no
--     technician" and both assign one — the first technician is told the
--     job is theirs while the row points at the second;
--   * a client double-tapping "Pagar" runs two activations;
--   * two `advance` calls from step 2 both write 3, losing a transition.
--
-- A version counter makes the second writer's UPDATE match no rows, which
-- the repository turns into a clear `ConcurrentModification` error instead
-- of a silent overwrite. Optimistic rather than `SELECT ... FOR UPDATE`
-- because these are short, low-contention writes: a lock would serialise
-- requests that almost never collide, and the retry is the caller's to
-- make anyway.
--
-- Existing rows start at 0; the check is `version = $n` against the value
-- the caller read, so a fresh migration is transparent.

ALTER TABLE job_requests
    ADD COLUMN IF NOT EXISTS version INT NOT NULL DEFAULT 0;
