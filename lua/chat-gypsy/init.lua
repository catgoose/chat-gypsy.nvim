local Gypsy = {}

Gypsy.Log = {}
Gypsy.History = {}
Gypsy.Events = require("chat-gypsy.events")

Gypsy.setup = function(opts)
	local config = require("chat-gypsy.config")
	config.init(opts)

	Gypsy.Log = require("chat-gypsy.logger").init()
	Gypsy.History = require("chat-gypsy.history").init()

	require("chat-gypsy.usercmd").init()
	require("chat-gypsy.models").init()

	if config.plugin_cfg.dev then
		Gypsy.Log.info("Gypsy:setup: dev mode enabled")
	end
end

local chat = {}
local chats = {}

Gypsy.Events.sub("layout:unmount", function()
	Gypsy.Log.trace("Events. layout:unmount")
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
		if chat._.mounted then
			if not chat._.hidden and not chat.is_focused() then
				chat.focus_last_win()
				return
			end
			if chat._.hidden and not chat.is_focused() then
				chat.show()
				return
			end
			if not chat._.hidden and chat.is_focused() then
				chat.hide()
				return
			end
		else
			chat.mount()
			return
		end
	end
end

Gypsy.open = function()
	if #chats == 0 then
		chat = require("chat-gypsy.layout"):new()
		chat:init()
		if not chat._.mounted then
			table.insert(chats, chat)
			chat:mount()
		end
	end
end

Gypsy.hide = function()
	if #chats == 1 then
		chat = table.remove(chats, 1)
		if chat._.mounted and not chat._.hidden then
			chat.hide()
		end
	end
end

Gypsy.show = function()
	if #chats == 1 then
		chat = table.remove(chats, 1)
		if chat._.mounted and chat._.hidden then
			chat.show()
		end
	end
end

Gypsy.close = function()
	chat = table.remove(chats, 1)
	if chat._.mounted then
		chat.unmount()
	end
end

return Gypsy
