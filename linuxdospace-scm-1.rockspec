-- This rockspec intentionally describes the working tree for local development.
-- Tagged GitHub releases publish a versioned rockspec asset such as
-- `linuxdospace-0.1.2-1.rockspec`, aligned with the release tag.
package = "linuxdospace"
version = "scm-1"
source = {
  url = "."
}
description = {
  summary = "LinuxDoSpace Lua SDK",
  detailed = "Lua SDK for LinuxDoSpace token email stream with local mailbox routing.",
  license = "MIT"
}
dependencies = {
  "lua >= 5.1",
  "http",
  "dkjson"
}
build = {
  type = "builtin",
  modules = {
    ["linuxdospace"] = "linuxdospace/init.lua"
  }
}
