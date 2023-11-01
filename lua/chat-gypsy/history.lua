local Log = require("chat-gypsy").Log
local Utils = require("chat-gypsy.utils")

local History = {}
History.__index = History

function History:new()
	setmetatable(self, History)
	self.messages = {}
	return self
end

function History:reset()
	self.messages = {}
end

function History:add_message(content, role, tokens)
	if not role or not Utils.check_roles(role) then
		return
	end
	tokens = Utils.deep_copy(tokens)
	Log.trace(
		string.format(
			[[Adding to history: content "%s" of role "%s" with tokens %s]],
			content,
			role,
			vim.inspect(tokens)
		)
	)
	table.insert(self.messages, {
		role = role,
		content = content,
		time = os.time(),
		tokens = tokens,
	})
	Log.trace(string.format("Inserting new message into history: %s", vim.inspect(self.messages[#self.messages])))
end

function History:get()
	return Utils.deep_copy(self.messages)
end

return History
