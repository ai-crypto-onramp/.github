-- Fixtures for onboarding_kyc database
\c onboarding_kyc;

INSERT INTO kyc_applications (id, user_id, vendor, vendor_application_id, state, created_at, updated_at, expires_at, re_kyc_due_at, decided_at, version)
VALUES
  ('11111111-aaaa-1111-aaaa-111111111111', 'user-001', 'sumsub', 'sumsub-app-001', 'pass', now() - interval '25 days', now() - interval '24 days', NULL, now() + interval '335 days', now() - interval '24 days', 3),
  ('22222222-bbbb-2222-bbbb-222222222222', 'user-002', 'onfido', 'onfido-app-002', 'manual_review', now() - interval '5 days', now() - interval '1 day', now() + interval '2 days', NULL, NULL, 2),
  ('33333333-cccc-3333-cccc-333333333333', 'user-004', 'sumsub', NULL, 'documents_uploaded', now() - interval '1 hour', now() - interval '30 minutes', now() + interval '23 hours', NULL, NULL, 1),
  ('44444444-dddd-4444-dddd-444444444444', 'user-005', 'sumsub', 'sumsub-app-004', 'fail', now() - interval '10 days', now() - interval '9 days', NULL, NULL, now() - interval '9 days', 2);

INSERT INTO documents (id, application_id, type, object_key, vendor_document_id, uploaded_at, retention_until)
VALUES
  ('653fca05-6d77-5a33-b928-709c3299992d'::uuid, '11111111-aaaa-1111-aaaa-111111111111', 'id_front', 's3://kyc/user-001/id-front.jpg', 'sumsub-doc-001', now() - interval '25 days', now() + interval '335 days'),
  ('49836b50-13dd-5830-9543-4f2cb94ade2f'::uuid, '11111111-aaaa-1111-aaaa-111111111111', 'id_back', 's3://kyc/user-001/id-back.jpg', 'sumsub-doc-002', now() - interval '25 days', now() + interval '335 days'),
  ('99a23c5f-4e8d-5a38-81d5-12a59bfc38d2'::uuid, '11111111-aaaa-1111-aaaa-111111111111', 'selfie', 's3://kyc/user-001/selfie.jpg', 'sumsub-doc-003', now() - interval '25 days', now() + interval '335 days'),
  ('532bb210-781c-515a-aaef-cc29a17e895a'::uuid, '22222222-bbbb-2222-bbbb-222222222222', 'id_front', 's3://kyc/user-002/id-front.jpg', 'onfido-doc-001', now() - interval '5 days', now() + interval '355 days'),
  ('2a3261d3-dfeb-5667-b141-7c67e065bbfd'::uuid, '33333333-cccc-3333-cccc-333333333333', 'id_front', 's3://kyc/user-004/id-front.jpg', NULL, now() - interval '40 minutes', now() + interval '355 days');

INSERT INTO liveness_sessions (id, application_id, vendor_session_id, status, started_at, completed_at, result, retention_until)
VALUES
  ('3f924b42-8eb0-53f5-be2a-aa8d1ebeb763'::uuid, '11111111-aaaa-1111-aaaa-111111111111', 'sumsub-live-001', 'passed', now() - interval '25 days', now() - interval '25 days', '{"score":0.98}'::jsonb, now() + interval '335 days'),
  ('102e09dc-ee0a-51fc-b256-43d87c0542f2'::uuid, '22222222-bbbb-2222-bbbb-222222222222', 'onfido-live-002', 'passed', now() - interval '5 days', now() - interval '5 days', '{"score":0.95}'::jsonb, now() + interval '355 days'),
  ('9feb8f03-98ca-512e-a091-79e1d3ceb45c'::uuid, '33333333-cccc-3333-cccc-333333333333', NULL, 'started', now() - interval '20 minutes', NULL, NULL, NULL);

INSERT INTO sanctions_hits (id, application_id, list, matched_name, score, raw_payload, reviewed_by, reviewed_at, disposition)
VALUES
  ('b7ddc889-cf7e-5d6f-8d6f-e6158602d756'::uuid, '22222222-bbbb-2222-bbbb-222222222222', 'ofac_sdtn', 'Bob Smith', 0.72, '{"match_type":"name"}'::jsonb, 'analyst-1', now() - interval '1 day', 'clear');

INSERT INTO kyc_decisions (id, application_id, outcome, reason, decided_by, decided_at)
VALUES
  ('8e5f465a-711f-5086-9d78-c5fbe311c389'::uuid, '11111111-aaaa-1111-aaaa-111111111111', 'pass', 'All checks passed', 'sumsub-vendor', now() - interval '24 days'),
  ('90777a88-4871-5061-990b-dcbe4b887872'::uuid, '44444444-dddd-4444-dddd-444444444444', 'fail', 'Sanctions hit unresolved', 'compliance-1', now() - interval '9 days');

INSERT INTO webhook_events (id, vendor, event_id, received_at, raw_payload)
VALUES
  ('04bf7337-4b87-5859-93e0-5ecf862b8447'::uuid, 'sumsub', 'sumsub-evt-001', now() - interval '24 days', '{"type":"applicant.reviewed"}'::jsonb),
  ('28568093-05f9-5a5f-b480-63478bc642e9'::uuid, 'onfido', 'onfido-evt-001', now() - interval '3 days', '{"type":"report.completed"}'::jsonb);

INSERT INTO audit_events (id, aggregate, action, actor, payload, occurred_at)
VALUES
  ('5f2584d5-5376-5780-a27c-90fb1937a44f'::uuid, 'kyc_application', 'state_changed', 'system', '{"from":"screening","to":"pass"}'::jsonb, now() - interval '24 days'),
  ('8efb0ac7-cf66-56cb-acb5-038cd089dd5c'::uuid, 'kyc_application', 'sanctions_hit', 'system', '{"score":0.72}'::jsonb, now() - interval '4 days');