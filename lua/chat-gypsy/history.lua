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

local get_entries_from_file = function(file_path, on_error)
	local history_json = utils.decode_json_from_path(file_path)
	if history_json and history_json.name and history_json.description and history_json.keywords then
		return {
			name = history_json.name,
			description = history_json.description,
			keywords = history_json.keywords,
		}
	else
		local error = string.format(
			"history_json file %s is missing required fields. history_json: %s",
			file_path,
			vim.inspect(history_json)
		)
		on_error(error)
	end
end

local get_history_files = function(on_files_found, on_error)
	utils.find_files_in_directory(gypsy_data, on_files_found, on_error)
end

History.get_picker_entries = function(picker_cb)
	local on_error = function(err)
		Log.error(err)
		error(err)
	end
	local on_files_found = function(file_paths)
		local picker_entries = {}
		for _, file_path in ipairs(file_paths) do
			local entries = get_entries_from_file(file_path, on_error)
			table.insert(picker_entries, {
				path = {
					full = file_path,
					base = vim.fn.fnamemodify(file_path, ":t"),
				},
				entries = entries,
			})
		end
		picker_cb(picker_entries)
	end

	get_history_files(on_files_found, on_error)
end

return History
