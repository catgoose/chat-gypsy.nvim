local Log = require("chat-gypsy").Log
local Path = require("plenary.path")

History = {}
History.__index = History

function History.new()
	local self = setmetatable({}, History)
	self.current = {}
	local gypsy_path = vim.fn.stdpath("data") .. "/chat-gypsy"
	if not vim.loop.fs_stat(gypsy_path) then
		vim.fn.mkdir(vim.fn.stdpath("data") .. "/chat-gypsy", "p")
	end
	self.path = gypsy_path .. "/history.json"
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
	if not self.current.id then
		self.current = {
			id = generate_random_id(),
			createdAt = os.time(),
			updatedAt = os.time(),
			messages = {},
		}
		Log.debug("Creating new chat: %s", vim.inspect(self.current))
	end
	table.insert(self.current.messages, {
		type = "prompt",
		message = prompt_message,
		time = os.time(),
		tokens = tonumber(tokens_tbl.prompt),
	})
	Log.debug("Inserting new prompt into history: %s", vim.inspect(self.current.messages[#self.current.messages]))
	table.insert(self.current.messages, {
		type = "response",
		message = response_message,
		time = os.time(),
		tokens = tonumber(tokens_tbl.response),
	})
	Log.debug("Inserting new response into history: %s", vim.inspect(self.current.messages[#self.current.messages]))
	self.current.updatedAt = os.time()
	vim.print(self.current)
end

function History:get()
	return self.current
end

function History:read()
	local path = Path:new(self.path)
	if not path:exists() then
		return
	end
	local ok, history = pcall(vim.fn.json_decode, path:read())
	if not ok then
		return
	end
	self.current = history
end

function History:save()
	Path:new(self.path):write(vim.fn.json_encode(self.current), "w")
end

return History
