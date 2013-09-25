
local function group(name) expects "string"
	return tags.div {
		tags.h1 {class = "side" } { name },				
		tags.div { style="clear: both; overflow: visible;height: 7px"}
		{
			tags.div {class = "lineup"}
			{
				tags.span {class = "lineupweak", style = "margin-right: 0px;"}
			},
			tags.span {class = "lineuplweak", style = "position: relative;"}
		}
	}
end

local function link(name, to) expects("string", "string")
	return tags.li {class="sb"}{ tags.a {href = to} { name } }
end

function create_build_template(title, menu_items, content)
		expects("string", "table", "table")
	local menuitems = {}
	
	for k,v in pairs(menu_items) do
		if type(v) == "table" then
			for name, url in pairs(v) do
				table.insert(menuitems, link(name, url))
			end
		else
			table.insert(menuitems, group(v))
		end
	end
	
	return tags.html {
		tags.head
		{
			tags.title { title },
			tags.meta {["http-equiv"] = "Content-Type", content="text/html; charset=UTF-8"},
			tags.link {type="text/css", rel="stylesheet", href="/build/style.css"}
		},
		tags.body
		{
			tags.div {class = "wrapper"}
			{
				tags.div {class = "tpbr"}{ tags.img {class="header", src = "/build/imgs/header.png" } },
				tags.div {class = "lineup"}
				{
					tags.span {class = "lineupl"},
					tags.span {class = "lineupr"},
					tags.span {class = "lineup"}
				},
				tags.div {class = "side"}
				{
					tags.br,
					tags.ul {class = "sb"}
					{
						unpack(menuitems)
					}
				},
				tags.div {class = "main"}
				{
					content
				},
				tags.div {class = "linedown", style = "clear: both; overflow: visible;"}
				{
					tags.span {class = "linedownl"},
					tags.span {class = "linedownr"},
					tags.span {class = "linedown"}
				},
				tags.div {class = "foot"}
				{
					"Copyright &copy; " .. os.date("*t").year .. " Blah.  All rights reserved."
				}
			}
		}
	}
end