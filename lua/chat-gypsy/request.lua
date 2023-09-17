---@diagnostic disable: undefined-field
local config = require("chat-gypsy.config")
local opts = config.opts
local Log = require("chat-gypsy").Log
local utils = require("chat-gypsy.utils")
local Events = require("chat-gypsy").Events
local curl = require("plenary.curl")

local Request = {}
Request.__index = Request

function Request.new()
	local self = setmetatable({}, Request)
	self.chunks = {}
	self.content = ""
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
	self.on_new_request = function()
		self.chunks = {}
		self.raw_chunks = {}
		self.handler = nil
		self.content = ""
	end

	self.extract_chunk = function(chunk, on_chunk)
		for line in chunk:gmatch("[^\n]+") do
			local raw_json = string.gsub(line, "^data: ", "")

			table.insert(self.raw_chunks, raw_json)
			local ok, path = pcall(vim.json.decode, raw_json)
			if not ok then
				goto continue
			end

			path = path.choices
			if path == nil then
				goto continue
			end
			path = path[1]
			if path == nil then
				goto continue
			end
			path = path.delta
			if path == nil then
				goto continue
			end
			path = path.content
			if path == nil then
				goto continue
			end
			if #self.chunks == 0 and path == "" then
				goto continue
			end

			on_chunk(path)
			Events:pub("hook:request:chunk", path)
			table.insert(self.chunks, path)
			::continue::
		end
	end

	self.post = function(on_start, on_chunk, on_complete, on_error)
		on_start()
		--  TODO: 2023-09-17 - register self.handler with event service to
		--  call self.handler:shutdown() on exit
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
					if chunk:match("^data: %[DONE%]") then
						vim.schedule(function()
							on_complete()
						end)
					else
						vim.schedule(function()
							on_chunk(chunk)
						end)
					end
				else
					on_error("chunk is empty")
				end
			end,
			on_error = on_error,
		})
	end

	return self
end

function Request:query(content, on_response_start, on_response_chunk, on_response_complete)
	self.on_user_prompt(content)

	local on_start = function()
		Log.trace("query: on_start")
		Events:pub("hook:request:start", content)
		on_response_start()
	end

	local on_chunk = function(chunk)
		self.extract_chunk(chunk, on_response_chunk)
	end

	local on_complete = function()
		Log.trace("query: on_complete")
		self.on_assistant_response()
		Log.debug("query: openai_params: " .. vim.inspect(self.openai_params))
		on_response_complete(self.chunks)
	end

	local on_error = function(err)
		Log.error(string.format("query: on_error: %s", err))
	end

	self.on_new_request()
	self.post(on_start, on_chunk, on_complete, on_error)
end

return Request
