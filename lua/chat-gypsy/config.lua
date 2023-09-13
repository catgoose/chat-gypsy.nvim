local log_levels = { "trace", "debug", "info", "warn", "error", "fatal" }
local default_log_level = "warn"
-- local events = require("chat-gypsy").events

local Config = {}
Config.cfg = {
	plugin = "gypsy",
	log_level = default_log_level,
	dev = false,
	ui = {
		prompt_height = 5,
		max_lines = 6,
	},
	api = {
		queue_sleep_ms = 100,
	},
	openai_params = {
		model = "gpt-3.5-turbo",
		temperature = 0.7,
		stream = true,
		messages = { { role = "user", content = "" } },
	},
}

Config.opts = {
	openai_key = os.getenv("OPENAI_API_KEY"),
	ui = {
		prompt = {
			start_insert = true,
		},
	},
	hooks = {
		request = {
			start = function(--[[content]]) end,
			chunk = function(--[[chunk]]) end,
			complete = function(--[[response]]) end,
		},
	},
}

local sentence =
	[[Write 3 haiku.  Use a numbered list.  Numbers should be on their own line.  Insert a period after each number.]]
local message = {}
for word in sentence:gmatch("%w+") do
	table.insert(message, word)
end

Config.dev = {
	prompt = {
		message = message,
		enabled = true,
	},
}

-- local event_hooks = function()
-- 	local request = Config.opts.hooks.request
-- 	for hook, _ in pairs(request) do
-- 		events:sub("hook:request:" .. hook, request[hook])
-- 	end
-- end

Config.init = function(opts)
	opts = opts or {}
	opts = vim.tbl_deep_extend("force", Config.opts, opts)
	if not opts.openai_key then
		local err_msg = string.format("opts:new: invalid opts: missing openai_key\nopts: %s", vim.inspect(opts))
		error(err_msg)
	end
	if opts.dev then
		Config.cfg.dev = true
	end
	Config.cfg.log_level = vim.tbl_contains(log_levels, opts.log_level) and opts.log_level or default_log_level
	Config.opts = opts

	-- event_hooks()
end

return Config
