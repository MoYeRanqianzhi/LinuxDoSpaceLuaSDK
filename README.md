# LinuxDoSpace Lua SDK

This directory contains a Lua SDK implementation for LinuxDoSpace mail stream protocol.

## Scope

- `Client`, `Suffix`, `MailMessage` data shape
- Errors: authentication and stream error helpers
- Full token stream listener callback
- Local bind (exact/regex), ordered matching, `allow_overlap`
- `route`, `close`

## Runtime Dependencies

- `lua-http` (`http.request`)
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
