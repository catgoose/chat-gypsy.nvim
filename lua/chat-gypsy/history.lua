local Log = require("chat-gypsy").Log
local Events = require("chat-gypsy").Events
local Path = require("plenary.path")
local utils = require("chat-gypsy.utils")

--  BUG: 2023-09-28 - initial prompt being sent is not being saved to history
local History = {}
History.__index = History

function History:new()
	setmetatable(self, History)
	self.current = {}
	self.data_dir = vim.fn.stdpath("data") .. "/chat-gypsy"
	self.id_len = 16
	self.history_id = utils.generate_random_id(self.id_len)
	self.file = string.format("%s.json", self.history_id)
	self.json_path = string.format("%s/%s", self.data_dir, self.file)
	self.queue = require("chat-gypsy.queue"):new()
	self:init()
	return self
end

function History:init()
	Path:new(self.data_dir):mkdir()
	Events.sub("history:reset", function(queue_next)
		local request = require("chat-gypsy.request"):new()
		local on_complete = function()
			self:save()
			self:reset()
			queue_next()
		end
		request.compose_entries(self.current, on_complete)
	end)
end

function History:save()
	local save = function(queue_next)
		Path:new(self.json_path):write(vim.fn.json_encode(self.current), "w")
		queue_next()
	end
	self.queue:add(save)
end

function History:reset()
	Log.debug("Resetting history")
	self.history_id = utils.generate_random_id(self.id_len)
	self.file = string.format("%s.json", self.history_id)
	self.json_path = string.format("%s/%s", self.data_dir, self.file)
	self.current = {}
end

function History:add_message(message, type, tokens)
	tokens = utils.deepcopy(tokens)
	if not type then
		return
	end
	if not vim.tbl_contains({ "prompt", "response" }, type) then
		return
	end
	if not self.current.id then
		-- 	-- Only return the object.  Compose a json object for this chat with the schema: {name: string, description: string, keywords: string[]}.  The description should be limited to 80 characters.  Break compound words in keywords into multiple terms in lowercase.
		self.current = {
			id = nil,
			createdAt = os.time(),
			updatedAt = os.time(),
			messages = {},
			openai_params = {},
			entries = {
				name = nil,
				description = nil,
				keywords = {},
			},
		}

		-- Log.trace(string.format("Creating new chat: %s", vim.inspect(self.current)))
	end
	table.insert(self.current.messages, {
		type = type,
		message = message,
		time = os.time(),
		tokens = tokens,
	})
	Log.debug(
		string.format(
			"Inserting new prompt into history: %s",
			vim.inspect(self.current.messages[#self.current.messages])
		)
	)
	self.current.updatedAt = os.time()
	self:save()
end

function History:add_prompt(message, tokens)
	local type = "prompt"
	local add_message = function(queue_next)
		self:add_message(message, type, tokens)
	end
	self.queue:add(add_message)
end

function History:add_response(message, tokens)
	local add_message = function(queue_next)
		local type = "response"
		self:add_message(message, type, tokens)
	end
	self.queue:add(add_message)
end

function History:add_openai_params(openai_params)
	self.current.openai_params = openai_params
	self:save()
end

local get_entries_from_file = function(file_path, on_error)
	local history_json = utils.decode_json_from_path(file_path, on_error)
	if
		history_json
		and history_json.entries
		and history_json.entries.name
		and history_json.entries.description
		and history_json.entries.keywords
	then
		return history_json.entries
	else
		return nil
	end
end

function History:get_picker_entries(picker_cb)
	local on_error = function(err)
		if err then
			Log.error(err)
			error(err)
		end
	end
	local on_files_found = function(file_paths)
		local picker_entries = {}
		for _, file_path in ipairs(file_paths) do
			local entries = get_entries_from_file(file_path, on_error)
			if entries then
				table.insert(picker_entries, {
					path = {
						full = file_path,
						base = vim.fn.fnamemodify(file_path, ":t"),
					},
					entries = entries,
				})
			end
		end
		picker_cb(picker_entries)
	end

	utils.find_files_in_directory(self.data_dir, on_files_found, on_error)
end

return History
