# LuaServer virtualfilesystem libary

`local vfs = require("luaserver.virtualfilesystem")`

## `string vfs.locate(string path, boolean fallback = false)`

Translates site relative file locations relative to the current working directory.
