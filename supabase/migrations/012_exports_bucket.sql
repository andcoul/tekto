-- 012 — private storage bucket for GDPR exports (T089; contracts/backend-api.md §7).
-- Files live at <user_id>/<job_id>.json and are only reachable through 1-hour signed URLs
-- created by the export-data function (service role). No client policies: clients can
-- neither list nor read the bucket directly. delete-account removes a user's files.

INSERT INTO storage.buckets (id, name, public)
VALUES ('exports', 'exports', false)
ON CONFLICT (id) DO NOTHING;
