# UIXB enhancements for upstream v0.7.0

This branch is based on upstream `v0.7.0` (`51946f8aabd3e4a3eebc4bcad3fb1ddb6620f667`).
It contains deployment and compatibility fixes that were validated against a real Pi CLI client and an OpenAI-compatible `/v1/chat/completions` client.

## What changed

### OpenAI usage and conversation-cache reporting

- All normal, router, required-tool, streamed, and non-streamed tool responses use the same usage builder.
- Tool schemas, `tool_choice`, tool calls, message framing, visible request content, and visible completion content are included in the local estimate.
- `cached_tokens` is reported only when the gateway actually reuses a known conversation prefix. A cache miss reports zero instead of guessing from prompt length.
- `cache_read_input_tokens` is retained as a compatibility alias.
- Metadata explicitly marks the source as a local estimate. ChatHub does not expose upstream billing token counts.
- Session-resolver conversation reuse is included in the cache accounting, not only the in-memory conversation cache.

### Streaming and tool-call compatibility

- Pending streamed text and identity-filter tails are flushed before the final chunk.
- Streamed usage is included in the final chunk, with an additional `choices: []` usage chunk when `stream_options.include_usage=true`.
- Tool-call responses return standard OpenAI `tool_calls` and include consistent usage fields.

### Image-generation failover

- Image generation can try the next eligible account after an account-level failure or quota response.
- Image-only cooldown state no longer disables regular text chat for the same account.

### Runtime defaults

- The container includes timezone data and CA certificates.
- The compose healthcheck verifies the login endpoint.
- Long-running chat requests use a larger timeout.
- Conversation caching is enabled by default in the deployment configuration.
- The stable `router` tool-planning path remains the default; the experimental `native` mode is not enabled here.

## Validation

The following package tests passed during validation in a Go 1.23 Alpine test container:

```text
go test ./internal/web ./internal/chathub ./internal/auth ./internal/outbound
```

The full suite was also attempted. The only failure was the existing `internal/mcp/TestStdioMCPRoundTrip` dependency on `python3`, which is not installed in the minimal Alpine test image; the modified packages passed.

A real Pi CLI session also verified:

1. The model returned a standard `tool_calls` request.
2. Pi executed the requested Bash tool and returned the tool result.
3. The following turn reused the same conversation prefix and reported a non-zero `cacheRead` value.

The values exposed by this compatibility layer are estimates for visible request and completion content, not provider billing records.
