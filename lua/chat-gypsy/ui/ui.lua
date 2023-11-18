---@class UIState
---@field open boolean

---@class UI
---@field private _ UIState
---@field public ui_init fun()
---@field public toggle fun()
---@field public close fun()
---@field public open fun()

local Layout = require("chat-gypsy.ui.layout")

local UI = setmetatable({}, Layout)
UI.__index = UI
setmetatable(UI, {
	__index = Layout,
})

function UI:ui_init()
	self._ = {
		open = false,
	}
	self:layout_init()
end

function UI:toggle()
	if self._.open then
		self:close()
	else
		self:open()
	end
end

function UI:close()
	self._.open = false
end

function UI:open()
	self:set_layout("float")
	self:open_layout()
	self._.open = true
end

return UI
