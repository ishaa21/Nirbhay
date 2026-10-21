-- ── Nirbhay Community Hub Tables Migration ─────────────────────────────────────
-- Supports safety feeds, community reports, comments, upvotes, and content reporting.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 1. Community Posts
CREATE TABLE IF NOT EXISTS community_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category VARCHAR(50) NOT NULL CHECK (category IN (
        'SUSPICIOUS_ACTIVITY',
        'HARASSMENT',
        'UNSAFE_AREA',
        'THEFT',
        'ROAD_SAFETY',
        'LOST_PERSON',
        'HELPFUL_INFO',
        'OTHER'
    )),
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    location_name VARCHAR(255),
    latitude NUMERIC(10, 7) CHECK (latitude IS NULL OR (latitude >= -90 AND latitude <= 90)),
    longitude NUMERIC(10, 7) CHECK (longitude IS NULL OR (longitude >= -180 AND longitude <= 180)),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'DELETED', 'HIDDEN')),
    moderation_status VARCHAR(20) NOT NULL DEFAULT 'APPROVED' CHECK (moderation_status IN ('APPROVED', 'FLAGGED', 'BLOCKED')),
    upvotes_count INTEGER NOT NULL DEFAULT 0 CHECK (upvotes_count >= 0),
    comments_count INTEGER NOT NULL DEFAULT 0 CHECK (comments_count >= 0),
    reports_count INTEGER NOT NULL DEFAULT 0 CHECK (reports_count >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_community_posts_created_at ON community_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_community_posts_user_id ON community_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_community_posts_category ON community_posts(category);
CREATE INDEX IF NOT EXISTS idx_community_posts_status ON community_posts(status, moderation_status);
CREATE INDEX IF NOT EXISTS idx_community_posts_upvotes ON community_posts(upvotes_count DESC);
CREATE INDEX IF NOT EXISTS idx_community_posts_coords ON community_posts(latitude, longitude) WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

DROP TRIGGER IF EXISTS update_community_posts_updated_at ON community_posts;
CREATE TRIGGER update_community_posts_updated_at
    BEFORE UPDATE ON community_posts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 2. Community Comments
CREATE TABLE IF NOT EXISTS community_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'DELETED', 'HIDDEN')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_community_comments_post_id ON community_comments(post_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_community_comments_user_id ON community_comments(user_id);

DROP TRIGGER IF EXISTS update_community_comments_updated_at ON community_comments;
CREATE TRIGGER update_community_comments_updated_at
    BEFORE UPDATE ON community_comments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 3. Community Upvotes
CREATE TABLE IF NOT EXISTS community_upvotes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_community_upvotes_post_user UNIQUE (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_community_upvotes_post_id ON community_upvotes(post_id);
CREATE INDEX IF NOT EXISTS idx_community_upvotes_user_id ON community_upvotes(user_id);

-- 4. Community Content Reports
CREATE TABLE IF NOT EXISTS community_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason VARCHAR(50) NOT NULL CHECK (reason IN (
        'INACCURATE',
        'ABUSIVE',
        'SPAM',
        'DANGEROUS',
        'DOXXING',
        'OTHER'
    )),
    details TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'REVIEWED', 'DISMISSED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_community_reports_post_user UNIQUE (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_community_reports_post_id ON community_reports(post_id);
CREATE INDEX IF NOT EXISTS idx_community_reports_user_id ON community_reports(user_id);
