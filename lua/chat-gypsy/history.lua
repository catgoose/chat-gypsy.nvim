local Log = require("chat-gypsy").Log
History = {}
History.__index = History

function History.new()
	local self = setmetatable({}, History)
	self.history = {}
	return self
end

local generate_random_id = function()
	local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	local result = ""
	for _ = 1, 8 do
		local rand = math.random(#charset)
		result = result .. string.sub(charset, rand, rand)
	end
	return result
end

function History:add(prompt_message, response_message, tokens_tbl)
	if not self.history.id then
		self.history = {
			id = generate_random_id(),
			createdAt = os.time(),
			updatedAt = os.time(),
			messages = {},
		}
		Log.debug("Creating new chat: %s", vim.inspect(self.history))
	end
	table.insert(self.history.messages, {
		type = "prompt",
		message = prompt_message,
		time = os.time(),
		tokens = tonumber(tokens_tbl.prompt),
	})
	Log.debug("Inserting new prompt into history: %s", vim.inspect(self.history.messages[#self.history.messages]))
	table.insert(self.history.messages, {
		type = "response",
		message = response_message,
		time = os.time(),
		tokens = tonumber(tokens_tbl.response),
	})
	Log.debug("Inserting new response into history: %s", vim.inspect(self.history.messages[#self.history.messages]))
	self.history.updatedAt = os.time()
end

return History
