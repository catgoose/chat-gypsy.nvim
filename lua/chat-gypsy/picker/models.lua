local TelescopeProto = require("chat-gypsy.picker.prototype")

local TelescopeModels = setmetatable({}, TelescopeProto)
TelescopeModels.__index = TelescopeModels
setmetatable(TelescopeModels, {
	__index = TelescopeProto,
})

---@diagnostic disable-next-line: duplicate-set-field
function TelescopeModels:init() end

---@diagnostic disable-next-line: duplicate-set-field
function TelescopeModels:pick(opts)
	vim.print({ opts })
end

return TelescopeModels
