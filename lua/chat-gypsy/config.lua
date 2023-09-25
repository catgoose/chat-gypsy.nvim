local log_levels = { "trace", "debug", "info", "warn", "error", "fatal" }
local default_log_level = "warn"
local Events = require("chat-gypsy").Events

local Config = {}

Config.openai_models = {
	{
		model = "gpt-3.5-turbo",
		max_tokens = 4097,
		priority = 1,
	},
	{
		model = "gpt-3.5-turbo-16k",
		max_tokens = 16385,
		priority = 2,
	},
	{
		model = "gpt-4",
		max_tokens = 8192,
		priority = 3,
	},
	{
		model = "gpt-4-32k",
		max_tokens = 32768,
		priority = 4,
	},
}

Config.symbols = {
	horiz = "━",
	left_arrow = "◀",
	right_arrow = "▶",
}

Config.plugin_cfg = {
	name = "gypsy",
	log_level = default_log_level,
	dev = false,
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
		config = {
			zindex = 50,
			border = {
				style = "rounded",
				text = {
					top_align = "left",
				},
				padding = {
					top = 1,
					left = 2,
					right = 2,
				},
			},
			win_options = {
				cursorline = false,
				winblend = 0,
				winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
				wrap = true,
				fillchars = "lastline: ",
			},
		},
		layout = {
			left = {
				prompt_height = 8,
				size = {
					width = "35%",
					height = "100%",
				},
				position = {
					row = "0%",
					col = "0%",
				},
			},
			right = {
				prompt_height = 8,
				size = {
					width = "35%",
					height = "100%",
				},
				position = {
					row = "0%",
					col = "100%",
				},
			},
			float = {
				prompt_height = 5,
				prompt_max_lines = 6,
				position = {
					row = "20%",
					col = "50%",
				},
				size = {
					width = "70%",
					height = "70%",
				},
			},
		},
	},
	hooks = {
		request = {
			start = function(--[[content]]) end,
			chunk = function(--[[chunk]]) end,
			complete = function(--[[response]]) end,
			error = function(--[[source, error_tbl]]) end,
		},
		models = {
			get = function(--[[models]]) end,
			error = function(--[[source, error_tbl]]) end,
		},
	},
	dev_opts = {
		prompt = {
			user_prompt = "",
			enabled = false,
		},
		request = {
			throw_error = false,
			error = "You didn't provide an API key. You need to provide your API key in an Authorization header using Bearer auth (i.e. Authorization: Bearer YOUR_KEY), or as the password field (with blank username) if you're accessing the API from your browser and are prompted for a username and password. You can obtain an API key from https://platform.openai.com/account/api-keys.",
		},
	},
}

Config.dev = Config.opts.dev_opts

local init_event_hooks = function()
	local types = Config.opts.hooks
	for type, _ in pairs(types) do
		for hook, _ in pairs(types[type]) do
			Events.sub("hook:" .. type .. ":" .. hook, types[type][hook])
		end
	end
end

Config.init = function(opts)
	opts = opts or {}
	opts = vim.tbl_deep_extend("force", Config.opts, opts)
	if not opts.openai_key then
		local err_msg = string.format("opts:new: invalid opts: missing openai_key\nopts: %s", vim.inspect(opts))
		error(err_msg)
	end
	Config.plugin_cfg.log_level = vim.tbl_contains(log_levels, opts.log_level) and opts.log_level or default_log_level
	Config.opts = opts

	Config.plugin_cfg.dev = Config.plugin_cfg.dev or Config.opts.dev
	if Config.plugin_cfg.dev then
		Config.dev = vim.tbl_deep_extend("force", Config.dev, Config.opts.dev_opts)
		Config.dev.prompt.message = {}
		for word in Config.dev.prompt.user_prompt:gmatch("[^\n]+") do
			table.insert(Config.dev.prompt.message, word)
		end
	end

	init_event_hooks()
end

return Config
