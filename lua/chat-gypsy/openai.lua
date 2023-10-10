local Log = require("chat-gypsy").Log
local opts = require("chat-gypsy").Config.get("opts")
local History = require("chat-gypsy").History

local OpenAI = {}
OpenAI.__index = OpenAI

--  TODO: 2023-10-10 - Create picker for openai model
function OpenAI:new()
	setmetatable(self, OpenAI)
	self.openai_params = opts.openai_params
	self.queue = require("chat-gypsy.queue"):new()
	self._ = {
		system_rendered = false,
	}
	self.save_history = function()
		History:add_openai_params(self.openai_params)
	end
	self:init()
	return self
end

function OpenAI:send(
	lines,
	before_request,
	system_render,
	on_stream_start,
	on_chunk,
	on_chunks_complete,
	on_chunk_error
)
	local message = table.concat(lines, "\n")
	before_request()
	if not self._.system_rendered and self.openai_params.messages[1].role == "system" then
		system_render(self.openai_params.messages[1])
		self._.system_rendered = true
		self.save_history()
	end
	Log.trace(string.format("adding request to queue: \nmessage: %s", message))
	local action = function(queue_next)
		local _on_stream_start = function()
			on_stream_start()
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

		self:query(message, _on_stream_start, on_chunk, on_complete, on_error)
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
