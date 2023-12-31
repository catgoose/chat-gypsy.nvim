---@class Session
---@field public new fun(): Session
---@field public init fun()
---@field public toggle fun()
---@field public open fun()
---@field public restore fun(history: History)
---@field public hide fun()
---@field public show fun()
---@field public close fun()
---@field public chat Float

local Utils = require("chat-gypsy.utils")

local Session = {}
Session.__index = Session

function Session:new()
	setmetatable(self, Session)
	self.chat = nil
	self:init()
	return self
end

function Session:init()
	self.chat = { _ = {
		instance = false,
	} }
end

function Session:toggle()
	if not self.chat._.instance then
		self:open()
		return
	end
	if self.chat._.mounted then
		if not self.chat._.hidden and not self.chat.is_focused() then
			self.chat.focus_last_win()
			return
		end
		if self.chat._.hidden and not self.chat.is_focused() then
			self.chat.show()
			return
		end
		if not self.chat._.hidden and self.chat.is_focused() then
			self.chat.hide()
			return
		end
	else
		self.chat.mount()
		return
	end
end

function Session:open()
	if not self.chat._.instance then
		local ui_opts = {
			mount = true,
			injection = Utils.get_visual(),
		}
		self.chat = require("chat-gypsy.old-float"):new(ui_opts)
		self.chat._.instance = true
		return
	else
		self:hide()
	end
end

function Session:restore(history)
	if not self.chat._.instance then
		self.chat = require("chat-gypsy.old-float"):new({
			mount = true,
			restore_history = true,
			history = history,
		})
		self.chat._.instance = true
	end
end

function Session:hide()
	if self.chat._.mounted and not self.chat._.hidden then
		self.chat.hide()
	end
end

function Session:show()
	if self.chat._.mounted and self.chat._.hidden then
		self.chat.show()
	end
end

function Session:close()
	if self.chat._.mounted then
		self.chat.unmount()
		self:init()
	end
end

return Session
