---@class Picker
---@field history fun(opts: table)
---@field models  fun(opts: table)

local Picker = {}

local get_picker = function(picker)
	local pickers = {
		["history"] = "history",
		["models"] = "models",
	}
	if pickers[picker] then
		return require("chat-gypsy.picker." .. pickers[picker]):new()
	else
		return require("chat-gypsy.picker.prototype"):new()
	end
end

function Picker.history(opts)
	get_picker("history"):pick(opts)
end

function Picker.models(opts)
	get_picker("models"):pick(opts)
end

return Picker
