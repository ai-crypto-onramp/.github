-- Fixtures for notification database.
-- notification_templates is seeded by migration 0006; fixtures add a few
-- concrete notifications, delivery attempts, user preferences, and a webhook.
\c notification;

INSERT INTO notifications (id, event_id, event_type, channel, recipient, user_id, template_id, status, traffic_class, locale, created_at, sent_at)
VALUES
  ('notif-001', 'evt-001', 'tx.created',       'email', 'alice@example.com',  'user-001', 'tx.created',       'delivered', 'transactional', 'en', now() - interval '2 hours',  now() - interval '2 hours'),
  ('notif-002', 'evt-002', 'payment.captured', 'sms',    '+15551234567',       'user-001', 'payment.captured', 'sent',      'transactional', 'en', now() - interval '90 minutes', now() - interval '89 minutes'),
  ('notif-003', 'evt-003', 'tx.failed',        'email', 'bob@example.com',    'user-002', 'tx.failed',        'failed',    'transactional', 'en', now() - interval '1 hour',   NULL),
  ('notif-004', 'evt-004', 'tx.confirmed',     'push',  'device-token-abc',    'user-002', 'tx.confirmed',     'delivered', 'transactional', 'en', now() - interval '45 minutes', now() - interval '44 minutes'),
  ('notif-005', 'evt-005', 'tx.refunded',      'webhook','https://partner.example.com/hooks', 'user-003', 'tx.refunded', 'delivered', 'transactional', 'en', now() - interval '20 minutes', now() - interval '19 minutes');

INSERT INTO delivery_attempts (notification_id, channel, provider, provider_message_id, status, attempt_no, error, created_at, updated_at)
VALUES
  ('notif-001', 'email', 'ses',  'ses-msg-001', 'delivered', 1, NULL,              now() - interval '2 hours',    now() - interval '2 hours'),
  ('notif-002', 'sms',   'twilio','twilio-001',  'sent',      1, NULL,              now() - interval '89 minutes', now() - interval '89 minutes'),
  ('notif-003', 'email', 'ses',  NULL,          'failed',    1, 'InvalidRecipient', now() - interval '1 hour',     now() - interval '58 minutes'),
  ('notif-003', 'email', 'ses',  NULL,          'failed',    2, 'Bounce',           now() - interval '58 minutes',  now() - interval '55 minutes'),
  ('notif-004', 'push',  'fcm',  'fcm-msg-001', 'delivered', 1, NULL,              now() - interval '44 minutes', now() - interval '44 minutes'),
  ('notif-005', 'webhook','http','wh-001',      'delivered', 1, NULL,              now() - interval '19 minutes', now() - interval '19 minutes');

INSERT INTO user_preferences (user_id, email, sms, push, webhook, locale, quiet_start, quiet_end, updated_at)
VALUES
  ('user-001', true,  true,  true,  true,  'en', '22:00', '07:00', now() - interval '3 days'),
  ('user-002', true,  false, true,  true,  'en', '23:00', '06:00', now() - interval '5 days'),
  ('user-003', true,  true,  false, true,  'en', NULL,    NULL,    now() - interval '1 day');

INSERT INTO partner_webhooks (id, url, secret, event_filters, retry_policy, batch_window, status, created_at)
VALUES
  ('wh-001', 'https://partner.example.com/hooks', 'whsec-fixture', '["tx.*","payment.*"]'::jsonb, '{"max_retries":3,"backoff_ms":1000}'::jsonb, 1000, 'active', now() - interval '7 days');