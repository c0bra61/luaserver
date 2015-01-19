-- the reference that the type `socket` will be tested against
local none = require("luaflare.socket.none")
local script = require("luaflare.util.script")

local meta_socket_cache = {}

expects_types.socket = function(value)
	if meta_socket_cache[value] ~= nil then
		return meta_socket_cache[value]
	end
	
	local compat = metatable_compatible(none.client, value)
	
	meta_socket_cache[value] = compat
	
	return compat
end

local backend = script.options["socket-backend"] or "none"

return require("luaflare.socket." .. backend)