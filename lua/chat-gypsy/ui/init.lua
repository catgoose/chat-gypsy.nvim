---@class UI_INIT
---@field new fun(): UI
---@field Log Logger

local UI = require("chat-gypsy.ui.ui")

local UI_INIT = setmetatable({}, UI)
UI_INIT.__index = UI_INIT
setmetatable(UI_INIT, {
	__index = UI,
})

function UI_INIT:new()
	self.Log = require("chat-gypsy").Log
	self:ui_init()
	return self
end

return UI_INIT
