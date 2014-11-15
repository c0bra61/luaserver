local luaserver = require("luaserver")
local vfs = {}
vfs.mount_points = { "./" }

--[[
LuaServer file structure:

/etc/luaserver/luaserver.cfg

]]

function vfs.locate(string path, boolean fallback = false)
	assert(path:sub(1,1) == "/")
	local selfdir = ""
	local info = debug.getinfo(2) -- caller info
	
	local source = info.source
	local root = luaserver.config_path
	
	assert(source:sub(1, root:len()) == root)
	
	local post = source:sub(root:len() + 1, -1)
	if post:starts_with("/sites/") then
		selfdir = root .. post:match("(/sites/.-)/")
	else
		selfdir = root
	end
	
	return selfdir .. path
end

function vfs.exists(string path)
end

function vfs.mount(string path)
end

return vfs