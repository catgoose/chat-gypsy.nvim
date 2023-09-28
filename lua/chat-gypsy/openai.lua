local Log = require("chat-gypsy").Log

local OpenAI = {}
OpenAI.__index = OpenAI

function OpenAI:new()
	setmetatable(self, OpenAI)
	self.queue = require("chat-gypsy.queue"):new()
	self.request = require("chat-gypsy.request"):new()
	return self
end

function OpenAI:add_queue(action)
	if not action then
		return
	end
	local queue_callback = function(queue_complete)
		action(queue_complete)
	end
	self.queue:add(queue_callback)
end

function OpenAI:send(message, before_start, on_start, on_chunk, on_chunks_complete, on_chunk_error)
	Log.trace(string.format("adding request to queue: \nmessage: %s", message))
	before_start()
	local action = function(queue_complete)
		local on_complete = function(complete_chunks)
			Log.trace("request completed")
			on_chunks_complete(complete_chunks)
			queue_complete()
		end

		local on_error = function(chunk_error)
			on_chunk_error(chunk_error)
			queue_complete()
		end

		self.request:query(message, on_start, on_chunk, on_complete, on_error)
	end

	self:add_queue(action)
end

return OpenAI
