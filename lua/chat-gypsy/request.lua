local Log = require("chat-gypsy").Log
local Events = require("chat-gypsy").Events
local OpenAI = require("chat-gypsy.openai")
local opts = require("chat-gypsy").Config.get("opts")
local curl = require("plenary.curl")
local utils = require("chat-gypsy.utils")

Request = setmetatable({}, OpenAI)
Request.__index = Request
setmetatable(Request, {
	__index = OpenAI,
})

---@diagnostic disable-next-line: duplicate-set-field
function Request:init()
	self.chunks = {}
	self.error_chunks = {}
	self.content = ""
	self.handlers = {}
	self.join_content = function()
		self.content = table.concat(self.chunks, "")
	end
	self.on_assistant_response = function()
		self.content = table.concat(self.chunks, "")
		self.join_content()
		Log.trace("on_assistant_response: " .. self.content)
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
	self.reset = function()
		self.chunks = {}
		self.error_chunks = {}
		self.content = ""
	end

	self.extract_data = function(chunk, on_chunk)
		if not chunk then
			return
		end
		for line in chunk:gmatch("[^\n]+") do
			local data = string.gsub(line, "%s*data:%s*", "")
			local ok, json = pcall(vim.json.decode, data)
			if ok and json and json.choices and json.choices[1] then
				if json.choices[1].finish_reason == "stop" then
					return
				end
				if json.choices[1].delta and json.choices[1].delta.content then
					local content = json.choices[1].delta.content
					on_chunk(content)
					Events.pub("hook:request:chunk", content)
					table.insert(self.chunks, content)
				end
			end
		end
	end

	self.extract_error = function(chunk, on_error)
		table.insert(self.error_chunks, chunk .. "\n")
		on_error(self.error_chunks)
	end

	--  TODO: 2023-09-29 - add hook event for composing entries
	function Request:compose_entries(current_history, on_complete)
		local openai_params = utils.deepcopy(current_history.openai_params)
		table.insert(openai_params.messages, {
			role = "user",
			content = "Return json object for this chat",
		})
		openai_params.stream = false
		openai_params.messages[1] = {
			role = "system",
			content = "Important: ONLY RETURN THE OBJECT.  You will be reducing a openai chat to a json object.  The object's schema is {name: string, description: string, keywords: string[]}. The description should be limited to 80 characters.  Break compound words in keywords into multiple terms in lowercase.  Only return the object.",
		}
		Log.trace(string.format("Setting entries from openai response using %s", vim.inspect(openai_params)))
		--  TODO: 2023-10-02 - This is depending on an active request being shutdown
		--  first.  Could cause issues if the other request is not shut down
		local handler = curl.post({
			url = "https://api.openai.com/v1/chat/completions",
			headers = {
				content_type = "application/json",
				Authorization = "Bearer " .. opts.openai_key,
			},
			body = vim.json.encode(openai_params),
			callback = vim.schedule_wrap(function(response)
				if response.status == 200 then
					local response_json_ok, response_json = pcall(vim.json.decode, response.body)
					if response_json_ok and response_json then
						local content = response_json.choices[1].message.content
						local content_ok, content_json = pcall(vim.json.decode, content)
						if
							content_ok
							and content_json
							and content_json.name
							and content_json.description
							and content_json.keywords
							and #content_json.keywords > 0
						then
							current_history.entries = content_json
						end
					end
				else
					current_history.entries = {
						name = "Unknown Chat",
						description = "",
						keywords = { "unknown" },
					}
				end
				on_complete()
			end),
		})
		table.insert(self.handlers, handler)
	end

	self.completions = function(on_start, on_chunk, on_complete, on_error)
		on_start()
		local strategy = nil
		if opts.dev_opts.request.throw_error then
			on_error(opts.dev_opts.request.error)
		else
			local handler = curl.post({
				url = "https://api.openai.com/v1/chat/completions",
				raw = { "--no-buffer" },
				headers = {
					content_type = "application/json",
					Authorization = "Bearer " .. opts.openai_key,
				},
				body = vim.json.encode(self.openai_params),
				stream = function(_, chunk)
					if chunk and chunk ~= "" then
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
			handler:after_success(function()
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
			table.insert(self.handlers, handler)
		end
	end

	return self
end

function Request:shutdown_handlers()
	while #self.handlers > 0 do
		local handler = table.remove(self.handlers, 1)
		if handler and not handler.is_shutdown then
			Log.debug(string.format("shutting down plenary.curl handler: %s", handler))
			handler:shutdown()
		end
	end
end

---@diagnostic disable-next-line: duplicate-set-field
function Request:query(message, on_response_start, on_response_chunk, on_response_complete, on_response_error)
	self.on_user_prompt(message)

	local on_start = function()
		Log.trace("query: on_start")
		Events.pub("hook:request:start", message)
		self.reset()
		on_response_start()
	end

	local on_complete = function()
		Log.trace("query: on_complete")
		self.on_assistant_response()
		Log.trace("query: openai_params: " .. vim.inspect(self.openai_params))
		on_response_complete(self.chunks)
	end

	local on_error = function(err)
		Events.pub("hook:request:error", "completions", err)
		if type(err) == "table" then
			err = vim.inspect(err)
		end
		Log.error(string.format("query: on_error: %s", err))
		on_response_error(err)
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

	self.completions(on_start, on_chunk, on_complete, on_error)
end

return Request
