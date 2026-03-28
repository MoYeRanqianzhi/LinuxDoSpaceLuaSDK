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
- `lds.Suffix.linuxdo_space` now resolves to the current token owner's
  canonical mail namespace: `<owner_username>-mail.linuxdo.space`
- `lds.semantic_suffix(lds.Suffix.linuxdo_space, "foo")` resolves to
  `<owner_username>-mailfoo.linuxdo.space`
- active semantic `-mail<suffix>` registrations are synchronized to
  `PUT /v1/token/email/filters`
- the legacy default alias `<owner_username>.linuxdo.space` still matches the
  default semantic binding automatically
- consumer code should keep using `lds.Suffix.linuxdo_space` instead of
  hardcoding a concrete `*-mail.linuxdo.space` namespace

## Protocol Notes

- `raw_message_base64` is decoded into the original raw mail payload before dispatch.
- NDJSON parsing keeps an internal line buffer so HTTP chunk boundaries do not split valid events.

## Runtime Dependencies

- Lua 5.4
- `liblua5.4-dev` when installing dependencies through LuaRocks on Debian/Ubuntu style systems
- LuaRocks
- `http` (`http.request`)
- `dkjson`

Recommended local verification commands:

```bash
lua5.4 -e "assert(loadfile('linuxdospace/init.lua'))"
lua5.4 -e "local m = require('linuxdospace'); assert(m.Client ~= nil)"
```

## Local Verification Status

Current environment does not have Lua runtime/toolchain installed, so this SDK was not run locally in this session.

## Release Model

- The repository root keeps `linuxdospace-scm-1.rockspec` as the development snapshot metadata.
- Tagged GitHub releases publish:
  - one source archive such as `linuxdospace-lua-v0.1.2.tar.gz`
  - one versioned rockspec such as `linuxdospace-0.1.2-1.rockspec`
- When consuming a tagged release, prefer the versioned release rockspec over the repository's `scm-1` rockspec.

## Example

```lua
local lds = require("linuxdospace")
local client = lds.Client.new({ token = "your-token" })
local box = client:bind({ prefix = "alice", suffix = lds.Suffix.linuxdo_space })
client:start()
```
