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

local chat

Gypsy.Events.sub("layout:unmount", function()
	Gypsy.Log.trace("Events. layout:unmount")
	chat = nil
end)

Gypsy.toggle = function()
	if not chat then
		Gypsy.open()
		return
	end
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

Gypsy.open = function()
	if not chat then
		chat = require("chat-gypsy.layout"):new():init()
		chat.mount()
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

return Gypsy
