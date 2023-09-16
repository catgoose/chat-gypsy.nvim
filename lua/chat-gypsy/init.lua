local Gypsy = {}

Gypsy.Log = {}
Gypsy.Events = require("chat-gypsy.events").new()

Gypsy.setup = function(opts)
	local config = require("chat-gypsy.config")
	config.init(opts)

	Gypsy.Log = require("chat-gypsy.logger").init()
	require("chat-gypsy.usercmd").init()

	if config.plugin_cfg.dev then
		Gypsy.Log.info("Gypsy:setup: dev mode enabled")
	end
end

local chat = {}
local chats = {}

Gypsy.Events:sub("layout:unmount", function()
	Gypsy.Log.trace("Events: layout:unmount")
	chat = {}
	chats = {}
end)

Gypsy.toggle = function()
	if #chats == 0 then
		Gypsy.open()
		return
	end
	if #chats == 1 then
		chat = chats[1]
		local layout = chat.layout
		if layout._.mounted then
			if not layout._.hidden and not layout.is_focused() then
				layout.focus_last_win()
				return
			end
			if layout._.hidden and not layout.is_focused() then
				layout.show()
				return
			end
			if not layout._.hidden and layout.is_focused() then
				layout.hide()
				return
			end
		else
			layout.mount()
			return
		end
	end
end

Gypsy.open = function()
	if #chats == 0 then
		chat = require("chat-gypsy.ui").new()
		if not chat.layout._.mounted then
			table.insert(chats, chat)
			chat.layout.mount()
		end
	end
end

Gypsy.hide = function()
	if #chats == 1 then
		chat = chats[1]
		local layout = chat.layout
		if layout._.mounted and not layout._.hidden then
			layout.hide()
		end
	end
end

Gypsy.show = function()
	if #chats == 1 then
		chat = chats[1]
		chat = table.remove(chats, 1)
		local layout = chat.layout
		if layout._.mounted and layout._.hidden then
			layout.show()
		end
	end
end

Gypsy.close = function()
	chat = table.remove(chats, 1)
	if chat.layout._.mounted then
		chat.layout.unmount()
	end
end

return Gypsy
