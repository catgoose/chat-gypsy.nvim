local Log = require("chat-gypsy").Log
local Events = require("chat-gypsy").Events
local Path = require("plenary.path")
local utils = require("chat-gypsy.utils")

History = {}

local current = {}
local history_id = ""
local file = ""
local path = ""
local gypsy_path = vim.fn.stdpath("data") .. "/chat-gypsy"
local id_len = 16

local reset = function()
	Log.debug("Resetting history")
	current = {}
	history_id = utils.generate_random_id(id_len)
	file = string.format("%s.json", history_id)
	path = string.format("%s/%s", gypsy_path, file)
end

Events.sub("history:reset", function()
	reset()
end)

History.init = function()
	reset()
	Path:new(gypsy_path):mkdir()
	return History
end

local save = function()
	Path:new(path):write(vim.fn.json_encode(current), "w")
end

local add = function(message, type, tokens)
	tokens = utils.deepcopy(tokens)
	if not type then
		return
	end
	if not vim.tbl_contains({ "prompt", "response" }, type) then
		return
	end
	if not current.id then
		current = {
			id = history_id,
			createdAt = os.time(),
			updatedAt = os.time(),
			messages = {},
		}
		Log.trace(string.format("Creating new chat: %s", vim.inspect(current)))
	end
	table.insert(current.messages, {
		type = type,
		message = message,
		time = os.time(),
		tokens = tokens,
	})
	Log.trace(string.format("Inserting new prompt into history: %s", vim.inspect(current.messages[#current.messages])))
	current.updatedAt = os.time()
	save()
end

History.add_prompt = function(message, tokens)
	local type = "prompt"
	add(message, type, tokens)
end

History.add_response = function(message, tokens)
	local type = "response"
	add(message, type, tokens)
end

History.get = function()
	return current
end

local read = function()
	local read_path = Path:new(path)
	if not read_path:exists() then
		return
	end
	--  TODO: 2023-09-25 - Path:read accepts a callback
	local ok, history = pcall(vim.fn.json_decode, read_path:read())
	if not ok then
		return
	end
	current = history
end

return History
