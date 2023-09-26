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

	if Gypsy.Config.plugin_cfg.dev then
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
	local symbols = Gypsy.Config.symbols
	local symbols2 = Gypsy.Config.symbols
	vim.print(symbols.horiz == symbols2.horiz)
	symbols.horiz = "asdf"
	vim.print(symbols.horiz == symbols2.horiz)
	symbols2.horiz = "1234"
	vim.print(symbols.horiz == symbols2.horiz)
	if not chat then
		chat = require("chat-gypsy.layout"):new({
			mount = Gypsy.Config.opts.ui.behavior.mount,
			layout = Gypsy.Config.opts.ui.behavior.layout,
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

return Gypsy
