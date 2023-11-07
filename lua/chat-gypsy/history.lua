---@alias Role "user"|"system"|"assistant"

---@class Token
---@field system number
---@field user number
---@field assistant number
---@field total number

---@class Message
---@field role string
---@field content string
---@field time number
---@field tokens table

---@class History
---@field new fun(self: History): History
---@field add_message fun(self, content: string, role: string, tokens: Token)
---@field get fun(self): Message[]

local Log = require("chat-gypsy").Log
local Utils = require("chat-gypsy.utils")

local History = {}
History.__index = History

---@return History
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
