# Consumer Guide

## Integrate

Module import:

```lua
local lds = require("linuxdospace")
```

Runtime dependencies:

- Lua 5.4
- LuaRocks
- `http` / `lua-http`
- `dkjson`

Use the repository `scm-1` rockspec for development and the versioned rockspec
from GitHub Release for tagged releases.

## Full stream

```lua
local client = lds.Client.new({ token = "lds_pat..." })

client:listen(function(msg)
  print(msg.address, msg.subject)
end)

client:start()
```

## Mailbox binding

```lua
local box = client:bind({
  prefix = "alice",
  suffix = lds.Suffix.linuxdo_space,
  allow_overlap = false,
})

box:listen(function(msg)
  print(msg.subject)
end)
```

## Key semantics

- The stream starts on `client:start()`, not on `Client.new(...)`.
- Mailbox queues activate only after `mailbox:listen(...)`.
- `client:route({ address = ... })` is local matching only.

