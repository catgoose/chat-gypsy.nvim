local OpenAI = {}
OpenAI.__index = OpenAI

function OpenAI.new(log, queue, request)
	local self = setmetatable({}, OpenAI)
	self.queue = queue or require("chat-gypsy.queue").new()
	self.request = request or require("chat-gypsy.request").new(log)
	self.log = log
	return self
end

function OpenAI:sendPrompt(lines, on_start, on_chunk, on_chunks_complete)
	if not lines then
		self.log.warn("send_prompt: no message provided")
		return
	end
	on_chunks_complete = on_chunks_complete or function() end
	on_start = on_start or function() end
	local msg = table.concat(lines, "\n")

	self.log.debug(string.format("adding request to queue: \nmessage: %s", msg))
	self.queue:add(function(on_request_complete)
		local on_complete = function(complete_chunks)
			self.log.debug("request completed")
			on_chunks_complete(complete_chunks)
			on_request_complete()
		end

		self.request:query(msg, on_start, on_chunk, on_complete)
	end)
end

return OpenAI
