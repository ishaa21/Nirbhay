-- ============================================================
-- Live Tracking Feature Migration
-- Run on existing Render PostgreSQL database if columns/tables
-- are missing from a pre-tracking deployment.
-- All statements are idempotent (safe to run multiple times).
-- ============================================================

-- 1. Add tracking_token column to sos_incidents if not present
ALTER TABLE sos_incidents
  ADD COLUMN IF NOT EXISTS tracking_token VARCHAR(255) UNIQUE;

-- 2. Add index on tracking_token for fast lookup by guardian tracking page
CREATE INDEX IF NOT EXISTS idx_sos_incidents_tracking_token
  ON sos_incidents(tracking_token);

-- 3. Create sos_location_updates breadcrumb table if not present
CREATE TABLE IF NOT EXISTS sos_location_updates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sos_id UUID NOT NULL REFERENCES sos_incidents(id) ON DELETE CASCADE,
    latitude NUMERIC(10, 7) NOT NULL CHECK (latitude >= -90 AND latitude <= 90),
    longitude NUMERIC(10, 7) NOT NULL CHECK (longitude >= -180 AND longitude <= 180),
    accuracy NUMERIC(8, 2),
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4. Add index on sos_id for fast latest-location queries
CREATE INDEX IF NOT EXISTS idx_sos_location_updates_sos_id
  ON sos_location_updates(sos_id);
