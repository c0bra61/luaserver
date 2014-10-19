local stack

local meta = {}
meta._meta = {__index = meta}

function stack()
	local ret = {_tbl = {}}
	return setmetatable(ret, meta._meta)
end

function meta:push(val) expects (meta)
	table.insert(self._tbl, val)
end

function meta:pop() expects (meta)
	table.remove(self._tbl, 1)
end

function meta:value() expects (meta)
	return self._tbl[1]
end

function meta:all() expects (meta)
	return self._tbl
end

return stack
