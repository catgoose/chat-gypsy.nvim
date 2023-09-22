---@diagnostic disable: undefined-field
local config = require("chat-gypsy.config")
local opts = config.opts
local Log = require("chat-gypsy").Log
local utils = require("chat-gypsy.utils")
local Events = require("chat-gypsy").Events
local curl = require("plenary.curl")

local Request = {}
Request.__index = Request

function Request.new(events)
	local self = setmetatable({}, Request)
	self.events = events
	self.chunks = {}
	self.error_chunks = {}
	self.content = ""
	self.handler = nil
	self.openai_params = utils.deepcopy(opts.openai_params)
	self.join_content = function()
		self.content = table.concat(self.chunks, "")
	end
	self.on_assistant_response = function()
		self.content = table.concat(self.chunks, "")
		self.join_content()
		Log.trace("on_user_prompt: " .. self.content)
		--  TODO: 2023-09-17 - create chat module to handle chat history,
		--  saving chats to disk, and providing an interface for telescope
		--  picker to choose from previous chats
		table.insert(self.openai_params.messages, {
			role = "assistant",
			content = self.content,
		})
	end
	self.on_user_prompt = function(content)
		self.content = content
		Log.trace("on_user_prompt: " .. self.content)
		table.insert(self.openai_params.messages, {
			role = "user",
			content = self.content,
		})
	end
	self.query_reset = function()
		self.chunks = {}
		self.error_chunks = {}
		self.content = ""
		if self.handler ~= nil then
			Log.trace("shutting down plenary.curl handler")
			self.handler:shutdown()
			self.handler = nil
		end
	end

	self.extract_data = function(chunk, on_chunk)
		if not chunk then
			return
		end
		for line in chunk:gmatch("[^\n]+") do
			local data = string.gsub(line, "%s*data:%s*", "")
			local ok, json = pcall(vim.json.decode, data)
			if not ok then
				return
			end
			local path = json.choices
			if not path then
				return
			end
			path = path[1]
			if not path then
				return
			end
			path = path.delta
			if not path then
				return
			end
			path = path.content
			if not path then
				return
			end
			if #self.chunks == 0 and path == "" then
				return
			end
			on_chunk(path)
			Events:pub("hook:request:chunk", path)
			table.insert(self.chunks, path)
		end
	end

	self.extract_error = function(chunk)
		table.insert(self.error_chunks, chunk .. "\n")
	end

	self.completions = function(on_start, on_chunk, on_complete, on_error)
		on_start()
		local strategy = nil
		self.handler = curl.post({
			url = "https://api.openai.com/v1/chat/completions",
			raw = { "--no-buffer" },
			headers = {
				content_type = "application/json",
				Authorization = "Bearer " .. opts.openai_key,
			},
			body = vim.json.encode(self.openai_params),
			stream = function(_, chunk)
				if chunk ~= "" then
					vim.schedule(function()
						if not strategy then
							if string.match(chunk, "data:") then
								strategy = "data"
							else
								strategy = "error"
							end
						end
						on_chunk(chunk, strategy)
					end)
				end
			end,
			on_error = on_error,
		})
		self.handler:after_success(function()
			if #self.error_chunks > 0 then
				local error = table.concat(self.error_chunks, "")
				local ok, json = pcall(vim.json.decode, error)
				if ok then
					on_error(json)
				else
					on_error(self.error_chunks)
				end
			else
				vim.schedule(function()
					on_complete()
				end)
			end
		end)
	end

	self.events:sub("layout:unmount", function()
		self:query_reset()
	end)

	return self
end

function Request:query(content, on_response_start, on_response_chunk, on_response_complete)
	self.on_user_prompt(content)

	local on_start = function()
		Log.trace("query: on_start")
		Events:pub("hook:request:start", content)
		on_response_start()
	end

	local on_complete = function()
		Log.trace("query: on_complete")
		self.on_assistant_response()
		Log.debug("query: openai_params: " .. vim.inspect(self.openai_params))
		on_response_complete(self.chunks)
	end

	local on_error = function(err)
		Events:pub("hook:request:error", "completions", err)
		Events:pub("request:error", err)
		if type(err) == "table" then
			err = vim.inspect(err)
		end
		Log.error(string.format("query: on_error: %s", err))
	end

	local on_chunk = function(chunk, strategy)
		if not strategy then
			return
		elseif strategy == "data" then
			self.extract_data(chunk, on_response_chunk)
		elseif strategy == "error" then
			self.extract_error(chunk, on_error)
		end
	end

	self.query_reset()
	self.completions(on_start, on_chunk, on_complete, on_error)
end

return Request
