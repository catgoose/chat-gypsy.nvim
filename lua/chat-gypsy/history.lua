local Log = require("chat-gypsy").Log
local Path = require("plenary.path")
local utils = require("chat-gypsy.utils")
local plugin_opts = require("chat-gypsy").Config.get("plugin_opts")

local History = {}
History.__index = History

function History:new()
	setmetatable(self, History)
	self.data_dir = string.format("%s/%s", vim.fn.stdpath("data"), plugin_opts.name)
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
end

function History:compose_entries(request)
	local on_complete = function()
		self:save()
		--  BUG: 2023-10-05 - Sending a history to compose entries while another
		--  history composition is finishing will result in the history being reset
		--  by the on_complete of the previous request which causes the history to
		--  be reset prematurely
		--  FIX: 2023-10-05 - Stop storing history as state, use sqlite instead
		self:reset()
	end
	--  TODO: 2023-10-06 - When reloading a history, don't recompose entries
	--  unless a new message has been added
	if #self.current.messages > 0 then
		request:compose_entries(self.current, on_complete)
	end
end

function History:save()
	Path:new(self.json_path):write(vim.fn.json_encode(self.current), "w")
end

function History:reset()
	Log.trace("Resetting history")
	self.history_id = utils.generate_random_id(self.id_len)
	self.file = string.format("%s.json", self.history_id)
	self.json_path = string.format("%s/%s", self.data_dir, self.file)
	self:init_current()
end

function History:add_message(message, role, tokens)
	if not role then
		return
	end
	if not vim.tbl_contains({ "user", "assistant" }, role) then
		return
	end
	tokens = utils.deepcopy(tokens)
	Log.trace(
		string.format(
			[[Adding to history: message "%s" of role "%s" with tokens %s]],
			message,
			role,
			vim.inspect(tokens)
		)
	)
	if not self.current.id then
		self:init_current()
	end
	table.insert(self.current.messages, {
		role = role,
		message = message,
		time = os.time(),
		tokens = tokens,
	})
	Log.trace(
		string.format(
			"Inserting new prompt into history: %s",
			vim.inspect(self.current.messages[#self.current.messages])
		)
	)
	self.current.updatedAt = os.time()
	self:save()
end

function History:add_openai_params(openai_params)
	self.current.openai_params = openai_params
	self:save()
end

function History:get_current()
	return self.current
end

function History:load_from_file_path(file_path)
	local json = utils.decode_json_from_path(file_path)
	if json then
		self.current = json
		return true
	end
	return false
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
					entries = {
						name = entries.name,
						description = entries.description,
						keywords = entries.keywords,
						path = {
							full = file_path,
							base = vim.fn.fnamemodify(file_path, ":t"),
						},
					},
				})
			end
		end
		picker_cb(picker_entries)
	end

	utils.find_files_in_directory(self.data_dir, on_files_found, on_error)
end

return History
