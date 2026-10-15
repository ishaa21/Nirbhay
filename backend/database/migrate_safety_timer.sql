-- Safety Timer Migration
-- Run AFTER the base schema.sql has been applied.
-- Safe to run multiple times (idempotent).

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. safety_timers table
--    Persists every timer so the server can detect expiry independently
--    of the Flutter client.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS safety_timers (
    id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- State machine: ACTIVE → CHECKED_IN | CANCELLED | EXPIRED
    status           VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
                                 CHECK (status IN ('ACTIVE','CHECKED_IN','CANCELLED','EXPIRED')),

    duration_minutes INTEGER     NOT NULL CHECK (duration_minutes > 0),
    expires_at       TIMESTAMPTZ NOT NULL,

    -- Last known location at the moment the timer was created / last updated
    latitude         NUMERIC(10,7),
    longitude        NUMERIC(10,7),
    location_at      TIMESTAMPTZ,

    -- Idempotency: server marks this TRUE before firing alerts so a retry
    -- or a concurrent cron tick cannot double-dispatch.
    alert_fired      BOOLEAN     NOT NULL DEFAULT FALSE,

    checked_in_at    TIMESTAMPTZ,
    cancelled_at     TIMESTAMPTZ,
    expired_at       TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- One ACTIVE timer per user at a time (mirrors the SOS incident guard)
CREATE UNIQUE INDEX IF NOT EXISTS idx_safety_timers_user_active
    ON safety_timers(user_id) WHERE status = 'ACTIVE';

CREATE INDEX IF NOT EXISTS idx_safety_timers_user_id  ON safety_timers(user_id);
CREATE INDEX IF NOT EXISTS idx_safety_timers_status   ON safety_timers(status);
CREATE INDEX IF NOT EXISTS idx_safety_timers_expires  ON safety_timers(expires_at) WHERE status = 'ACTIVE';

-- Auto-update updated_at helper function (idempotent)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Auto-update updated_at (reuses existing trigger function from schema.sql)
DROP TRIGGER IF EXISTS update_safety_timers_updated_at ON safety_timers;
CREATE TRIGGER update_safety_timers_updated_at
    BEFORE UPDATE ON safety_timers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
