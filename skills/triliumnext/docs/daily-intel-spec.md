# Daily Intelligence Structure & Template Specification

This document defines the hierarchy, naming conventions, tagging system, and content template for daily intelligence notes in TriliumNext.

---

## 1. Hierarchy Structure

Daily intelligence notes are organized in a date-based tree structure:

```
Daily Intelligence (root)
└── 2026 (year)
    └── 02 - February (month)
        └── 2026-02-04 - Tuesday (day)
```

### Level Definitions

| Level | Type | Purpose |
|-------|------|---------|
| Root | Container | Top-level container for all daily intelligence |
| Year | Container | Groups notes by calendar year |
| Month | Container | Groups notes by calendar month within year |
| Day | Note | The actual daily intelligence content |

---

## 2. Naming Conventions

### Root Note
- **Title**: `Daily Intelligence`
- **Note Type**: `text` (container)

### Year Notes
- **Title Format**: `{YYYY}`
- **Example**: `2026`
- **Note Type**: `text` (container)

### Month Notes
- **Title Format**: `{MM} - {Month Name}`
- **Example**: `02 - February`
- **Note Type**: `text` (container)
- **Rationale**: Leading zero ensures proper sort order; full name aids readability

### Day Notes
- **Title Format**: `{YYYY-MM-DD} - {Day Name}`
- **Example**: `2026-02-04 - Tuesday`
- **Note Type**: `text`
- **Rationale**: ISO date format ensures uniqueness and proper chronological sorting

---

## 3. Required Attributes

### Root Note Attributes

| Attribute | Type | Value | Purpose |
|-----------|------|-------|---------|
| `#dailyIntelRoot` | Label | (no value) | Identifies this as the daily intel root |
| `#iconClass` | Label | `bx bx-calendar-star` | Visual identifier in tree |

### Year Note Attributes

| Attribute | Type | Value | Purpose |
|-----------|------|-------|---------|
| `#dailyIntelYear` | Label | `{YYYY}` | Identifies year container with value |
| `#year` | Label | `{YYYY}` | Queryable year value |
| `#iconClass` | Label | `bx bx-folder` | Visual identifier |

### Month Note Attributes

| Attribute | Type | Value | Purpose |
|-----------|------|-------|---------|
| `#dailyIntelMonth` | Label | `{YYYY-MM}` | Identifies month container |
| `#year` | Label | `{YYYY}` | Queryable year value |
| `#month` | Label | `{MM}` | Queryable month value (01-12) |
| `#iconClass` | Label | `bx bx-folder-open` | Visual identifier |

### Day Note Attributes

| Attribute | Type | Value | Purpose |
|-----------|------|-------|---------|
| `#dailyIntel` | Label | `{YYYY-MM-DD}` | Primary identifier for lookup |
| `#date` | Label | `{YYYY-MM-DD}` | ISO date for queries |
| `#year` | Label | `{YYYY}` | Queryable year |
| `#month` | Label | `{MM}` | Queryable month |
| `#day` | Label | `{DD}` | Queryable day |
| `#dayOfWeek` | Label | `{weekday}` | e.g., `tuesday` (lowercase) |
| `#iconClass` | Label | `bx bx-file` | Visual identifier |

---

## 4. Content Template for Daily Notes

Each daily intelligence note uses the following structured template:

```html
<h2>Summary</h2>
<p>High-level overview of the day's intelligence gathered. 2-3 sentences summarizing the most important findings or themes.</p>

<h2>Key Items</h2>
<ul>
  <li><strong>[Category]</strong>: Brief description of notable item</li>
  <li><strong>[Category]</strong>: Brief description of notable item</li>
</ul>

<h2>Detailed Findings</h2>
<h3>[Topic 1]</h3>
<p>Detailed notes about this topic...</p>

<h3>[Topic 2]</h3>
<p>Detailed notes about this topic...</p>

<h2>Sources</h2>
<ul>
  <li><a href="[URL]">[Source Title]</a> - Brief description</li>
  <li><a href="[URL]">[Source Title]</a> - Brief description</li>
</ul>

<h2>Action Items</h2>
<ul>
  <li>[ ] Action item description (priority: high/medium/low)</li>
  <li>[ ] Action item description (priority: high/medium/low)</li>
</ul>

<h2>Notes</h2>
<p>Additional observations, questions for follow-up, or related thoughts.</p>
```

### Section Definitions

| Section | Required | Purpose |
|---------|----------|---------|
| Summary | Yes | Executive summary of the day's intelligence |
| Key Items | Yes | Bulleted list of most important findings with category tags |
| Detailed Findings | No | Extended notes organized by topic |
| Sources | Yes | Links to source materials with descriptions |
| Action Items | No | Actionable follow-ups with priority levels |
| Notes | No | Miscellaneous observations and questions |

