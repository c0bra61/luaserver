reqs.AddPattern("*", "/profile/(%d+)", function(request, response, id)
	id = tonumber(id)
	
	-- error is on purpose
	response:apend("Hello, you requested the profile id " .. id .. tostring(request))
end)

local template = tags.html
{
	tags.head
	{
		tags.title { tags.SECTION },
		tags.style
		{
			[[
			body {
				background-color: #DDDDDD;
				font-family: Helvetica, Arial, sans-serif;
			}
			div.bg_wrapper
			{
				width: 600px;
				margin: 0px auto;
				margin-top: 50px;
				background-color: #ffffff;
				background-image: url(http://lua-users.org/files/wiki_insecure/lua-icons-png/lua-256x256.png);
				background-repeat: no-repeat;
				background-position: center center;
				box-shadow: 0px 0px 50px #888888;
			}
			div.wrapper {
				background-color: rgba(255, 255, 255, 0.95);
				#border-radius: 4px;
				padding: 15px;
			}
			div.box {
				background-color: rgba(240, 240, 255, 0.5);
				border: 1px solid #ddddff;
				padding: 5px;
				overflow: auto;
				overflow-y: hidden;
			}
			div.nowrap {
				white-space: nowrap;
			}
			]]
		}
	},
	tags.body
	{
		tags.div {class = "bg_wrapper"}
		{
			tags.div {class = "wrapper"}
			{
				tags.p {style = "font-size: 22; margin-top: 0px; border-bottom: 1px solid #dddddd"}
				{
					tags.SECTION
				},
				tags.SECTION
			}
		}
	}
}

local last_runlua = ""
local function run_lua_page(req, res)
	local content = tags.div
	{
		tags.p { "Run Lua code:" },
		tags.form {method = "post", action = "/runlua"}
		{
			tags.SECTION,
			tags.input{type = "submit"}
		},
		tags.div {class = "box nowrap"}
		{
			tags.SECTION
		}
	}
	
	local title = "Run Lua"
	local lua = req.post_data.lua or [[function fact (n)
    if n == 0 then
        return 1
    else
        return n * fact(n-1)
    end
end


return fact(4)]]
	
	template.to_response(res, 0) -- <title>
	res:append(title)
	template.to_response(res, 1) -- header
	res:append(title)
	template.to_response(res, 2) -- content
	
		content.to_response(res, 0)
		res:append("<textarea name='lua' rows=20 cols=68>\n")
		res:append(html_escape(lua, false))
		res:append("</textarea>\n")
		
		content.to_response(res, 1)
			-- output
			
			local function print(...)
				local prefix = ""
				
				local args = {...}
				
				for i=1, #args do
					local v = args[i]
					res:append(html_escape(prefix .. tostring(v)))
					prefix = ", \t"
				end
				
				if prefix ~= "" then
					res:append(html_escape("\n"))
				end
			end
			
			local function timeout()
				hook.Call("Error", {type = 501, message = "code took too long to execute"}, req, res)
				error("function timed out", 2)
			end
			
			last_runlua = lua
			
			local func, err = loadstring(lua, "runlua")
			
			if not func then error(err, -1) end
			
			------------------------------ ENVIROMENT
			local meta_tables = {}

			local function safe_setmetatable(tbl, meta)
				if getmetatable(tbl) and meta_tables[tbl] == nil then return error("sandbox error: unsafe setmetatable!", 2) end

				meta_tables[tbl] = meta
				setmetatable(tbl, meta)
			end

			local function safe_getmetatable(tbl)
				return meta_tables[tbl]
			end
			
			local env = {
				print = print,
				ipairs = ipairs, tonumber = tonumber, next = next, pairs = pairs, 
				pcall = pcall, tonumber = tonumber, tostring = tostring, type = type,
				unpack = unpack, setmetatable = safe_setmetatable, getmetatable = safe_getmetatable, 
				coroutine = {
					create = coroutine.create, resume = coroutine.resume, 
					running = coroutine.running, status = coroutine.status, 
					wrap = coroutine.wrap, yield = coroutine.yield
				},
				string = { 
					byte = string.byte, char = string.char, find = string.find, 
					format = string.format, gmatch = string.gmatch, gsub = string.gsub, 
					len = string.len, lower = string.lower, match = string.match, 
					rep = string.rep, reverse = string.reverse, sub = string.sub, 
					upper = string.upper, Trim = string.Trim, Right = string.Right,
					ToMinutesSeconds = string.ToMinutesSeconds, Replace = string.Replace,
					SetChar = string.SetChar, StartWith = string.StartWith, Left = string.Left,
					TrimLeft = string.TrimLeft, GetExtensionFromFilename = string.GetExtensionFromFilename,
					Implode = string.Implode, GetPathFromFilename = string.GetPathFromFilename,
					Comma = string.Comma, JavascriptSafe = string.JavascriptSafe, 
					StripExtension = string.StripExtension, FromColor = string.FromColor,
					GetChar = string.GetChar, EndsWith = string.EndsWith, 
					NiceSize = string.NiceSize, GetFileFromFilename = string.GetFileFromFilename, 
					TrimRight = string.TrimRight, NiceTime = string.NiceTime, 
					ToTable = string.ToTable, Explode = string.Explode, Split = string.Split,
					ToMinutesSecondsMilliseconds = string.ToMinutesSecondsMilliseconds, 
					FormattedTime = string.FormattedTime, ToColor = string.ToColor
				},
				table = {
					insert = table.insert, maxn = table.maxn, remove = table.remove, 
					sort = table.sort, HasValue = table.HasValue, Count = table.Count
				},
				math = { --table.Copy(math)
					abs = math.abs, acos = math.acos, asin = math.asin, 
					atan = math.atan, atan2 = math.atan2, ceil = math.ceil, cos = math.cos, 
					cosh = math.cosh, deg = math.deg, exp = math.exp, floor = math.floor, 
					fmod = math.fmod, frexp = math.frexp, huge = math.huge, 
					ldexp = math.ldexp, log = math.log, log10 = math.log10, max = math.max, 
					min = math.min, modf = math.modf, pi = math.pi, pow = math.pow, 
					rad = math.rad, random = math.random, sin = math.sin, sinh = math.sinh, 
					sqrt = math.sqrt, tan = math.tan, tanh = math.tanh,
					Round = math.Round, Clamp = math.Clamp
				},
				--os = { clock = os.clock, difftime = os.difftime, time = os.time },
				--bit = {
				--	tobit = bit.tobit, tohex = bit.tohex, bnot = bit.bnot,
				--	band = bit.band, bor = bit.bor, bxor = bit.bxor,
				--	lshift = bit.lshift, rshift = bit.rshift, 
				--	arshift = bit.arshift, rol = bit.rol, ror = bit.ror, 
				--	bswap = bit.bswap
				--},
			}
			
			env._G = env
			
			setfenv(func, env)
			
			--------------------------------------------------- END ENV
			
			local oldhook = debug.gethook()
			debug.sethook(timeout, "", 1000)
			local rets = {pcall(func)}
			
			if not rets[1] then
				debug.sethook(oldhook)
				return
			end
			table.remove(rets, 1)
			debug.sethook(oldhook)
			
			
			
			local prefix = "returned "
			for k,v in pairs(rets) do
				res:append(html_escape(prefix .. to_lua_value(v)))
				prefix = ", "
			end
		content.to_response(res, 2)
		
	template.to_response(res, 3)
end
reqs.AddPattern("*", "/runlua", run_lua_page)

hook.Add("LuaGetLine", "locate runstring", function(err)
	local line_num = err:match('%[string "runlua"]:(%d+): ')
	
	if line_num then
		line_num = tonumber(line_num)
		local line = ""
		
		for i=1, last_runlua:len() do
			local char = last_runlua:sub(i, i)
			
			if char == '\n' then
				line_num = line_num - 1
				if line_num == 0 then break end
				line = ""
			else
				line = line .. char
			end
		end
		
		return line
	end
end)
