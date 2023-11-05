local Log = require("chat-gypsy").Log
local Utils = require("chat-gypsy.utils")

---@alias Role "user"|"system"|"assistant"

---@class Message
---@field role string
---@field content string
---@field time number
---@field tokens table

---@class History
---@field new fun(self: History): History
---@field add_message fun(self, content: string, role: string, tokens: table)
local History = {}
History.__index = History

---@return History
function History:new()
	setmetatable(self, History)
	self.messages = {}
	return self
end

---@return nil
function History:reset()
	self.messages = {}
end

---@param content string
---@param role Role
---@param tokens table
---@return nil
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

---@return Message[]
function History:get()
	return Utils.deep_copy(self.messages)
end

return History
