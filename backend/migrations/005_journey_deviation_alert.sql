-- Debounce route-deviation SMS alerts per journey session
ALTER TABLE journeys
  ADD COLUMN IF NOT EXISTS last_deviation_alert_at TIMESTAMPTZ;
