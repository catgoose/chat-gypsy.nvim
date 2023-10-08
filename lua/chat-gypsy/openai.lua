local Log = require("chat-gypsy").Log
local opts = require("chat-gypsy").Config.get("opts")
local History = require("chat-gypsy").History

local OpenAI = {}
OpenAI.__index = OpenAI

function OpenAI:new()
	setmetatable(self, OpenAI)
	self.openai_params = opts.openai_params
	self.queue = require("chat-gypsy.queue"):new()
	self:init()
	return self
end

function OpenAI:send(
	lines,
	before_send,
	before_request_start,
	on_stream_start,
	on_chunk,
	on_chunks_complete,
	on_chunk_error
)
	local message = table.concat(lines, "\n")
	Log.trace(string.format("adding request to queue: \nmessage: %s", message))
	before_send()
	local action = function(queue_next)
		local before_start = function()
			before_request_start()
			History:add_openai_params(self.openai_params)
		end
		local on_complete = function(complete_chunks)
			Log.trace("request completed")
			on_chunks_complete(complete_chunks)
			History:add_openai_params(self.openai_params)
			queue_next()
		end

		local on_error = function(chunk_error)
			on_chunk_error(chunk_error)
			queue_next()
		end

		self:query(message, before_start, on_stream_start, on_chunk, on_complete, on_error)
	end

	self.queue:add(action)
end

function OpenAI:init()
	Log.warn("OpenAI:layout_init: not implemented")
end

function OpenAI:query(...)
	Log.warn(string.format("OpenAI:query: not implemented: %s"), vim.inspect({ ... }))
end

return OpenAI
