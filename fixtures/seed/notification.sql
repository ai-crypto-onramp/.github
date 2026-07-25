-- Fixtures for notification database.
-- notification_templates is seeded by migration 0006; fixtures add a few
-- concrete notifications, delivery attempts, user preferences, and a webhook.
\c notification;

INSERT INTO notifications (id, event_id, event_type, channel, recipient, user_id, template_id, status, traffic_class, locale, created_at, updated_at, sent_at)
VALUES
  ('01890000-0000-7000-8000-000000000401', 'evt-001', 'tx.created',       'EMAIL',  'alice@example.com',  '01890000-0000-7000-8000-000000000001', 'tx.created',       'DELIVERED', 'TRANSACTIONAL', 'en', now() - interval '2 hours',   now() - interval '2 hours',    now() - interval '2 hours'),
  ('01890000-0000-7000-8000-000000000402', 'evt-002', 'payment.captured', 'SMS',    '+15551234567',       '01890000-0000-7000-8000-000000000001', 'payment.captured', 'SENT',      'TRANSACTIONAL', 'en', now() - interval '90 minutes', now() - interval '89 minutes', now() - interval '89 minutes'),
  ('01890000-0000-7000-8000-000000000403', 'evt-003', 'tx.failed',        'EMAIL',  'bob@example.com',    '01890000-0000-7000-8000-000000000002', 'tx.failed',        'FAILED',    'TRANSACTIONAL', 'en', now() - interval '1 hour',    now() - interval '58 minutes', NULL),
  ('01890000-0000-7000-8000-000000000404', 'evt-004', 'tx.confirmed',     'PUSH',   'device-token-abc',   '01890000-0000-7000-8000-000000000002', 'tx.confirmed',     'DELIVERED', 'TRANSACTIONAL', 'en', now() - interval '45 minutes', now() - interval '44 minutes', now() - interval '44 minutes'),
  ('01890000-0000-7000-8000-000000000405', 'evt-005', 'tx.refunded',      'WEBHOOK','https://partner.example.com/hooks', '01890000-0000-7000-8000-000000000003', 'tx.refunded', 'DELIVERED', 'TRANSACTIONAL', 'en', now() - interval '20 minutes', now() - interval '19 minutes', now() - interval '19 minutes');

INSERT INTO delivery_attempts (id, notification_id, channel, provider, provider_message_id, status, attempt_no, error, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000410', '01890000-0000-7000-8000-000000000401', 'EMAIL',   'ses',     'ses-msg-001', 'DELIVERED', 1, NULL,              now() - interval '2 hours',    now() - interval '2 hours'),
  ('01890000-0000-7000-8000-000000000411', '01890000-0000-7000-8000-000000000402', 'SMS',     'twilio',  'twilio-001',  'SENT',      1, NULL,              now() - interval '89 minutes', now() - interval '89 minutes'),
  ('01890000-0000-7000-8000-000000000412', '01890000-0000-7000-8000-000000000403', 'EMAIL',   'ses',     NULL,         'FAILED',    1, 'InvalidRecipient', now() - interval '1 hour',     now() - interval '58 minutes'),
  ('01890000-0000-7000-8000-000000000413', '01890000-0000-7000-8000-000000000403', 'EMAIL',   'ses',     NULL,         'FAILED',    2, 'Bounce',           now() - interval '58 minutes',  now() - interval '55 minutes'),
  ('01890000-0000-7000-8000-000000000414', '01890000-0000-7000-8000-000000000404', 'PUSH',    'fcm',     'fcm-msg-001', 'DELIVERED', 1, NULL,              now() - interval '44 minutes', now() - interval '44 minutes'),
  ('01890000-0000-7000-8000-000000000415', '01890000-0000-7000-8000-000000000405', 'WEBHOOK', 'http',    'wh-001',      'DELIVERED', 1, NULL,              now() - interval '19 minutes', now() - interval '19 minutes');

INSERT INTO user_preferences (id, user_id, email, sms, push, webhook, locale, quiet_start, quiet_end, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000420', '01890000-0000-7000-8000-000000000001', true,  true,  true,  true,  'en', '22:00', '07:00', now() - interval '3 days', now() - interval '3 days'),
  ('01890000-0000-7000-8000-000000000421', '01890000-0000-7000-8000-000000000002', true,  false, true,  true,  'en', '23:00', '06:00', now() - interval '5 days', now() - interval '5 days'),
  ('01890000-0000-7000-8000-000000000422', '01890000-0000-7000-8000-000000000003', true,  true,  false, true,  'en', NULL,    NULL,    now() - interval '1 day',  now() - interval '1 day');

INSERT INTO partner_webhooks (id, url, secret, event_filters, retry_policy, batch_window, status, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000430', 'https://partner.example.com/hooks', 'whsec-fixture', '["tx.*","payment.*"]'::jsonb, '{"max_retries":3,"backoff_ms":1000}'::jsonb, 1000, 'ACTIVE', now() - interval '7 days', now() - interval '7 days');