local Chat = {}
Chat.__index = Chat

function Chat.new(log)
	local self = setmetatable({}, Chat)
	local queue = require("gypsy.queue").new()
	local openai = require("gypsy.openai").new(log, queue)
	self.ui = require("gypsy.ui").new(log, openai)
	return self
end

return Chat
