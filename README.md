# LinuxDoSpace Lua SDK

This directory contains a Lua SDK implementation for LinuxDoSpace mail stream protocol.

## Scope

- `Client`, `Suffix`, `MailMessage` data shape
- Errors: authentication and stream error helpers
- Full token stream listener callback
- Local bind (exact/Lua pattern), ordered matching, `allow_overlap`
- `route`, `close`

Important:

- `lds.Suffix.linuxdo_space` is semantic, not literal
- the SDK resolves it to `<owner_username>.linuxdo.space` after `ready.owner_username`

## Protocol Notes

- `raw_message_base64` is decoded into the original raw mail payload before dispatch.
- NDJSON parsing keeps an internal line buffer so HTTP chunk boundaries do not split valid events.

## Runtime Dependencies

- `http` (`http.request`)
- `dkjson`

## Local Verification Status

Current environment does not have Lua runtime/toolchain installed, so this SDK was not run locally in this session.

## Example

```lua
local lds = require("linuxdospace")
local client = lds.Client.new({ token = "your-token" })
local box = client:bind({ prefix = "alice", suffix = lds.Suffix.linuxdo_space })
client:start()
```
