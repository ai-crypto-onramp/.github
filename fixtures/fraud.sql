-- Fixtures for fraud database
\c fraud;

INSERT INTO fraud_scores (tx_id, user_id, score, risk_band, model_version, variant, top_features, scored_at)
VALUES
  ('tx-001', 'user-001', 0.92, 'high',    'gbm-v1', 'control', '[{"feature":"velocity_24h","value":42},{"feature":"device_age_hours","value":0.5}]', now() - interval '2 hours'),
  ('tx-002', 'user-002', 0.15, 'low',     'gbm-v1', 'control', '[{"feature":"velocity_24h","value":3},{"feature":"device_age_hours","value":720}]',   now() - interval '90 minutes'),
  ('tx-003', 'user-003', 0.71, 'medium',  'gbm-v1', 'control', '[{"feature":"velocity_24h","value":18},{"feature":"device_age_hours","value":2}]',     now() - interval '45 minutes'),
  ('tx-004', 'user-001', 0.98, 'high',    'gbm-v1', 'control', '[{"feature":"velocity_24h","value":55},{"feature":"keystroke_entropy","value":1.2}]',  now() - interval '30 minutes');

INSERT INTO model_versions (name, version, stage, metrics, traffic_split, trained_at, updated_at)
VALUES
  ('gbm', 'v1', 'production', '{"auc":0.91,"precision":0.83,"recall":0.77}', '{"control":1.0}', now() - interval '10 days', now() - interval '2 days'),
  ('gbm', 'v2', 'shadow',     '{"auc":0.93,"precision":0.86,"recall":0.80}', '{"control":0.8,"shadow":0.2}', now() - interval '3 days', now() - interval '1 days');

INSERT INTO feature_values (tx_id, feature_group, payload, recorded_at)
VALUES
  ('tx-001', 'velocity',    '{"velocity_24h":42,"velocity_1h":12,"distinct_ips":5}', now() - interval '2 hours'),
  ('tx-001', 'behavioral',  '{"session_duration_ms":4500,"keystroke_entropy":2.1,"tap_variance":0.8}', now() - interval '2 hours'),
  ('tx-002', 'velocity',    '{"velocity_24h":3,"velocity_1h":1,"distinct_ips":1}',  now() - interval '90 minutes'),
  ('tx-003', 'velocity',    '{"velocity_24h":18,"velocity_1h":7,"distinct_ips":3}', now() - interval '45 minutes');

INSERT INTO chargeback_events (tx_id, outcome, reason_code, source, reported_at, ingested_at)
VALUES
  ('tx-001', 'fraud',      '10.4', 'api', now() - interval '5 hours',  now() - interval '4 hours'),
  ('tx-002', 'clean',     NULL,    'api', now() - interval '3 hours',  now() - interval '3 hours'),
  ('tx-004', 'chargeback', '13.1', 'csv', now() - interval '1 hour',   now() - interval '55 minutes');

INSERT INTO drift_metrics (model_name, feature_name, psi, ks, breached, measured_at)
VALUES
  ('gbm', 'velocity_24h',     0.12, 0.08, false, now() - interval '6 hours'),
  ('gbm', 'device_age_hours', 0.31, 0.22, true,  now() - interval '6 hours'),
  ('gbm', 'keystroke_entropy',0.05, 0.03, false, now() - interval '6 hours');