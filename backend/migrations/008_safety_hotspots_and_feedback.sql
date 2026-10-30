-- ── Nirbhay Migration 008: Safety Hotspots & Community Feedback ─────────────
-- Adds resolution tracking to community_posts and creates the feedback table
-- for community-confirmed hotspots, dispute handling, and resolution tracking.

-- 1. Add resolution and feedback tracking columns to community_posts if not present
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'community_posts' AND column_name = 'resolution_status'
    ) THEN
        ALTER TABLE community_posts
        ADD COLUMN resolution_status VARCHAR(20) NOT NULL DEFAULT 'UNRESOLVED'
        CHECK (resolution_status IN ('UNRESOLVED', 'RESOLVED', 'DISPUTED'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'community_posts' AND column_name = 'resolved_at'
    ) THEN
        ALTER TABLE community_posts ADD COLUMN resolved_at TIMESTAMPTZ;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'community_posts' AND column_name = 'confirmations_count'
    ) THEN
        ALTER TABLE community_posts ADD COLUMN confirmations_count INTEGER NOT NULL DEFAULT 0 CHECK (confirmations_count >= 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'community_posts' AND column_name = 'disputes_count'
    ) THEN
        ALTER TABLE community_posts ADD COLUMN disputes_count INTEGER NOT NULL DEFAULT 0 CHECK (disputes_count >= 0);
    END IF;
END $$;

-- 2. Create community_post_feedback table
-- Allows users to report whether a safety concern is still present, resolved, or inaccurate.
-- Enforces one feedback per user per post to prevent manipulation.
CREATE TABLE IF NOT EXISTS community_post_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    feedback_type VARCHAR(30) NOT NULL CHECK (feedback_type IN ('STILL_PRESENT', 'RESOLVED', 'INACCURATE')),
    comments TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_community_post_user_feedback UNIQUE (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_post_feedback_post_id ON community_post_feedback(post_id);
CREATE INDEX IF NOT EXISTS idx_post_feedback_user_id ON community_post_feedback(user_id);
CREATE INDEX IF NOT EXISTS idx_post_feedback_type ON community_post_feedback(feedback_type);

-- 3. Composite geospatial index for fast bounding-box & proximity queries
CREATE INDEX IF NOT EXISTS idx_community_posts_hotspots
ON community_posts(latitude, longitude, created_at DESC)
WHERE latitude IS NOT NULL AND longitude IS NOT NULL AND status = 'ACTIVE' AND moderation_status != 'BLOCKED';
