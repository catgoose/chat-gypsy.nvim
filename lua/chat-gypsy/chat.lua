local Chat = {}
Chat.__index = Chat

function Chat.new()
	local self = setmetatable({}, Chat)
	local queue = require("chat-gypsy.queue").new()
	local openai = require("chat-gypsy.openai").new(queue)
	self.ui = require("chat-gypsy.ui").new(openai)
	return self
end

return Chat
