-- Migration 006: hourly scheduler for weekly plan adaptation (FR-026, research §10)
-- Calls adapt-plan in batch mode; the function itself decides which plans are due.
-- Requires two Vault secrets (created per environment, never committed):
--   select vault.create_secret('<https://<ref>.supabase.co>', 'project_url');
--   select vault.create_secret('<service-role-key>',          'service_role_key');
-- If either secret is missing the job runs but the request URL/header is null and nothing is called.

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

SELECT cron.schedule(
  'adapt-due-plans',
  '0 * * * *',                                  -- every hour, on the hour
  $job$
    SELECT net.http_post(
      url     := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url')
                 || '/functions/v1/adapt-plan',
      headers := jsonb_build_object(
                   'Content-Type',  'application/json',
                   'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key')
                 ),
      body    := '{"mode":"batch"}'::jsonb
    );
  $job$
);
