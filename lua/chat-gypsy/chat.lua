local Chat = {}
Chat.__index = Chat

function Chat.new(log)
	local self = setmetatable({}, Chat)
	local queue = require("chat-gypsy.queue").new()
	local openai = require("chat-gypsy.openai").new(log, queue)
	self.ui = require("chat-gypsy.ui").new(log, openai)
	return self
end

return Chat
