local Log = require("chat-gypsy").Log

local OpenAI = {}
OpenAI.__index = OpenAI

function OpenAI.new()
	local self = setmetatable({}, OpenAI)
	self.queue = require("chat-gypsy.queue").new()
	self.request = require("chat-gypsy.request").new()
	return self
end

function OpenAI:sendPrompt(lines, on_start, on_chunk, on_chunks_complete)
	if not lines then
		Log.warn("send_prompt: no message provided")
		return
	end
	on_chunks_complete = on_chunks_complete or function() end
	on_start = on_start or function() end
	local msg = table.concat(lines, "\n")

	Log.debug(string.format("adding request to queue: \nmessage: %s", msg))
	self.queue:add(function(on_request_complete)
		local on_complete = function(complete_chunks)
			Log.debug("request completed")
			on_chunks_complete(complete_chunks)
			on_request_complete()
		end

		self.request:query(msg, on_start, on_chunk, on_complete)
	end)
end

return OpenAI
