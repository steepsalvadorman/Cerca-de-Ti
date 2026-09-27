-- How far each participant has read a job's thread, so the inbox can show
-- unread counts. One row per (job, reader); a missing row means "never
-- opened", i.e. every message from the other party is unread.

CREATE TABLE IF NOT EXISTS chat_reads (
    job_request_id UUID NOT NULL REFERENCES job_requests(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    last_read_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (job_request_id, user_id)
);
