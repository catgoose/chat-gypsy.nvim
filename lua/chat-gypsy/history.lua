local Log = require("chat-gypsy").Log
local Path = require("plenary.path")
local utils = require("chat-gypsy.utils")

History = {}

local current = {}
local history_id = ""
local file = ""
local path = ""
local gypsy_path = vim.fn.stdpath("data") .. "/chat-gypsy"

History.reset = function()
	current = {}
	history_id = utils.generate_random_id()
	file = string.format("%s.json", history_id)
	path = string.format("%s/%s", gypsy_path, file)
end

History.init = function()
	History.reset()
	utils.mkdir(gypsy_path)
	return History
end

local save = function()
	Path:new(path):write(vim.fn.json_encode(current), "w")
end

History.add = function(prompt_message, response_message, tokens_tbl)
	if not current.id then
		current = {
			id = history_id,
			createdAt = os.time(),
			updatedAt = os.time(),
			messages = {},
		}
		Log.debug("Creating new chat: %s", vim.inspect(current))
	end
	table.insert(current.messages, {
		type = "prompt",
		message = prompt_message,
		time = os.time(),
		tokens = tonumber(tokens_tbl.prompt),
	})
	Log.debug("Inserting new prompt into history: %s", vim.inspect(current.messages[#current.messages]))
	table.insert(current.messages, {
		type = "response",
		message = response_message,
		time = os.time(),
		tokens = tonumber(tokens_tbl.response),
	})
	Log.debug("Inserting new response into history: %s", vim.inspect(current.messages[#current.messages]))
	current.updatedAt = os.time()
	save()
end

History.get = function()
	return current
end

local read = function()
	local read_path = Path:new(path)
	if not read_path:exists() then
		return
	end
	local ok, history = pcall(vim.fn.json_decode, read_path:read())
	if not ok then
		return
	end
	current = history
end

return History
