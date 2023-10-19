local Config = require("chat-gypsy").Config
local History = require("chat-gypsy").History

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
	return self
end

function OpenAI:init_openai()
	self._.system_written = false
	self._.openai_params = Config.get("opts").openai_params
	self._.session_id = -1
end

function OpenAI:restore(selection)
	selection = self.utils.deep_copy(selection)
	self.Log.trace(string.format("OpenAI:restore: current: %s", vim.inspect(selection)))
	self._.openai_params = selection.openai_params
	self._.system_written = true
	self._.session_id = selection.id
end

function OpenAI:summarize_chat(request)
	local action = function(queue_next)
		local on_start = function()
			local messages = History:get()
			for _, message in ipairs(messages) do
				message.tokens = message.tokens[message.role]
				message.session = self._.session_id
				self.sql:insert_message(message)
			end
			History:reset()
		end
		local on_complete = function(entries)
			self:init_session()
			self.sql:session_summary(self._.session_id, entries)
			self.Log.debug(string.format("Composed entries for session: %s", self._.session_id))
			self:init_openai()
			queue_next()
		end
		local on_error = function(err)
			self.Events.pub("hook:request:error", "summarize", err)
			if type(err) == "table" then
				err = vim.inspect(err)
			end
			self.Log.error(string.format("query: on_error: %s", err))
			queue_next()
		end
		local openai_params = self.utils.deep_copy(self._.openai_params)
		request:compose_entries(openai_params, on_start, on_complete, on_error)
	end
	self.queue:add(action)
end

function OpenAI:init_session()
	if self._.session_id < 0 then
		self._.session_id = self.sql:new_session(self._.openai_params) or -1
		if not self._.session_id == -1 then
			local err = "OpenAI:send: on_stream_start: Session could not be set"
			self.Log.error(err)
			error(err)
		end
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
	before_request()
	if not self._.system_written and self._.openai_params.messages[1].role == "system" then
		system_writer(self._.openai_params.messages[1])
		self._.system_written = true
	end
	self.Log.trace(string.format("adding request to queue: \nmessage: %s", table.concat(prompt_lines, "\n")))
	local action = function(queue_next)
		local on_stream_start = function(lines)
			on_chunk_stream_start(lines)
		end
		local on_complete = function(complete_chunks)
			self.Log.trace("request completed")
			on_chunks_complete(complete_chunks)
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

return OpenAI
