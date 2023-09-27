local Log = require("chat-gypsy").Log
local Events = require("chat-gypsy").Events
local Path = require("plenary.path")
local utils = require("chat-gypsy.utils")

History = {}

local current = {}
local history_id = ""
local file = ""
local json_path = ""
local gypsy_data = vim.fn.stdpath("data") .. "/chat-gypsy"
local id_len = 16

local reset = function()
	Log.trace("Resetting history")
	current = {}
	history_id = utils.generate_random_id(id_len)
	file = string.format("%s.json", history_id)
	json_path = string.format("%s/%s", gypsy_data, file)
end

Events.sub("history:reset", function()
	reset()
end)

History.init = function()
	reset()
	Path:new(gypsy_data):mkdir()
	return History
end

local save = function()
	Path:new(json_path):write(vim.fn.json_encode(current), "w")
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
		--compose a json object for this chat with the schema: {name: string, description: string, keywords: string[]}.  The description should be limited to 80 characters.  Break compound words in keywords into multiple terms in lowercase.  Only return the object.
		current = {
			id = history_id,
			createdAt = os.time(),
			updatedAt = os.time(),
			messages = {},
			name = "Programming Concepts Chat",
			description = "An explanation about closure and lexical scope in programming.",
			keywords = { "programming", "concepts", "chat", "closure", "lexical", "scope" },
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

local get_entries = function(path)
	local history = utils.decode_json_from_path(path)
	if history and history.name and history.description and history.keywords then
		return {
			name = history.name,
			description = history.description,
			keywords = history.keywords,
		}
	else
		Log.error(string.format("History file %s is missing required fields", path))
	end
end

local get_history_files = function(on_found)
	utils.find_files_in_directory(gypsy_data, on_found)
end

History.get_entries = function(on_entries)
	get_history_files(function(files)
		local paths = {}
		for _, path in ipairs(files) do
			table.insert(paths, {
				path = {
					full = path,
					base = vim.fn.fnamemodify(path, ":t"),
				},
				entries = get_entries(path),
			})
		end
		on_entries(paths)
	end)
end

return History