### Category Tags for Key Items

Recommended categories (not exhaustive):
- `News` - Current events
- `Tech` - Technology updates
- `Security` - Security-related findings
- `Research` - Research discoveries
- `Market` - Market/financial information
- `Personal` - Personal interest items

---

## 5. Idempotency Strategy

The system must be idempotent: running `daily run` multiple times for the same date should not create duplicate notes.

### Lookup Strategy

**Primary Method: Attribute Search**

```
Find note where #dailyIntel = "{YYYY-MM-DD}"
```

This is the authoritative lookup method. The `#dailyIntel` attribute with the ISO date value uniquely identifies each day's note.

### Creation Logic

```
function ensureDailyNote(date):
    # 1. Search for existing note by attribute
    existing = searchNotes("#dailyIntel = '{date}'")
    if existing:
        return existing[0]

    # 2. Ensure parent hierarchy exists
    root = ensureRoot()
    year = ensureYear(root, date.year)
    month = ensureMonth(year, date.year, date.month)

    # 3. Create new day note
    dayNote = createNote(
        parent: month,
        title: formatDayTitle(date),
        content: getTemplate(),
        attributes: getDayAttributes(date)
    )

    return dayNote
```

### Hierarchy Idempotency

Each level uses its own attribute for idempotent lookup:

| Level | Lookup Attribute | Example Query |
|-------|------------------|---------------|
| Root | `#dailyIntelRoot` | `#dailyIntelRoot` |
| Year | `#dailyIntelYear` | `#dailyIntelYear = "2026"` |
| Month | `#dailyIntelMonth` | `#dailyIntelMonth = "2026-02"` |
| Day | `#dailyIntel` | `#dailyIntel = "2026-02-04"` |

### Update Strategy

When a note already exists:
1. Do NOT overwrite existing content
2. Return the existing note for potential updates
3. Log that existing note was found (not created)

---

## 6. Command Interface

### `daily init-root`

Initializes the Daily Intelligence root note if it does not exist.

**Behavior**:
1. Search for `#dailyIntelRoot`
2. If found, report existing root and exit
3. If not found, create root note with attributes
4. Return root note ID

### `daily run [--date YYYY-MM-DD]`

Creates or retrieves the daily note for the specified date (defaults to today).

**Behavior**:
1. Parse date argument (default: today)
2. Ensure root exists (call init-root logic)
3. Ensure year container exists
4. Ensure month container exists
5. Create or retrieve day note
6. Return day note ID and status (created/existing)

**Output**:
```
Note ID: abc123
Status: created|existing
Path: Daily Intelligence > 2026 > 02 - February > 2026-02-04 - Tuesday
```

---

## 7. Example Tree

After running `daily run` for February 4, 2026:

```
Daily Intelligence                        #dailyIntelRoot
└── 2026                                  #dailyIntelYear="2026"
    └── 02 - February                     #dailyIntelMonth="2026-02"
        └── 2026-02-04 - Tuesday          #dailyIntel="2026-02-04"
```

After running for multiple days:

```
Daily Intelligence                        #dailyIntelRoot
├── 2025                                  #dailyIntelYear="2025"
│   └── 12 - December                     #dailyIntelMonth="2025-12"
│       ├── 2025-12-30 - Tuesday          #dailyIntel="2025-12-30"
│       └── 2025-12-31 - Wednesday        #dailyIntel="2025-12-31"
└── 2026                                  #dailyIntelYear="2026"
    ├── 01 - January                      #dailyIntelMonth="2026-01"
    │   ├── 2026-01-01 - Thursday         #dailyIntel="2026-01-01"
    │   └── ...
    └── 02 - February                     #dailyIntelMonth="2026-02"
        ├── 2026-02-01 - Sunday           #dailyIntel="2026-02-01"
        ├── 2026-02-02 - Monday           #dailyIntel="2026-02-02"
        ├── 2026-02-03 - Tuesday          #dailyIntel="2026-02-03"
        └── 2026-02-04 - Wednesday        #dailyIntel="2026-02-04"
```

---

## 8. Implementation Notes

### TriliumNext API Considerations

- Use `POST /api/notes` to create notes
- Use `GET /api/notes?search=...` for attribute queries
- Attributes are set via `POST /api/notes/{noteId}/attributes`
- Content is HTML (TriliumNext uses CKEditor internally)

### Error Handling

- If root cannot be found and creation fails, abort with clear error
- If date parsing fails, abort with usage message
- Network errors should be retried with exponential backoff

### Performance

- Cache root note ID after first lookup within a session
- Year and month lookups can also be cached for the current date
- Avoid redundant searches when creating a sequence of daily notes

---

**Last Updated:** 2026-02-04
