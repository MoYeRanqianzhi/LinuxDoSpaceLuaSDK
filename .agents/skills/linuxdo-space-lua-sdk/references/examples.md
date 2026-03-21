# Task Templates

## Register one full-stream callback

```lua
client:listen(function(msg)
  print(msg.address)
end)
client:start()
```

## Add one exact mailbox

```lua
local alice = client:bind({
  prefix = "alice",
  suffix = lds.Suffix.linuxdo_space,
})
```

## Add one catch-all

```lua
local catch_all = client:bind({
  pattern = ".*",
  suffix = lds.Suffix.linuxdo_space,
  allow_overlap = true,
})
```

