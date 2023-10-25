local Config = require("chat-gypsy").Config
local opts = Config.get("opts")
local History = require("chat-gypsy").History
local validate = require("chat-gypsy.validate")

local OpenAI = {}
OpenAI.__index = OpenAI

--  TODO: 2023-10-10 - Create picker for openai model
function OpenAI:new()
	setmetatable(self, OpenAI)
	self.sql = require("chat-gypsy.sql"):new()
	self.utils = require("chat-gypsy.utils")
	self.Events = require("chat-gypsy").Events
	self.Log = require("chat-gypsy").Log
	self._ = {}
	self.queue = require("chat-gypsy.queue"):new()
	self:init_openai()
	self:init_request()
	self.validate = function()
		return validate.openai_key(opts.openai.openai_key)
	end
	return self
end

function OpenAI:init_openai()
	self._.system_written = false
	self._.openai_params = Config.get("opts").openai.openai_params
	self._.session_id = nil
end

function OpenAI:restore(selection)
	selection = self.utils.deep_copy(selection)
	self.Log.trace(string.format("OpenAI:restore: current: %s", vim.inspect(selection)))
	self._.openai_params = selection.openai_params
	self._.system_written = true
	self._.session_id = selection.id
end

function OpenAI:init_session()
	if not self._.session_id then
		local status = self.sql:new_session(self._.openai_params)
		if status.success then
			self._.session_id = status.data
		else
			local err = "OpenAI:send: on_stream_start: Session could not be set"
			self.Log.error(err)
			error(err)
		end
	end
end

function OpenAI:summarize_chat(request)
	if not self.validate() then
		return
	end
	local on_error = function(err)
		self.Events.pub("hook:request:error", "summarize", err)
		if type(err) == "table" then
			err = vim.inspect(err)
		end
		self.Log.error(string.format("query: on_error: %s", err))
	end
	local on_complete = function(entries)
		local status = self.sql:session_summary(self._.session_id, entries)
		if status.success then
			self.Log.debug(string.format("Composed entries for session: %s", self._.session_id))
			self:init_openai()
		else
			on_error(status.err)
		end
	end

	self:init_session()
	local do_compose = false
	local messages = History:get()
	for _, message in ipairs(messages) do
		message.tokens = message.tokens[message.role]
		message.session = self._.session_id
		local status = self.sql:insert_message(message)
		if not status.success then
			on_error(string.format("Could not insert message: %s\n\n error: %s", vim.inspect(message), status.err))
			do_compose = false
			break
		end
		do_compose = true
	end

	if do_compose then
		History:reset()
		local openai_params = self.utils.deep_copy(self._.openai_params)
		request:compose_entries(openai_params, on_complete, on_error)
	end
end

function OpenAI:send(
	prompt_lines,
	before_request,
	system_writer,
	on_chunk_stream_start,
	on_chunk,
	on_chunks_complete,
	on_chunk_error
)
	if not self.validate() then
		return
	end
	before_request()
	if not self._.system_written and self._.openai_params.messages[1].role == "system" then
		system_writer(self._.openai_params.messages[1], self._.openai_params.model)
		self._.system_written = true
	end
	self.Log.trace(string.format("adding request to queue: \nmessage: %s", table.concat(prompt_lines, "\n")))
	local action = function(queue_next)
		local on_stream_start = function(lines)
			on_chunk_stream_start(lines, self._.openai_params.model)
		end
		local on_complete = function(complete_chunks)
			self.Log.trace("request completed")
			on_chunks_complete(complete_chunks, self._.openai_params.model)
			queue_next()
		end

		local on_error = function(chunk_error)
			on_chunk_error(chunk_error)
			queue_next()
		end

		self:query(prompt_lines, on_stream_start, on_chunk, on_complete, on_error)
	end

	self.queue:add(action)
end

function OpenAI:query(...)
	self.Log.warn(string.format("OpenAI:query: not implemented: %s"), vim.inspect({ ... }))
end

function OpenAI:init_request(...)
	self.Log.warn(string.format("OpenAI:init_request: not implemented: %s"), vim.inspect({ ... }))
end

return OpenAI
