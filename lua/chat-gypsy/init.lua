local Gypsy = {}

local log = {}

Gypsy.setup = function(opts)
	local cfg = require("chat-gypsy.config")
	cfg.init(opts)

	log = require("chat-gypsy.logger").init()

	if cfg.opts.dev then
		log.debug("Gypsy:setup: dev mode enabled")
	end
end

local chat = {}
local chats = {}

Gypsy.toggle = function()
	if #chats == 0 then
		Gypsy.open()
		return
	end
	if #chats == 1 then
		chat = table.remove(chats, 1)
		local layout = chat.ui.layout
		if layout.mounted then
			if not layout.hidden and not layout.is_focused() then
				layout.focus_last_win()
				table.insert(chats, chat)
				return
			end
			if layout.hidden and not layout.is_focused() then
				layout.show()
				table.insert(chats, chat)
				return
			end
			if not layout.hidden and layout.is_focused() then
				layout.hide()
				table.insert(chats, chat)
				return
			end
		else
			layout.mount()
			table.insert(chats, chat)
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
		chat = table.remove(chats, 1)
		local layout = chat.ui.layout
		if layout.mounted then
			layout.hide()
		end
	end
end

Gypsy.close = function()
	chat = table.remove(chats, 1)
	if chat.ui.layout.mounted then
		chat.ui.layout.unmount()
	end
end

vim.api.nvim_create_user_command("GypsyToggle", Gypsy.toggle, {})
vim.api.nvim_create_user_command("GypsyOpen", Gypsy.open, {})
vim.api.nvim_create_user_command("GypsyClose", Gypsy.close, {})
vim.api.nvim_create_user_command("GypsyHide", Gypsy.hide, {})

return Gypsy
