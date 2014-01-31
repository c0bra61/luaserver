websocket = {}
websocket.TEXT = 129
websocket.registered = {}

local sha1 = require("sha1")
local vstruct = require("vstruct")
local bit = require("bit")

local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
function base64(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

local function send_message(client, payload)
	local len = payload:len()
	local header
	local mode =  websocket.TEXT
	
	if len < 126 then
		header = {string.char(mode), string.char(len)}
	elseif len < 65536 then
		header = {
			string.char(mode),
			string.char(126),
			bit.band( bit.rshift(len, 8) , 255),
			bit.band( len                , 255),
		}
	else
		header = {
			string.char(mode),
			string.char(127),
			bit.band( bit.rshift(len, 56) , 255),
			bit.band( bit.rshift(len, 48) , 255),
			bit.band( bit.rshift(len, 40) , 255),
			bit.band( bit.rshift(len, 32) , 255),
			bit.band( bit.rshift(len, 24) , 255),
			bit.band( bit.rshift(len, 16) , 255),
			bit.band( bit.rshift(len,  8) , 255),
			bit.band( len                 , 255),
		}
	end
	
	client:send(string.format("%s%s", table.concat(header, ""), payload))
end

local function read_message(client)
	print("read message...")
	local type = client:receive(1)
	assert(string.byte(type) == websocket.TEXT, "this mode is not supported")
	
	local b1 = client:receive(1)
	local enc = bit.band(string.byte(b1), 128) == 128
	local len = 0
	
	if bit.band(string.byte(b1), 127) < 126 then -- 1 byte
		len  = bit.band(string.byte(b1), 127)
	elseif bit.band(string.byte(b1), 127) == 126 then -- 2 bytes
		len = 0
			+ bit.lshift(string.byte(client:receive(1)), 8)
			+ string.byte(client:receive(1))
	else -- 8 bytes
		len = 0
			+ bit.lshift(string.byte(client:receive(1)), 56)
			+ bit.lshift(string.byte(client:receive(1)), 48)
			+ bit.lshift(string.byte(client:receive(1)), 40)
			+ bit.lshift(string.byte(client:receive(1)), 32)
			+ bit.lshift(string.byte(client:receive(1)), 24)
			+ bit.lshift(string.byte(client:receive(1)), 16)
			+ bit.lshift(string.byte(client:receive(1)),  8)
			+ string.byte(client:receive(1))
	end
	
	local payload
	
	if enc then -- need to XOR 
		local mask = { client:receive(4):byte(1, 4) }
		local bytes = { client:receive(len):byte(1, len) }
		
		for i = 1, len do
			bytes[i] = bit.bxor(bytes[i], mask[((i - 1) % 4) + 1])
		end
		
		payload = string.char(unpack(bytes))
	else -- no need to XOR
		payload = client:receive(len)
	end
	
	return payload
end

local function Upgrade_websocket(request, response)
	local client = request:client()
	request:set_upgraded()
	
	local key      = request:headers()["Sec-WebSocket-Key"]
	local protocol = request:headers()["Sec-WebSocket-Protocol"]
	local version  = request:headers()["Sec-WebSocket-Version"]
	
	if not key or not protocol or not version then
		print(key, protocol, version)
		response:set_status(501)
		response:send()
		return
	end
	
	local path_tbl = websocket.registered[request:url()]
	if not path_tbl then
		response:set_status(404)
		response:send()
		return
	end
	
	local proto = path_tbl[protocol]
	if not proto then
		response:set_status(404)
		response:send()
		return
	end
	
	-- okay, there's a registered client, let's authenticate
	
	local hash = base64(sha1.binary(key .. "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
	
	print(string.format("websocket: %s: generated the hash %s from key %s", protocol, hash, key))
	
	response:clear_headers()
	response:set_status(101)
	response:set_header("Upgrade", "websocket")
	response:set_header("Connection", "Upgrade")
	response:set_header("Sec-WebSocket-Accept", hash)
	response:set_header("Sec-WebSocket-Protocol", protocol)
	response:send()
	
	-- client now should be a websocket protocol
	client:settimeout(0)
	proto.newclient(client)
	
	--	send_message(client, "hello")
	--	print(string.format("websocket: message: %s", read_message(client)))
	--	send_message(client, "world")
	--	print(string.format("websocket: message: %s", read_message(client)))
		--client:send("hello\n")
	--end
end

reqs.Upgrades["websocket"] = Upgrade_websocket

local meta = {}
meta._metatbl = {__index = meta}

function websocket.run()
	-- resume all coroutines
	for path, protos in pairs(websocket.registered) do
		for proto, prototbl in pairs(protos) do
			for client, thread in pairs(prototbl._client_threads) do
				--print(string.format("resuming client thread for %s at %s", proto, path))
				local _, err = coroutine.resume(thread)
				if err then
					table.RemoveValue(prototbl._clients, client)
					prototbl._client_threads[client] = nil
					print(string.format("websocket: %s at %s: %s", proto, path, err))
				end
			end
		end
	end
end

function websocket.done()
	return false -- TODO: not implimented yet
end

function websocket.register(path, protocol, callbacks) expects("string", "string", "table")
	websocket.registered[path] = websocket.registered[path] or {}
	websocket.registered[path][protocol] = {} -- TODO:
	
	print(string.format("websocket: registering %s at %s", protocol, path))
	
	local obj = websocket.registered[path][protocol]
	obj._path = path
	obj._protocol = protocol
	obj._callbacks = callbacks
	obj._clients = {}
	obj._client_threads = {}
	
	obj.newclient = function(client)
		--error("not implimented", 2)
		
		-- create a thread for them
		local thread = function()
			-- call the onconnect callback
			if obj._callbacks.onconnect then
				obj._callbacks.onconnect(client)
			end
			
			while true do
				local msg = read_message(client)
				if not msg then break end -- client disconnected
				
				if obj._callbacks.onmessage then
					obj._callbacks.onmessage(client, msg)
				end
			end
			
			if obj._callbacks.ondisconnect then
				obj._callbacks.ondisconnect(client)
			end
			table.RemoveValue(obj._clients, client) -- nil-ify them
			obj._client_threads[client] = nil
		end
		
		local co = coroutine.create(thread)
		table.insert(obj._clients, client)
		obj._client_threads[client] = co
	end
	
	return setmetatable(obj, meta._metatbl)
end

function meta:send(message, client) expects(meta._meta, "string")
	if client == nil then --send to all the clients
		for k,cl in pairs(self._clients) do
			send_message(cl, message)
		end
	else
		send_message(client, message)
	end
end

local tty
local function tty_onconnect(client)
	print("tty: client connected")
	tty:send("hello", client)
end
local function tty_ondisconnect(client)
	print("tty: client disconnected")
end
local function tty_onmessage(client, message)
	print("got message " .. message)
end
tty = websocket.register("/tty", "tty", {onconnect = tty_onconnect, ondisconnect = tty_ondisconnect, onmessage = tty_onmessage})



reqs.AddPattern("*", "/websocket", function(req, res)
	tags.html
	{
		tags.head
		{
			tags.script { type = "text/javascript", src = "//ajax.googleapis.com/ajax/libs/jquery/1.10.2/jquery.min.js" },
			tags.script
			{
				tags.NOESCAPE,
				[[
					function reverse(s){
						return s.split("").reverse().join("");
					}
					$( document ).ready(function()
					{
						con = new WebSocket("ws://localhost:8080/tty", "tty");    
						con.onopen = function() { document.write("open<br/>") }
						con.onmessage = function(event) {
							document.write("data: " + event.data + "<br/>") 
							con.send(reverse(event.data))
						}
						con.onclose = function(event) { document.write("close<br/>") }
					})
				]]
			}
		},
		tags.body
		{
		}
	}.to_response(res)
end)