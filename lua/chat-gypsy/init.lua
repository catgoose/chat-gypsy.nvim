local Gypsy = {}

local log = {}

Gypsy.setup = function(opts)
	local cfg = require("chat-gypsy.config")
	cfg.init(opts)

	log = require("chat-gypsy.logger").init()

	if cfg.opts.dev then
		log.debug("Gypsy:setup: dev mode enabled")
	end
	require("chat-gypsy.usercmd").init()
end

--  TODO: 2023-09-13 - should the chat class track the number of chats?
--  Gypsy.open should open a new chat if a chat is hidden.  Chats should be able
--  to be selected from using telescope or some other picker.

local chat = {}
local chats = {}

Gypsy.toggle = function()
	if #chats == 0 then
		Gypsy.open()
		return
	end
	if #chats == 1 then
		chat = chats[1]
		local layout = chat.ui.layout
		if layout.mounted then
			if not layout.hidden and not layout.is_focused() then
				layout.focus_last_win()
				return
			end
			if layout.hidden and not layout.is_focused() then
				layout.show()
				return
			end
			if not layout.hidden and layout.is_focused() then
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
		chat = require("chat-gypsy.chat").new(log)
		if not chat.ui.layout.mounted then
			table.insert(chats, chat)
			chat.ui.layout:mount()
		end
	end
end

Gypsy.hide = function()
	if #chats == 1 then
		chat = chats[1]
		local layout = chat.ui.layout
		if layout.mounted and not layout.hidden then
			layout.hide()
		end
	end
end

Gypsy.show = function()
	if #chats == 1 then
		chat = chats[1]
		chat = table.remove(chats, 1)
		local layout = chat.ui.layout
		if layout.mounted and layout.hidden then
			layout.show()
		end
	end
end

Gypsy.close = function()
	chat = table.remove(chats, 1)
	if chat.ui.layout.mounted then
		chat.ui.layout.unmount()
	end
end

return Gypsy
