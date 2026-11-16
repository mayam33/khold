-- Khold level server — D1 schema.
-- Apply with:
--   npx wrangler d1 migrations apply khold-levels --remote

CREATE TABLE IF NOT EXISTS levels (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    author TEXT NOT NULL,
    data TEXT NOT NULL,
    created_at REAL NOT NULL,
    plays INTEGER NOT NULL DEFAULT 0,
    hidden INTEGER NOT NULL DEFAULT 0,
    rating_sum REAL NOT NULL DEFAULT 0,
    rating_count INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS ratings (
    level_id TEXT NOT NULL,
    client TEXT NOT NULL,
    score INTEGER NOT NULL,
    PRIMARY KEY (level_id, client)
);

CREATE TABLE IF NOT EXISTS reports (
    level_id TEXT NOT NULL,
    client TEXT NOT NULL,
    reason TEXT NOT NULL,
    created_at REAL NOT NULL,
    PRIMARY KEY (level_id, client)
);

CREATE INDEX IF NOT EXISTS idx_levels_visible_created
    ON levels (hidden, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ratings_level
    ON ratings (level_id);

CREATE INDEX IF NOT EXISTS idx_reports_level
    ON reports (level_id);
