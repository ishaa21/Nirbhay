-- Nirbhay Women Safety Application Database Schema
-- Compatible with PostgreSQL / Neon PostgreSQL

-- Enable pgcrypto extension for UUID generation if needed
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Users Table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50),
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for fast lookup on email
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- Trigger to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Emergency Contacts Table
CREATE TABLE IF NOT EXISTS emergency_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(50) NOT NULL,
    relationship VARCHAR(100),
    auto_alert BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for fast lookup on user_id
CREATE INDEX IF NOT EXISTS idx_emergency_contacts_user_id ON emergency_contacts(user_id);

DROP TRIGGER IF EXISTS update_emergency_contacts_updated_at ON emergency_contacts;
CREATE TRIGGER update_emergency_contacts_updated_at
    BEFORE UPDATE ON emergency_contacts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- SOS Incidents Table
CREATE TABLE IF NOT EXISTS sos_incidents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'RESOLVED', 'CANCELLED')),
    latitude NUMERIC(10, 7) CHECK (latitude IS NULL OR (latitude >= -90 AND latitude <= 90)),
    longitude NUMERIC(10, 7) CHECK (longitude IS NULL OR (longitude >= -180 AND longitude <= 180)),
    activated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    notification_status VARCHAR(50) NOT NULL DEFAULT 'PENDING' CHECK (notification_status IN ('PENDING', 'SENT', 'FAILED', 'NO_CONTACTS', 'PARTIAL')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sos_incidents_user_id ON sos_incidents(user_id);
CREATE INDEX IF NOT EXISTS idx_sos_incidents_status ON sos_incidents(status);

-- Enforce maximum of ONE ACTIVE SOS incident per user at a time
CREATE UNIQUE INDEX IF NOT EXISTS idx_sos_incidents_user_active ON sos_incidents(user_id) WHERE status = 'ACTIVE';

DROP TRIGGER IF EXISTS update_sos_incidents_updated_at ON sos_incidents;
CREATE TRIGGER update_sos_incidents_updated_at
    BEFORE UPDATE ON sos_incidents
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- SOS Notifications Log Table
CREATE TABLE IF NOT EXISTS sos_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sos_id UUID NOT NULL REFERENCES sos_incidents(id) ON DELETE CASCADE,
    contact_id UUID REFERENCES emergency_contacts(id) ON DELETE SET NULL,
    contact_name VARCHAR(255) NOT NULL,
    contact_phone VARCHAR(50) NOT NULL,
    channel VARCHAR(50) NOT NULL DEFAULT 'SMS',
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'SENT', 'DELIVERED', 'FAILED', 'NOT_CONFIGURED')),
    provider_message_id VARCHAR(255),
    error_message TEXT,
    sent_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sos_notifications_sos_id ON sos_notifications(sos_id);


