# Claude Code Context: Palimpsest – A Friction Tool for Design Research

## What This Is

Palimpsest is a macOS app that governs how I collect and process design inspiration. It uses Are.na as its source platform and enforces a core rule: **you cannot save anything without first speaking about it.** The tool refuses to let me accumulate without processing. Collecting is not research. Saving is not thinking.

This is a personal tool — I am the sole user. Accessibility is considered but not prioritized for broad audiences.

## Core Interaction Loop

1. Search Are.na by URL → discover blocks, channels, and related URLs
2. Browse results at full fidelity
3. To save any source: **record a voice response** (transcribed automatically)
4. Saved sources enter a personal collection with audio + transcription attached
5. After 7 days, sources **degrade** — only blurred/pixelated thumbnails + audio remain
6. Every Sunday: **ritual transfer** of full-fidelity originals to a physical hard drive
7. If Sunday transfer is skipped, the app **locks new discovery** until completed
8. Post-transfer: app shows only degraded thumbnails, transcriptions, and a pointer to which physical drive holds the original

## The Argument

The tool demands more from the user (voice, ritual, physical storage). It makes infrastructure tangible (hard drives). It inserts the body (speaking, handling objects). It refuses to scale conveniently. Time degrades sources so they cannot be directly copied — only remembered through your own spoken reactions. The real archive is your evolving thinking, not a pile of bookmarks.

## Technology Stack

- **Platform**: macOS native app
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Audio Recording**: AVAudioRecorder / AVAudioEngine
- **Speech Transcription**: Apple Speech framework (SFSpeechRecognizer) — on-device
- **Database**: SQLite (searches, blocks, channels, saved collection, recordings)
- **Networking**: URLSession with async/await
- **Architecture**: MVVM

## Are.na API Integration

### Endpoints

- `GET /v2/search/blocks?q=QUERY&page=X` — search blocks by stripped domain
- `GET /v2/blocks/{id}/channels?page=X` — find channels containing a block
- `GET /v2/channels/{slug}/contents` — get all blocks in a channel
- `GET /v2/channels/{slug}/thumb` — channel preview metadata
- `GET /v2/channels/{slug}/connections?page=X` — connected channels

### Rules

- No auth required for GET requests
- Rate limit: 60 requests/minute — implement queuing
- Cache aggressively to minimize API calls
- Skip private channels silently on 401
- Paginate with `total_pages` from responses

### URL Matching

- Strip input URL to domain name (`https://example.com/page` → `example`)
- Accept www/no-www, http/https variations
- Flag URLs with extra path segments as "inexact"
- Deduplicate within channels, sum occurrences across channels for ranking

## Voice Recording System

### Recording Flow

1. User taps/clicks a source to save it
2. Recording panel appears — save button is **disabled** until recording completes
3. User speaks their reaction (no minimum length, but must record *something*)
4. On stop: audio saved locally, transcription runs via SFSpeechRecognizer
5. Transcription displayed for review
6. Source + audio file path + transcription text saved to collection

### Technical Notes

- Use `AVAudioRecorder` for recording, save as `.m4a`
- Use `SFSpeechRecognizer` with on-device recognition (no network required)
- Store audio files in app's documents directory
- Store transcription as text in SQLite alongside the source reference
- Request microphone + speech recognition permissions on first use

## Collection & Degradation

### Saved Items Store

Each saved item contains:
- Reference to the original Are.na block/channel/URL
- Audio file path
- Transcription text
- Date saved
- Degradation status (fresh / degraded)
- Hard drive pointer (post-transfer)

### Time-Based Degradation (7 days after save)

- Original image replaced with heavily pixelated/blurred version (apply CIFilter gaussian blur or pixelation)
- Audio recording and transcription remain at full fidelity
- The degraded thumbnail is a trigger, not a reference — you can't pull details from it

### Sunday Ritual

- Every Sunday: app prompts transfer of full-fidelity originals to external drive
- Transfer = export original images/data to user-selected drive location
- After transfer: app records which drive received which items
- If transfer is skipped: app locks the search/discovery features until completed
- The lockout isn't punitive — the tool refuses to let you accumulate more until you've dealt with what you have

## Database Schema

```sql
-- Search history and cache
CREATE TABLE searches (
    id INTEGER PRIMARY KEY,
    original_url TEXT NOT NULL,
    stripped_domain TEXT NOT NULL,
    searched_at DATETIME NOT NULL
);

-- Are.na blocks from search results
CREATE TABLE blocks (
    id INTEGER PRIMARY KEY,
    arena_block_id TEXT UNIQUE,
    source_url TEXT,
    title TEXT,
    image_url TEXT,
    is_exact_match BOOLEAN DEFAULT 1
);

-- Are.na channels
CREATE TABLE channels (
    id INTEGER PRIMARY KEY,
    slug TEXT UNIQUE,
    title TEXT,
    username TEXT,
    block_count INTEGER
);

-- Block-Channel relationships
CREATE TABLE block_channels (
    block_id INTEGER,
    channel_id INTEGER,
    FOREIGN KEY (block_id) REFERENCES blocks(id),
    FOREIGN KEY (channel_id) REFERENCES channels(id)
);

-- URLs discovered in channels
CREATE TABLE channel_urls (
    channel_id INTEGER,
    url TEXT,
    is_exact_match BOOLEAN DEFAULT 1,
    occurrence_count INTEGER DEFAULT 1,
    FOREIGN KEY (channel_id) REFERENCES channels(id)
);

-- THE COLLECTION: saved sources with voice recordings
CREATE TABLE collection (
    id INTEGER PRIMARY KEY,
    source_type TEXT NOT NULL, -- 'block', 'channel', or 'url'
    source_id TEXT NOT NULL, -- reference to blocks.id, channels.id, or raw URL
    source_title TEXT,
    source_url TEXT,
    original_image_url TEXT,
    audio_file_path TEXT NOT NULL,
    transcription TEXT NOT NULL,
    saved_at DATETIME NOT NULL,
    is_degraded BOOLEAN DEFAULT 0,
    degraded_at DATETIME,
    drive_label TEXT, -- which physical drive holds the original
    transferred_at DATETIME
);
```

## Current Priorities

1. **Voice-to-save gate** — the core interaction that enforces the tool's thesis
2. **Collection view** — showing saved items with transcriptions
3. **Degradation system** — time-based blur after 7 days
4. **Sunday ritual interface** — transfer flow and lockout
5. **Drive pointer system** — tracking which drive holds which originals
6. UI polish and animation

## Code Quality

After any changes, always run:

```bash
swiftformat .
swiftlint
```

Fix all SwiftLint violations before committing.

## Design Principles

- Every feature should be minimal but exceptional
- Keyboard-first, mouse-optional
- Dark mode optimized
- Loading states should be beautiful and informative
- The friction is intentional — do not optimize it away
- Voice interaction should feel natural, not punitive