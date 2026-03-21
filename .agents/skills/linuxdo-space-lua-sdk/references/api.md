# API Reference

## Paths

- SDK root: `../../../`
- Module source: `../../../linuxdospace/init.lua`
- Rockspec: `../../../linuxdospace-scm-1.rockspec`
- Consumer README: `../../../README.md`

## Public surface

- Module exports:
  - `Suffix.linuxdo_space`
  - `Client`
  - `LinuxDoSpaceError`
  - `AuthenticationError`
  - `StreamError`
- Client:
  - `Client.new({...})`
  - `client:listen(callback)`
  - `client:bind({...})`
  - `client:route({ address = ... })`
  - `client:start()`
  - `client:close()`
- Mailbox:
  - `mailbox:listen(callback)`
  - `mailbox:close()`

## Semantics

- `Client.new(...)` validates config but does not connect yet.
- `client:start()` opens the shared NDJSON stream.
- `client:route(...)` only uses the current `address`.
- Full-stream `msg.address` is the first recipient projection.
- Mailbox delivery rewrites `address` to the matched recipient projection.
