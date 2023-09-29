local Log = require("chat-gypsy").Log
local Events = require("chat-gypsy").Events
local Path = require("plenary.path")
local utils = require("chat-gypsy.utils")

local History = {}
History.__index = History

function History:new()
	setmetatable(self, History)
	self.data_dir = vim.fn.stdpath("data") .. "/chat-gypsy"
	self.id_len = 16
	self.history_id = utils.generate_random_id(self.id_len)
	self.file = string.format("%s.json", self.history_id)
	self.json_path = string.format("%s/%s", self.data_dir, self.file)
	self:init()
	return self
end

function History:init_current()
	self.current = {
		id = self.history_id,
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
end

function History:init()
	self:init_current()
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
	Path:new(self.json_path):write(vim.fn.json_encode(self.current), "w")
end

function History:reset()
	Log.debug("Resetting history")
	self.history_id = utils.generate_random_id(self.id_len)
	self.file = string.format("%s.json", self.history_id)
	self.json_path = string.format("%s/%s", self.data_dir, self.file)
	self:init_current()
end

function History:add_message(message, role, tokens)
	tokens = utils.deepcopy(tokens)
	if not role then
		return
	end
	if not vim.tbl_contains({ "user", "assistant" }, role) then
		return
	end
	Log.debug(
		string.format(
			[[Adding to history: message "%s" of role "%s" with tokens %s]],
			message,
			role,
			vim.inspect(tokens)
		)
	)
	if not self.current.id then
		self:init_current()
		-- 	-- Only return the object.  Compose a json object for this chat with the schema: {name: string, description: string, keywords: string[]}.  The description should be limited to 80 characters.  Break compound words in keywords into multiple terms in lowercase.
	end
	table.insert(self.current.messages, {
		role = role,
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
	local role = "user"
	self:add_message(message, role, tokens)
end

function History:add_response(message, tokens)
	local role = "assistant"
	self:add_message(message, role, tokens)
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
