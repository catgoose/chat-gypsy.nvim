local Log = require("chat-gypsy").Log
local Config = require("chat-gypsy").Config
local History = require("chat-gypsy").History

local OpenAI = {}
OpenAI.__index = OpenAI

--  TODO: 2023-10-10 - Create picker for openai model
function OpenAI:new()
	setmetatable(self, OpenAI)
	self.sql = require("chat-gypsy.sql"):new()
	self._ = {}
	self._.queue = require("chat-gypsy.queue"):new()
	self:init_openai()
	self:init_request()
	self.session_id = -1
	return self
end

function OpenAI:init_openai()
	self._.system_written = false
	self._.openai_params = Config.get("opts").openai_params
	self:init_session()
end

function OpenAI:set_openai_params(params)
	Log.trace(string.format("OpenAI:set_openai_params: params: %s", vim.inspect(params)))
	self._.openai_params = params
	self._.system_written = true
end

function OpenAI:summarize_chat(request)
	local on_complete = function(entries)
		Log.debug("Composed entries for History")
		if self.session_id < 0 then
			self:init_session()
		end
		local messages = History:get()
		for _, message in ipairs(messages) do
			self.sql:insert_message(message, self.session_id)
		end
		self.sql:session_summary(self.session_id, entries)
		History:reset()
	end
	request:compose_entries(on_complete)
end

function OpenAI:init_session()
	self._.session_id = self.sql:new_session(self._.openai_params) or -1
	if not self._.session_id == -1 then
		local err = "OpenAI:send: on_stream_start: Session could not be set"
		Log.error(err)
		error(err)
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
	Log.trace(string.format("adding request to queue: \nmessage: %s", table.concat(prompt_lines, "\n")))
	local action = function(queue_next)
		local on_stream_start = function(lines)
			on_chunk_stream_start(lines)
		end
		local on_complete = function(complete_chunks)
			Log.trace("request completed")
			on_chunks_complete(complete_chunks)
			queue_next()
		end

		local on_error = function(chunk_error)
			on_chunk_error(chunk_error)
			queue_next()
		end

		self:query(prompt_lines, on_stream_start, on_chunk, on_complete, on_error)
	end

	self._.queue:add(action)
end

function OpenAI:query(...)
	Log.warn(string.format("OpenAI:query: not implemented: %s"), vim.inspect({ ... }))
end

return OpenAI
