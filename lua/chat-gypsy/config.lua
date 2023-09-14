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
}

Config.opts = {
	openai_key = os.getenv("OPENAI_API_KEY"),
	openai_params = {
		model = "gpt-3.5-turbo",
		temperature = 0.7,
		stream = true,
		messages = {
			{
				role = "system",
				content = "You are gypsy, a chatbot that can talk to anyone.",
			},
		},
	},
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
	dev_opts = {
		prompt = {
			user_prompt = "",
			enabled = false,
		},
	},
}

Config.dev = Config.opts.dev_opts

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
	Config.cfg.log_level = vim.tbl_contains(log_levels, opts.log_level) and opts.log_level or default_log_level
	Config.opts = opts

	if Config.opts.dev then
		Config.cfg.dev = true
		Config.dev = vim.tbl_deep_extend("force", Config.dev, Config.opts.dev_opts)
		Config.dev.prompt.message = {}
		for word in Config.dev.prompt.user_prompt:gmatch("[^\n]+") do
			table.insert(Config.dev.prompt.message, word)
		end
	end

	-- event_hooks()
end

return Config
