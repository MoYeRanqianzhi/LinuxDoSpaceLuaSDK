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
  "lua-http",
  "dkjson"
}
build = {
  type = "builtin",
  modules = {
    ["linuxdospace"] = "linuxdospace/init.lua"
  }
}
