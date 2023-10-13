local Log = require("chat-gypsy").Log
local Config = require("chat-gypsy").Config
local History = require("chat-gypsy").History

local OpenAI = {}
OpenAI.__index = OpenAI

--  TODO: 2023-10-10 - Create picker for openai model
function OpenAI:new()
	setmetatable(self, OpenAI)
	self._ = {}
	self._.queue = require("chat-gypsy.queue"):new()
	self.save_history = function()
		History:add_openai_params(self._.openai_params)
	end
	self:init_openai()
	self:init_request()
	return self
end

function OpenAI:init_openai()
	self._.system_written = false
	self._.openai_params = Config.get("opts").openai_params
end

function OpenAI:set_openai_params(params)
	Log.debug(string.format("OpenAI:set_openai_params: params: %s", vim.inspect(params)))
	self._.openai_params = params
end

function OpenAI:send(
	lines,
	before_request,
	system_writer,
	on_chunk_stream_start,
	on_chunk,
	on_chunks_complete,
	on_chunk_error
)
	local message = table.concat(lines, "\n")
	before_request()
	if not self._.system_written and self._.openai_params.messages[1].role == "system" then
		system_writer(self._.openai_params.messages[1])
		self._.system_written = true
		self.save_history()
	end
	Log.trace(string.format("adding request to queue: \nmessage: %s", message))
	local action = function(queue_next)
		local on_stream_start = function()
			on_chunk_stream_start()
			self.save_history()
		end
		local on_complete = function(complete_chunks)
			Log.trace("request completed")
			on_chunks_complete(complete_chunks)
			self.save_history()
			queue_next()
		end

		local on_error = function(chunk_error)
			on_chunk_error(chunk_error)
			queue_next()
		end

		self:query(message, on_stream_start, on_chunk, on_complete, on_error)
	end

	self._.queue:add(action)
end

function OpenAI:query(...)
	Log.warn(string.format("OpenAI:query: not implemented: %s"), vim.inspect({ ... }))
end

return OpenAI
