-- Real file uploads for technician verification documents.
--
-- Until now `technician_documents` only tracked a status flag: "uploaded"
-- meant a technician had tapped a toggle, with no file behind it. These
-- columns hold the reference to the object actually stored in the bucket.
--
-- All nullable: existing rows (and the seed data) predate real uploads,
-- and a row is also created with `status = 'pending'` the moment an
-- upload slot is handed out, before any bytes have been confirmed.
ALTER TABLE technician_documents
    ADD COLUMN IF NOT EXISTS storage_key TEXT,
    ADD COLUMN IF NOT EXISTS content_type TEXT,
    ADD COLUMN IF NOT EXISTS original_filename TEXT,
    ADD COLUMN IF NOT EXISTS uploaded_at TIMESTAMPTZ;
