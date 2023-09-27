local Path = require("plenary.path")

local Gypsy = {}

Gypsy.Log = {}
Gypsy.History = {}
Gypsy.Events = require("chat-gypsy.events")
Gypsy.Config = {}

Gypsy.setup = function(opts)
	Gypsy.Config = require("chat-gypsy.config")
	Gypsy.Config.init(opts)

	Gypsy.Log = require("chat-gypsy.logger").init()
	Gypsy.History = require("chat-gypsy.history").init()

	require("chat-gypsy.usercmd").init()
	require("chat-gypsy.models").init()

	if Gypsy.Config.get("plugin_cfg").dev then
		Gypsy.Log.info("Gypsy:setup: dev mode enabled")
	end
end

local chat

Gypsy.Events.sub("layout:unmount", function()
	Gypsy.Log.trace("Events. layout:unmount")
	chat = nil
end)

Gypsy.toggle = function()
	Gypsy.history()
	-- if not chat then
	-- 	Gypsy.open()
	-- 	return
	-- end
	-- if chat._.mounted then
	-- 	if not chat._.hidden and not chat.is_focused() then
	-- 		chat.focus_last_win()
	-- 		return
	-- 	end
	-- 	if chat._.hidden and not chat.is_focused() then
	-- 		chat.show()
	-- 		return
	-- 	end
	-- 	if not chat._.hidden and chat.is_focused() then
	-- 		chat.hide()
	-- 		return
	-- 	end
	-- else
	-- 	chat.mount()
	-- 	return
	-- end
end

Gypsy.open = function()
	if not chat then
		chat = require("chat-gypsy.layout"):new({
			mount = Gypsy.Config.get("opts").ui.behavior.mount,
			layout = Gypsy.Config.get("opts").ui.behavior.layout,
		})
		return
	else
		Gypsy.hide()
	end
end

Gypsy.hide = function()
	if chat._.mounted and not chat._.hidden then
		chat.hide()
	end
end

Gypsy.show = function()
	if chat._.mounted and chat._.hidden then
		chat.show()
	end
end

Gypsy.close = function()
	if chat._.mounted then
		chat.unmount()
	end
end

Gypsy.history = function()
	-- require("chat-gypsy.telescope").history()
	-- History.get_files(function() end)
	local get_contents = function(path)
		local contents = Path:new(path):read()
		local return_table = {}
		for _, tbl in pairs(vim.json.decode(contents)) do
			-- table.insert(return_table, {
			-- 	name = tbl.name,
			-- 	description = tbl.description,
			-- 	keywords = tbl.keywords,
			-- })
			vim.print(tbl)
		end
		return return_table
		-- return vim.tbl_map(function(t)
		-- 	return {
		-- 		name = t.name,
		-- 		description = t.description,
		-- 		keywords = t.keywords,
		-- 	}
		-- end, vim.json.decode(contents))
	end
	History.chat_entries(function(response)
		local paths = {}
		for _, path in ipairs(response) do
			table.insert(paths, {
				full = path,
				base = vim.fn.fnamemodify(path, ":t"),
				contents = get_contents(path),
			})
		end
		vim.print(paths)
	end)
end

return Gypsy
