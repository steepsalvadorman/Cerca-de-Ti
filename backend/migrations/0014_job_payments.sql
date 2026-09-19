-- Records of fee captures (GAP-14). The fake gateway writes here today;
-- a real PSP adapter will use the same table.

CREATE TABLE IF NOT EXISTS job_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_request_id UUID NOT NULL REFERENCES job_requests(id) ON DELETE CASCADE,
    gateway TEXT NOT NULL,
    gateway_reference TEXT NOT NULL,
    amount_soles INT NOT NULL CHECK (amount_soles >= 0),
    payment_method TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('captured', 'failed', 'refunded')),
    idempotency_key UUID NOT NULL,
    simulated BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (idempotency_key)
);

CREATE INDEX IF NOT EXISTS job_payments_job_request_id_idx
    ON job_payments (job_request_id);
