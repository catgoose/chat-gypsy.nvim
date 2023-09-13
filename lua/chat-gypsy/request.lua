---@diagnostic disable: undefined-field
local config = require("chat-gypsy.config")
local cfg = config.cfg
local opts = config.opts

local raw_chunks = {}
local chunks = {}

local Request = {}
Request.__index = Request

function Request.new(log)
	local self = setmetatable({}, Request)
	self.log = log
	return self
end

local exec = function(cmd, args, on_start, on_stdout_chunk, on_complete, on_error)
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

local extract_chunk = function(chunk, on_chunk)
	for line in chunk:gmatch("[^\n]+") do
		local raw_json = string.gsub(line, "^data: ", "")

		table.insert(raw_chunks, raw_json)
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
		if #chunks == 0 and path == "" then
			goto continue
		end

		on_chunk(path)
		-- events:pub("hook:request:chunk", path)
		table.insert(chunks, path)
		::continue::
	end
end

function Request:query(content, on_response_start, on_response_chunk, on_response_complete)
	local openai_params = cfg.openai_params
	openai_params.messages[1].content = content

	local on_start = function()
		self.log.debug("query: on_start")
		-- events:pub("hook:request:start", content)
		on_response_start()
	end

	local on_stdout_chunk = function(chunk)
		extract_chunk(chunk, on_response_chunk)
	end

	local on_complete = function()
		self.log.debug("query: on_complete")
		on_response_complete(chunks)
	end

	local on_error = function(err)
		self.log.warn(string.format("query: on_error: %s", err))
	end

	chunks = {}
	raw_chunks = {}
	exec("curl", {
		"--silent",
		"--show-error",
		"--no-buffer",
		"https://api.openai.com/v1/chat/completions",
		"-H",
		"Content-Type: application/json",
		"-H",
		"Authorization: Bearer " .. opts.openai_key,
		"-d",
		vim.json.encode(openai_params),
	}, on_start, on_stdout_chunk, on_complete, on_error)
end

return Request
