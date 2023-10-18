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
	self.session_id = -1
	self.sql = require("chat-gypsy.sql"):new()
	self:set_id(utils.generate_random_id(self.id_len))
	self:init()
	return self
end

function History:set_session_id(id)
	self.session_id = id
end

function History:set_id(id)
	self.history_id = id
	self.file = string.format("%s.json", self.history_id)
	self.json_path = string.format("%s/%s", self.data_dir, self.file)
end

function History:init_current()
	self.session_id = -1
	self.current = {
		id = self.history_id,
		createdAt = os.time(),
		updatedAt = os.time(),
		messages = {},
		openai_params = {},
		entries = {
			keywords = {},
		},
	}
end

function History:init()
	self:init_current()
	Path:new(self.data_dir):mkdir()

	self.sort_keywords = function()
		local keywords = self.current.entries.keywords
		table.sort(keywords, function(a, b)
			return a < b
		end)
		self.current.entries.keywords = keywords
	end
end

function History:compose_entries(request)
	local on_complete = function()
		Log.debug(string.format("Composed entries for History id %s", self.current.id))
		self.sort_keywords()
		if self.session_id > 0 then
			self.sql:session_summary(self.session_id, self.current.entries)
		end
		self:save()
		self:reset()
	end
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

function History:replay(message)
	table.insert(self.current.messages, message)
end

function History:add_message(content, role, tokens)
	if not role or not utils.check_roles(role) then
		return
	end
	tokens = utils.deepcopy(tokens)
	Log.trace(
		string.format(
			[[Adding to history: content "%s" of role "%s" with tokens %s]],
			content,
			role,
			vim.inspect(tokens)
		)
	)
	table.insert(self.current.messages, {
		role = role,
		content = content,
		time = os.time(),
		tokens = tokens,
	})
	Log.trace(
		string.format(
			"Inserting new prompt into history: %s",
			vim.inspect(self.current.messages[#self.current.messages])
		)
	)
	if self.session_id > 0 then
		local message = {
			role = role,
			content = content,
			time = os.time(),
			tokens = tokens[role],
			session = self.session_id,
		}
		self.sql:insert_message(message)
	end
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

function History:get_picker_entries(picker_cb, opts)
	local sessions = self.sql:get_sessions()
	local entries = {}
	for _, session in ipairs(sessions) do
		local sql_messages = self.sql:get_messages_for_session(session.id)
		local messages = {}
		local openai_params = {}
		local tokens = {
			system = 0,
			user = 0,
			assistant = 0,
			total = 0,
		}
		for _, message in ipairs(sql_messages) do
			tokens[message.role] = tokens[message.role] + message.tokens
			tokens.total = tokens.total + message.tokens
			local _tokens = utils.deepcopy(tokens)
			table.insert(messages, {
				role = message.role,
				tokens = _tokens,
				time = message.time,
				content = message.content,
			})
			table.insert(openai_params, {
				role = message.role,
				content = message.content,
			})
		end
		table.insert(entries, {
			id = session.id,
			name = session.name,
			description = session.description,
			keywords = utils.split_string(session.keywords, ","),
			messages = messages,
			openai_params = openai_params,
		})
	end

	picker_cb(entries, opts)
end

return History
