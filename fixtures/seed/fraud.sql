-- Fixtures for fraud database
\c fraud;

INSERT INTO fraud_scores (id, tx_id, user_id, score, risk_band, model_version, variant, top_features, scored_at, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000701', 'tx-001', '01890000-0000-7000-8000-000000000001', 0.92, 'HIGH',   'gbm-v1', 'CONTROL', '[{"feature":"velocity_24h","value":42},{"feature":"device_age_hours","value":0.5}]', now() - interval '2 hours', now() - interval '2 hours', now() - interval '2 hours'),
  ('01890000-0000-7000-8000-000000000702', 'tx-002', '01890000-0000-7000-8000-000000000002', 0.15, 'LOW',    'gbm-v1', 'CONTROL', '[{"feature":"velocity_24h","value":3},{"feature":"device_age_hours","value":720}]',   now() - interval '90 minutes', now() - interval '90 minutes', now() - interval '90 minutes'),
  ('01890000-0000-7000-8000-000000000703', 'tx-003', '01890000-0000-7000-8000-000000000003', 0.71, 'MEDIUM', 'gbm-v1', 'CONTROL', '[{"feature":"velocity_24h","value":18},{"feature":"device_age_hours","value":2}]',    now() - interval '45 minutes', now() - interval '45 minutes', now() - interval '45 minutes'),
  ('01890000-0000-7000-8000-000000000704', 'tx-004', '01890000-0000-7000-8000-000000000001', 0.98, 'HIGH',   'gbm-v1', 'CONTROL', '[{"feature":"velocity_24h","value":55},{"feature":"keystroke_entropy","value":1.2}]', now() - interval '30 minutes', now() - interval '30 minutes', now() - interval '30 minutes');

INSERT INTO model_versions (id, name, version, stage, metrics, traffic_split, trained_at, updated_at, created_at)
VALUES
  ('01890000-0000-7000-8000-000000000710', 'gbm', 'v1', 'PRODUCTION', '{"auc":0.91,"precision":0.83,"recall":0.77}', '{"control":1.0}',                  now() - interval '10 days', now() - interval '2 days', now() - interval '10 days'),
  ('01890000-0000-7000-8000-000000000711', 'gbm', 'v2', 'SHADOW',     '{"auc":0.93,"precision":0.86,"recall":0.80}', '{"control":0.8,"shadow":0.2}',     now() - interval '3 days',  now() - interval '1 days', now() - interval '3 days');

INSERT INTO feature_values (id, tx_id, feature_group, payload, recorded_at, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000720', 'tx-001', 'velocity',    '{"velocity_24h":42,"velocity_1h":12,"distinct_ips":5}', now() - interval '2 hours', now() - interval '2 hours', now() - interval '2 hours'),
  ('01890000-0000-7000-8000-000000000721', 'tx-001', 'behavioral',  '{"session_duration_ms":4500,"keystroke_entropy":2.1,"tap_variance":0.8}', now() - interval '2 hours', now() - interval '2 hours', now() - interval '2 hours'),
  ('01890000-0000-7000-8000-000000000722', 'tx-002', 'velocity',    '{"velocity_24h":3,"velocity_1h":1,"distinct_ips":1}',  now() - interval '90 minutes', now() - interval '90 minutes', now() - interval '90 minutes'),
  ('01890000-0000-7000-8000-000000000723', 'tx-003', 'velocity',    '{"velocity_24h":18,"velocity_1h":7,"distinct_ips":3}', now() - interval '45 minutes', now() - interval '45 minutes', now() - interval '45 minutes');

INSERT INTO chargeback_events (id, tx_id, outcome, reason_code, source, reported_at, ingested_at, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000730', 'tx-001', 'FRAUD',      '10.4', 'API', now() - interval '5 hours',  now() - interval '4 hours', now() - interval '5 hours', now() - interval '4 hours'),
  ('01890000-0000-7000-8000-000000000731', 'tx-002', 'CLEAN',      NULL,    'API', now() - interval '3 hours',  now() - interval '3 hours', now() - interval '3 hours', now() - interval '3 hours'),
  ('01890000-0000-7000-8000-000000000732', 'tx-004', 'CHARGEBACK', '13.1', 'CSV', now() - interval '1 hour',   now() - interval '55 minutes', now() - interval '1 hour', now() - interval '55 minutes');

INSERT INTO drift_metrics (id, model_name, feature_name, psi, ks, breached, measured_at, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000740', 'gbm', 'velocity_24h',      0.12, 0.08, false, now() - interval '6 hours', now() - interval '6 hours', now() - interval '6 hours'),
  ('01890000-0000-7000-8000-000000000741', 'gbm', 'device_age_hours',  0.31, 0.22, true,  now() - interval '6 hours', now() - interval '6 hours', now() - interval '6 hours'),
  ('01890000-0000-7000-8000-000000000742', 'gbm', 'keystroke_entropy', 0.05, 0.03, false, now() - interval '6 hours', now() - interval '6 hours', now() - interval '6 hours');