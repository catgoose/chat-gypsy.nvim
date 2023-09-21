local Log = require("chat-gypsy").Log

local OpenAI = {}
OpenAI.__index = OpenAI

function OpenAI.new(events)
	local self = setmetatable({}, OpenAI)
	self.queue = require("chat-gypsy.queue").new()
	self.request = require("chat-gypsy.request").new(events)
	return self
end

--  TODO: 2023-09-20 - check if message is greater than max token count for
--  model
function OpenAI:send_prompt(message, on_start, on_chunk, on_chunks_complete)
	if not message then
		Log.warn("send_prompt: no message provided")
		return
	end

	Log.debug(string.format("adding request to queue: \nmessage: %s", message))
	self.queue:add(function(on_request_complete)
		local on_complete = function(complete_chunks)
			Log.debug("request completed")
			on_chunks_complete(complete_chunks)
			on_request_complete()
		end

		self.request:query(message, on_start, on_chunk, on_complete)
	end)
end

return OpenAI
