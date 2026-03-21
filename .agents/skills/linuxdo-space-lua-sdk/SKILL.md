---
name: linuxdo-space-lua-sdk
description: Use when writing or fixing Lua code that consumes or maintains the LinuxDoSpace Lua SDK under sdk/lua. Use for LuaRocks/source integration, callback-based full-stream usage, mailbox bindings, client:start lifecycle, allow_overlap semantics, release guidance, and local validation.
---

# LinuxDoSpace Lua SDK

Read [references/consumer.md](references/consumer.md) first for normal SDK usage.
Read [references/api.md](references/api.md) for exact public Lua API names.
Read [references/examples.md](references/examples.md) for task-shaped snippets.
Read [references/development.md](references/development.md) only when editing `sdk/lua`.

## Workflow

1. Prefer the module import `local lds = require("linuxdospace")`.
2. The SDK root relative to this `SKILL.md` is `../../../`.
3. Preserve these invariants:
   - `Client.new(...)` validates configuration but does not open the stream yet
   - `client:start()` opens the shared upstream HTTPS NDJSON stream
   - `client:listen(callback)` registers full-stream callbacks
   - `client:bind(...)` creates local mailbox bindings
   - `mailbox:listen(callback)` activates mailbox delivery
   - `lds.Suffix.linuxdo_space` is semantic and resolves after `ready.owner_username`
   - exact and pattern bindings share one ordered chain per suffix
   - `allow_overlap=false` stops at first match; `true` continues
4. Keep README, Lua source, rockspec, and workflows aligned when behavior changes.
5. Validate with the commands in `references/development.md`.

## Do Not Regress

- Do not claim the stream opens automatically during `Client.new(...)`.
- Do not claim a public mailbox single-listener guard that the current Lua code does not implement.
- Do not document public registry publication; current release path is GitHub assets plus rockspec files.

