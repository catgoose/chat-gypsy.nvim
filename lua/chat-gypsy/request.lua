---@diagnostic disable: undefined-field
local config = require("chat-gypsy.config")
local opts = config.opts
local events = require("chat-gypsy").events
local Log = require("chat-gypsy").Log

local Request = {}
Request.__index = Request

function Request.new()
	local self = setmetatable({}, Request)
	self.chunks = {}
	self.content = ""
	self.openai_params = opts.openai_params
	self.join_content = function()
		self.content = table.concat(self.chunks, "")
	end
	self.on_assistant_response = function()
		self.content = table.concat(self.chunks, "")
		self.join_content()
		Log.debug("on_user_prompt: " .. self.content)
		table.insert(self.openai_params.messages, {
			role = "assistant",
			content = self.content,
		})
	end
	self.on_user_prompt = function(content)
		self.content = content
		Log.debug("on_user_prompt: " .. self.content)
		table.insert(self.openai_params.messages, {
			role = "user",
			content = self.content,
		})
	end
	self.on_new_request = function()
		self.chunks = {}
		self.raw_chunks = {}
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
			events:pub("hook:request:chunk", path)
			table.insert(self.chunks, path)
			::continue::
		end
	end

	self.exec = function(cmd, args, on_start, on_stdout_chunk, on_complete, on_error)
		local stdout = vim.loop.new_pipe()
		local stderr = vim.loop.new_pipe()
		local stderr_chunks = {}
		local function on_stdout_read(err, chunk)
			if err then
				on_error(err)
				return
			end
			if chunk then
				vim.schedule(function()
					on_stdout_chunk(chunk)
				end)
			end
		end

		local function on_stderr_read(err, chunk)
			if err then
				on_error(err)
			end
			if chunk then
				table.insert(stderr_chunks, chunk)
			end
		end

		on_start()

		local handle, handle_err
		handle, handle_err = vim.loop.spawn(cmd, {
			args = args,
			stdio = { nil, stdout, stderr },
		}, function(exit_code, _)
			stdout:close()
			stderr:close()
			handle:close()

			vim.schedule(function()
				if exit_code ~= 0 then
					on_error(vim.trim(table.concat(stderr_chunks, "")))
				else
					on_complete()
				end
			end)
		end)

		if not handle then
			on_error(handle_err)
		else
			stdout:read_start(on_stdout_read)
			stderr:read_start(on_stderr_read)
		end
	end
	return self
end

function Request:query(content, on_response_start, on_response_chunk, on_response_complete)
	self.on_user_prompt(content)

	local on_start = function()
		events:pub("hook:request:start", content)
		Log.debug("query: on_start")
		on_response_start()
	end

	local on_stdout_chunk = function(chunk)
		self.extract_chunk(chunk, on_response_chunk)
	end

	local on_complete = function()
		Log.debug("query: on_complete")
		self.on_assistant_response()
		Log.debug("query: openai_params: " .. vim.inspect(self.openai_params))
		on_response_complete(self.chunks)
	end

	local on_error = function(err)
		Log.warn(string.format("query: on_error: %s", err))
	end

	self.on_new_request()
	self.exec("curl", {
		"--silent",
		"--show-error",
		"--no-buffer",
		"https://api.openai.com/v1/chat/completions",
		"-H",
		"Content-Type: application/json",
		"-H",
		"Authorization: Bearer " .. opts.openai_key,
		"-d",
		vim.json.encode(self.openai_params),
	}, on_start, on_stdout_chunk, on_complete, on_error)
end

return Request
