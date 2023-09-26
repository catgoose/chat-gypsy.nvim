local Log = require("chat-gypsy").Log

local OpenAI = {}
OpenAI.__index = OpenAI

function OpenAI:new()
	setmetatable(self, OpenAI)
	self.queue = require("chat-gypsy.queue"):new()
	return self
end

function OpenAI:send(message, before_start, on_start, on_chunk, on_chunks_complete, on_error)
	Log.trace(string.format("adding request to queue: \nmessage: %s", message))
	before_start()
	self.queue:add(function(on_request_complete)
		local on_complete = function(complete_chunks)
			Log.trace("request completed")
			on_chunks_complete(complete_chunks)
			on_request_complete()
		end

		local request = require("chat-gypsy.request"):new()
		request:query(message, on_start, on_chunk, on_complete, on_error)
	end)
end

return OpenAI
