-- ── Live Journey Tracking Tables ─────────────────────────────────────────────
-- Run this script once against your Neon PostgreSQL database to create the
-- tables needed for the Live Journey Tracking feature.

-- 1. Journey sessions
CREATE TABLE IF NOT EXISTS journeys (
  id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status                    TEXT NOT NULL DEFAULT 'ACTIVE'
                              CHECK (status IN ('ACTIVE', 'COMPLETED', 'CANCELLED')),
  destination               TEXT,
  tracking_token            TEXT NOT NULL UNIQUE,
  tracking_url              TEXT,
  start_latitude            NUMERIC(10, 7),
  start_longitude           NUMERIC(10, 7),
  last_known_latitude       NUMERIC(10, 7),
  last_known_longitude      NUMERIC(10, 7),
  last_updated_at           TIMESTAMPTZ,
  route_deviation_enabled   BOOLEAN NOT NULL DEFAULT true,
  deviation_threshold_meters INTEGER NOT NULL DEFAULT 150,
  started_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at                  TIMESTAMPTZ
);

-- Only one ACTIVE journey per user at a time
CREATE UNIQUE INDEX IF NOT EXISTS idx_journeys_user_active
  ON journeys (user_id)
  WHERE status = 'ACTIVE';

-- 2. GPS breadcrumbs for journey location history
CREATE TABLE IF NOT EXISTS journey_locations (
  id          BIGSERIAL PRIMARY KEY,
  journey_id  UUID NOT NULL REFERENCES journeys(id) ON DELETE CASCADE,
  latitude    NUMERIC(10, 7) NOT NULL,
  longitude   NUMERIC(10, 7) NOT NULL,
  accuracy    NUMERIC(8, 2),
  speed       NUMERIC(8, 2),
  heading     NUMERIC(6, 2),
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_journey_locations_journey_id
  ON journey_locations (journey_id, recorded_at DESC);

-- Done!
SELECT 'Journey tables created successfully.' AS status;
