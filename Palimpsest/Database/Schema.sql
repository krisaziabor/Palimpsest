-- Palimpsest Database Schema v1

-- Search history
CREATE TABLE IF NOT EXISTS searches (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    original_url TEXT NOT NULL,
    stripped_domain TEXT NOT NULL,
    searched_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    is_stale BOOLEAN DEFAULT 0,
    UNIQUE(original_url)
);

-- Cached blocks
CREATE TABLE IF NOT EXISTS blocks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    arena_block_id TEXT UNIQUE NOT NULL,
    source_url TEXT,
    title TEXT,
    is_exact_match BOOLEAN DEFAULT 1
);

-- Cached channels
CREATE TABLE IF NOT EXISTS channels (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    slug TEXT UNIQUE NOT NULL,
    owner_slug TEXT,
    title TEXT,
    username TEXT,
    block_count INTEGER,
    connection_count INTEGER,
    thumbnail_urls TEXT -- JSON array
);

-- Block-Channel relationships
CREATE TABLE IF NOT EXISTS block_channels (
    block_id INTEGER,
    channel_id INTEGER,
    PRIMARY KEY (block_id, channel_id),
    FOREIGN KEY (block_id) REFERENCES blocks(id),
    FOREIGN KEY (channel_id) REFERENCES channels(id)
);

-- URLs found in channels
CREATE TABLE IF NOT EXISTS channel_urls (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_id INTEGER,
    url TEXT NOT NULL,
    is_exact_match BOOLEAN DEFAULT 1,
    occurrence_count INTEGER DEFAULT 1,
    FOREIGN KEY (channel_id) REFERENCES channels(id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_searches_domain ON searches(stripped_domain);
CREATE INDEX IF NOT EXISTS idx_channel_urls_occurrence ON channel_urls(occurrence_count DESC);
