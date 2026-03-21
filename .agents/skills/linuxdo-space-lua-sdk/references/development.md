# Development Guide

## Workdir

```bash
cd sdk/lua
```

## Validate

```bash
lua5.4 -e "assert(loadfile('linuxdospace/init.lua'))"
lua5.4 -e "local m = require('linuxdospace'); assert(m.Client ~= nil)"
```

## Release model

- Workflow file: `../../../.github/workflows/release.yml`
- Trigger: push tag `v*`
- Current release outputs are a source archive plus a versioned rockspec on GitHub Release

## Keep aligned

- `../../../linuxdospace/init.lua`
- `../../../linuxdospace-scm-1.rockspec`
- `../../../README.md`
- `../../../.github/workflows/ci.yml`
- `../../../.github/workflows/release.yml`

