-- Fixtures for onboarding_kyc database
\c onboarding_kyc;

INSERT INTO kyc_applications (id, user_id, vendor, vendor_application_id, state, created_at, updated_at, expires_at, re_kyc_due_at, decided_at, version)
VALUES
  ('01890000-0000-7000-8000-000000000b01', '01890000-0000-7000-8000-000000000001', 'sumsub',  'sumsub-app-001', 'PASS',               now() - interval '25 days', now() - interval '24 days', NULL,                       now() + interval '335 days', now() - interval '24 days', 3),
  ('01890000-0000-7000-8000-000000000b02', '01890000-0000-7000-8000-000000000002', 'onfido',  'onfido-app-002', 'MANUAL_REVIEW',      now() - interval '5 days',  now() - interval '1 day',  now() + interval '2 days',  NULL,                       NULL,                       2),
  ('01890000-0000-7000-8000-000000000b03', '01890000-0000-7000-8000-000000000004', 'sumsub',  NULL,             'DOCUMENTS_UPLOADED', now() - interval '1 hour',   now() - interval '30 minutes', now() + interval '23 hours', NULL,                    NULL,                       1),
  ('01890000-0000-7000-8000-000000000b04', '01890000-0000-7000-8000-000000000005', 'sumsub',  'sumsub-app-004', 'FAIL',               now() - interval '10 days', now() - interval '9 days', NULL,                       NULL,                       now() - interval '9 days',  2);

INSERT INTO documents (id, application_id, type, object_key, vendor_document_id, uploaded_at, retention_until, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000b10', '01890000-0000-7000-8000-000000000b01', 'ID_FRONT', 's3://kyc/user-001/id-front.jpg', 'sumsub-doc-001', now() - interval '25 days', now() + interval '335 days', now() - interval '25 days', now() - interval '25 days'),
  ('01890000-0000-7000-8000-000000000b11', '01890000-0000-7000-8000-000000000b01', 'ID_BACK',  's3://kyc/user-001/id-back.jpg',  'sumsub-doc-002', now() - interval '25 days', now() + interval '335 days', now() - interval '25 days', now() - interval '25 days'),
  ('01890000-0000-7000-8000-000000000b12', '01890000-0000-7000-8000-000000000b01', 'SELFIE',   's3://kyc/user-001/selfie.jpg',  'sumsub-doc-003', now() - interval '25 days', now() + interval '335 days', now() - interval '25 days', now() - interval '25 days'),
  ('01890000-0000-7000-8000-000000000b13', '01890000-0000-7000-8000-000000000b02', 'ID_FRONT', 's3://kyc/user-002/id-front.jpg', 'onfido-doc-001', now() - interval '5 days',  now() + interval '355 days', now() - interval '5 days',  now() - interval '5 days'),
  ('01890000-0000-7000-8000-000000000b14', '01890000-0000-7000-8000-000000000b03', 'ID_FRONT', 's3://kyc/user-004/id-front.jpg', NULL,             now() - interval '40 minutes', now() + interval '355 days', now() - interval '40 minutes', now() - interval '40 minutes');

INSERT INTO liveness_sessions (id, application_id, vendor_session_id, status, started_at, completed_at, result, retention_until, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000b20', '01890000-0000-7000-8000-000000000b01', 'sumsub-live-001', 'PASSED',  now() - interval '25 days', now() - interval '25 days', '{"score":0.98}'::jsonb, now() + interval '335 days', now() - interval '25 days', now() - interval '25 days'),
  ('01890000-0000-7000-8000-000000000b21', '01890000-0000-7000-8000-000000000b02', 'onfido-live-002', 'PASSED',  now() - interval '5 days',  now() - interval '5 days',  '{"score":0.95}'::jsonb, now() + interval '355 days', now() - interval '5 days',  now() - interval '5 days'),
  ('01890000-0000-7000-8000-000000000b22', '01890000-0000-7000-8000-000000000b03', NULL,              'STARTED', now() - interval '20 minutes', NULL, NULL,                 NULL,                     now() - interval '20 minutes', now() - interval '20 minutes');

INSERT INTO sanctions_hits (id, application_id, list, matched_name, score, raw_payload, reviewed_by, reviewed_at, disposition, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000b30', '01890000-0000-7000-8000-000000000b02', 'ofac_sdtn', 'Bob Smith', 0.72, '{"match_type":"name"}'::jsonb, 'analyst-1', now() - interval '1 day', 'CLEAR', now() - interval '4 days', now() - interval '1 day');

INSERT INTO kyc_decisions (id, application_id, outcome, reason, decided_by, decided_at, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000b40', '01890000-0000-7000-8000-000000000b01', 'PASS', 'All checks passed',     'sumsub-vendor', now() - interval '24 days', now() - interval '24 days', now() - interval '24 days'),
  ('01890000-0000-7000-8000-000000000b41', '01890000-0000-7000-8000-000000000b04', 'FAIL', 'Sanctions hit unresolved', 'compliance-1', now() - interval '9 days',  now() - interval '9 days',  now() - interval '9 days');

INSERT INTO webhook_events (id, vendor, event_id, received_at, raw_payload, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000b50', 'sumsub', 'sumsub-evt-001', now() - interval '24 days', '{"type":"applicant.reviewed"}'::jsonb, now() - interval '24 days', now() - interval '24 days'),
  ('01890000-0000-7000-8000-000000000b51', 'onfido', 'onfido-evt-001', now() - interval '3 days',  '{"type":"report.completed"}'::jsonb,  now() - interval '3 days',  now() - interval '3 days');

INSERT INTO audit_events (id, aggregate, action, actor, payload, occurred_at, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000b60', 'kyc_application', 'STATE_CHANGED', 'system', '{"from":"SCREENING","to":"PASS"}'::jsonb, now() - interval '24 days', now() - interval '24 days', now() - interval '24 days'),
  ('01890000-0000-7000-8000-000000000b61', 'kyc_application', 'SANCTIONS_HIT', 'system', '{"score":0.72}'::jsonb, now() - interval '4 days', now() - interval '4 days', now() - interval '4 days');