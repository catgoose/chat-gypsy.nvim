local Log = require("chat-gypsy").Log

local OpenAI = {}
OpenAI.__index = OpenAI

function OpenAI:new()
	local events = require("chat-gypsy.events"):new()
	setmetatable(self, OpenAI)
	-- self.events = events
	self.queue = require("chat-gypsy.queue").new()
	self.request = require("chat-gypsy.request").new(events)
	return self
end

function OpenAI:initializeEvents()
	local ancestor = self.parent
	while ancestor ~= nil do
		if ancestor.events then
			self.events = ancestor.events
			break
		end
		ancestor = ancestor.parent
	end

	self.events = self.events or require("chat-gypsy.events"):new()
end

function OpenAI:send_prompt(message, before_start, on_start, on_chunk, on_chunks_complete, on_error)
	if not message then
		Log.warn("send_prompt: no message provided")
		return
	end

	Log.trace(string.format("adding request to queue: \nmessage: %s", message))
	before_start()
	self.queue:add(function(on_request_complete)
		local on_complete = function(complete_chunks)
			Log.trace("request completed")
			on_chunks_complete(complete_chunks)
			on_request_complete()
		end

		self.request:query(message, on_start, on_chunk, on_complete, on_error)
	end)
end

return OpenAI
