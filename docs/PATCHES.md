# Customization Registry

This document records the downstream modifications maintained on the `uixb-v0.7.0-enhancements` branch.
When upstream releases new versions, check this registry to determine whether upstream has adopted equivalent logic or if local modifications should be adapted.

---

### 1. Chinese Localization & Password Reset i18n
- **Files**: `internal/web/`, `web/`
- **Intent**: Full Chinese localization of web dashboard, unified 12-character password validation, and internationalized error codes (e.g., `m365_cloud_not_configured`, `invalid_administrator_password`).
- **Retirement Criteria**: If upstream natively adds complete Chinese localization and password validation error mapping.

### 2. Account Selection & Memory Opt-Out
- **Files**: `internal/auth/`, `internal/api/`
- **Intent**: Ability to select active accounts and disable Microsoft Copilot persistent memory across sessions to prevent prompt leakage.
- **Retirement Criteria**: If upstream natively supports account switching and session memory toggle.

### 3. Stream SSE Flush Preservation
- **Files**: `internal/stream/`
- **Intent**: Ensure SSE chunks are flushed immediately to prevent client buffering delays, and ensure safe conversation context reuse.
- **Retirement Criteria**: If upstream adopts explicit response flushing and safe conversation reuse.

### 4. MCP Resources API
- **Files**: `internal/mcp/`
- **Intent**: Support Model Context Protocol (MCP) resources endpoint authentication and pending-channel client.
- **Retirement Criteria**: If upstream natively merges MCP resources support.
