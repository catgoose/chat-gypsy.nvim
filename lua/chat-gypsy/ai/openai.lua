---@class OpenAIParamsMessage
---@field role Role
---@field content string

---@class OpenAIParams
---@field model string
---@field temperature number
---@field messages OpenAIParamsMessage[]
---@field stream boolean

---@class OpenAIState
---@field openai_params OpenAIParams
---@field session_id number
---@field system_written boolean
---@field injected_prompt boolean

---@class OpenAI
---@field public new fun(): OpenAI
---@field public restore fun(selection: OpenAIState)
---@field public inject_prompt fun(prompt: string)
---@field private sql Sql
---@field private utils Utils
---@field private Events Events
---@field private Log Logger
---@field private _ OpenAIState
---@field private queue FuncQueue
---@field private validate fun(): boolean
---@field private set_model fun(model: string)
---@field private init_openai fun()
---@field private init_session fun()
---@field private init_child fun()
---@field private summarize_chat fun(request: Request)
---@field private send fun(prompt_lines: string[], before_request: fun(), system_writer: fun(message: OpenAIParamsMessage, model: string), on_chunk_stream_start: fun(lines: string[], model: string), on_chunk: fun(chunk: string, model: string), on_chunks_complete: fun(complete_chunks: string[], model: string), on_chunk_error: fun(chunk_error: string))
---@field private query fun(prompt_lines: string[], on_stream_start: fun(lines: string[]), on_chunk: fun(chunk: string), on_complete: fun(complete_chunks: string[]), on_error: fun(chunk_error: string))

local Config = require("chat-gypsy").Config
local opts = Config.get("opts")
local History = require("chat-gypsy").History
local Validate = require("chat-gypsy.config.validate")
local Models = require("chat-gypsy.ai.models")
local Utils = require("chat-gypsy.utils")

local OpenAI = {}
OpenAI.__index = OpenAI

function OpenAI:new()
	setmetatable(self, OpenAI)
	self.sql = require("chat-gypsy.db.sql"):new()
	self.utils = require("chat-gypsy.utils")
	self.Events = require("chat-gypsy").Events
	self.Log = require("chat-gypsy").Log
	self._ = {}
	self.queue = require("chat-gypsy.core.queue"):new()
	self.validate = function()
		return Validate.openai_key(opts.openai.openai_key)
	end

	self.set_model = function(model)
		self._.openai_params.model = model
	end
	self.init_openai = function()
		self._.system_written = false
		self._.injected_prompt = false
		self._.openai_params = Config.get("opts").openai.openai_params
		self.set_model(Models.selected)
		self._.session_id = nil
	end

	self.init_session = function()
		if not self._.session_id then
			local status = self.sql:new_session(self._.openai_params)
			if status.success then
				self._.session_id = status.data
			else
				local err = "OpenAI:send: on_stream_start: Session could not be set"
				self.Log.error(err)
				error(err)
			end
		end
	end

	self.Events.sub("hook:models:set", function(model)
		self.set_model(model)
	end)

	self.init_openai()
	if OpenAI.__index.init_child then
		self:init_child()
	end

	return self
end

function OpenAI:restore(selection)
	selection = self.utils.deep_copy(selection)
	self.Log.trace(string.format("OpenAI:restore: current: %s", vim.inspect(selection)))
	self._.openai_params = selection.openai_params
	self._.system_written = true
	self._.session_id = selection.id
end

function OpenAI:summarize_chat(request)
	if not self.validate() then
		return
	end
	local on_error = function(err)
		self.Events.pub("hook:request:error", "summarize", err)
		if type(err) == "table" then
			err = vim.inspect(err)
		end
		self.Log.error(string.format("query: on_error: %s", err))
	end
	local on_complete = function(entries)
		local status = self.sql:session_summary(self._.session_id, entries)
		if status.success then
			self.Log.trace(string.format("Composed entries for session: %s", self._.session_id))
			self.init_openai()
		else
			on_error(status.err)
		end
	end

	self.init_session()
	local do_compose = false
	local messages = History:get()
	for _, message in ipairs(messages) do
		message.tokens = message.tokens[message.role]
		message.session = self._.session_id
		local status = self.sql:insert_message(message)
		if not status.success then
			on_error(string.format("Could not insert message: %s\n\n error: %s", vim.inspect(message), status.err))
			do_compose = false
			break
		end
		do_compose = true
	end

	if do_compose then
		History:reset()
		local openai_params = self.utils.deep_copy(self._.openai_params)
		request:compose_entries(openai_params, on_complete, on_error)
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
	if not self.validate() then
		return
	end
	local model = self._.openai_params.model
	before_request()
	if not self._.system_written and self._.openai_params.messages[1].role == "system" then
		local message = Utils.deep_copy(self._.openai_params.messages[1])
		if self._.injected_prompt then
			message.content = Utils.split_string(message.content, "\n", false)
		end
		system_writer(message, model)
		self._.system_written = true
	end
	self.Log.trace(string.format("adding request to queue: \nmessage: %s", table.concat(prompt_lines, "\n")))
	local action = function(queue_next)
		local on_stream_start = function(lines)
			on_chunk_stream_start(lines, model)
		end
		local on_complete = function(complete_chunks)
			self.Log.trace("request completed")
			on_chunks_complete(complete_chunks, model)
			queue_next()
		end

		local on_error = function(chunk_error)
			on_chunk_error(chunk_error)
			queue_next()
		end

		self:query(prompt_lines, on_stream_start, on_chunk, on_complete, on_error)
	end

	self.queue:add(action)
end

function OpenAI:inject_prompt(prompt)
	self._.openai_params.messages[1].content = table.concat(prompt, "\n")
	self._.injected_prompt = true
end

function OpenAI:query(...) end

function OpenAI:init_child(...) end

return OpenAI
