# ETAPI Token Acquisition for TriliumNext

This document describes how to obtain and manage an ETAPI (External API) token for TriliumNext.

## Prerequisites

- TriliumNext running and accessible at `http://127.0.0.1:3011`
- Administrative access to the TriliumNext instance

---

## Obtaining an ETAPI Token

### Method 1: Via Web UI

1. **Access Options/Settings**
   - Open TriliumNext in your browser
   - Look for a menu icon (hamburger menu, gear icon, or similar) in the top-left or top-right corner
   - Navigate to **Options**, **Settings**, or **Preferences**

2. **Find the ETAPI Section**
   - Look for a tab or section labeled:
     - "ETAPI"
     - "API"
     - "External API"
     - "Tokens"
     - "Integrations"
   - This is typically found in an "Advanced" or "Security" category

3. **Generate a New Token**
   - Click **Create new ETAPI token**, **Generate**, **Add token**, or similar
   - Provide a descriptive name (e.g., `knowledge_trillium_integration`)
   - Copy the generated token immediately - it may only be shown once

### Method 2: Via ETAPI (Bootstrap with Existing Token)

If you already have a valid token and need to create additional tokens:

```bash
curl -X POST http://127.0.0.1:3011/etapi/tokens \
  -H "Authorization: <existing-token>" \
  -H "Content-Type: application/json" \
  -d '{"tokenName": "new_token_name"}'
```

### Method 3: Via Database (Advanced)

For recovery scenarios where UI access is unavailable:

1. Locate the Trilium database (typically `document.db`)
2. The `etapi_tokens` table contains token records
3. Tokens are stored hashed; you cannot retrieve existing tokens, only create new ones

**Note:** This method should only be used for recovery. Use the UI method for normal operations.

---

## How to Find It If UI Differs

TriliumNext UI may vary between versions. Use these strategies:

### Search Terms
Try searching within the application (if search is available) for:
- `etapi`
- `token`
- `api`
- `external`

### Common UI Locations
- **Menu > Options > ETAPI** (most common)
- **Settings > API Tokens**
- **Preferences > Integrations**
- **Advanced > External API**

### Visual Cues
- Look for sections with key/lock icons (security-related)
- Token management often appears near backup/sync settings
- May be grouped with "Developer" or "Advanced" options

### Keyboard Shortcuts
- Try `Ctrl+,` or `Cmd+,` for settings
- Check the Help menu for keyboard shortcut reference

---

## Verifying Token Validity

Test your token with a simple API call:

```bash
# Replace <your-token> with your actual ETAPI token
curl -s -o /dev/null -w "%{http_code}" \
  http://127.0.0.1:3011/etapi/app-info \
  -H "Authorization: <your-token>"
```

**Expected responses:**
- `200` - Token is valid
- `401` - Token is invalid or expired
- `403` - Token lacks required permissions

### Full Response Test

```bash
curl http://127.0.0.1:3011/etapi/app-info \
  -H "Authorization: <your-token>"
```

A valid response returns JSON with application information:
```json
{
  "appVersion": "...",
  "dbVersion": "...",
  "syncVersion": "...",
  "buildDate": "...",
  "buildRevision": "...",
  "dataDirectory": "...",
  "clipperProtocolVersion": "..."
}
```

---

## Token Storage

### Local Storage (Recommended)

Store the token in a local `.env` file that is **never committed to version control**:

```bash
# In project root: .env
TRILIUM_ETAPI_TOKEN=your_token_here
TRILIUM_URL=http://127.0.0.1:3011
```

Ensure `.env` is in `.gitignore`:
```bash
echo ".env" >> .gitignore
```

### Environment Variable (Alternative)

Export directly in your shell session:
```bash
export TRILIUM_ETAPI_TOKEN="your_token_here"
```

For persistent sessions, add to `~/.zshrc_custom` or equivalent (if this is a personal/development machine only).

---

## Security Notes

### Token Handling

1. **Never commit tokens** to version control
   - Add `.env` to `.gitignore` before creating it
   - Check `git status` before commits to ensure no token files are staged

2. **Treat tokens as passwords**
   - Do not share tokens in chat, email, or documentation
   - Do not log tokens in application output

3. **Use descriptive token names**
   - Name tokens by purpose (e.g., `jarvis_integration`, `backup_script`)
   - This aids in auditing and revocation

### Token Rotation

1. **Regular rotation** - Rotate tokens periodically (e.g., quarterly)
2. **Rotation procedure:**
   - Create a new token in the UI
   - Update your local `.env` file
   - Verify the new token works
   - Delete the old token from TriliumNext

### Exposure Response

If a token is accidentally exposed:

1. **Immediately revoke** the exposed token in TriliumNext UI
2. **Generate a new token**
3. **Audit** recent API activity if logging is available
4. **Update** all systems using the old token

### Least Privilege

- ETAPI tokens currently provide full API access
- If TriliumNext adds scoped tokens in the future, use the minimum required permissions
- Consider using separate tokens for different integrations to enable selective revocation

---

## Troubleshooting

### Token Not Working

1. **Check formatting** - Ensure no leading/trailing whitespace
2. **Verify endpoint** - Confirm TriliumNext is running at the expected URL
3. **Check token status** - Token may have been deleted in the UI

### Cannot Find ETAPI Options

1. **Check version** - ETAPI may not be available in very old versions
2. **Try direct URL** - Navigate to `http://127.0.0.1:3011/#/options/etapi` (path may vary)
3. **Check documentation** - Consult TriliumNext release notes for your version

### Connection Refused

1. **Verify TriliumNext is running** - Check process or container status
2. **Confirm port** - Default may differ; check your configuration
3. **Check firewall** - Ensure localhost connections are allowed

---

## References

- [TriliumNext GitHub Repository](https://github.com/TriliumNext/Notes)
- [ETAPI Documentation](https://github.com/zadam/trilium/wiki/ETAPI) (original Trilium wiki)

---

**Last Updated:** February 4, 2026
