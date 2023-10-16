local log_levels = { "trace", "debug", "info", "warn", "error", "fatal" }
local default_log_level = "warn"
local Events = require("chat-gypsy").Events
local utils = require("chat-gypsy.utils")

--  TODO: 2023-09-30 - validate config with vim.validate
--  TODO: 2023-09-30 - Add @type and @param for project

local Config = {}

local _openai_models = {
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

local _symbols = {
	horiz = "━",
	space = " ",
	hash = "#",
	left_arrow = "◀",
	right_arrow = "▶",
}

local _plugin_opts = {
	name = "chat-gypsy",
	log_level = default_log_level,
	dev = false,
}

local _opts = {
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
		highlight = {
			role = {
				error = "ErrorMsg",
				system = "LineNr",
				user = "Statement",
				assistant = "Boolean",
			},
			tokens = "LineNr",
			error_message = "Exception",
			heading = "MoreMsg",
		},
		layout_placement = "center",
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
			center = {
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
		entries = {
			start = function(--[[response]]) end,
			complete = function(--[[response]]) end,
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

local _dev = _opts.dev_opts

Config.get = function(cfg)
	if cfg == "openai_models" then
		return utils.deepcopy(_openai_models)
	elseif cfg == "symbols" then
		return utils.deepcopy(_symbols)
	elseif cfg == "plugin_opts" then
		return utils.deepcopy(_plugin_opts)
	elseif cfg == "opts" then
		return utils.deepcopy(_opts)
	elseif cfg == "dev" then
		return utils.deepcopy(_dev)
	end
end

local init_event_hooks = function()
	local types = _opts.hooks
	for type, _ in pairs(types) do
		for hook, _ in pairs(types[type]) do
			Events.sub("hook:" .. type .. ":" .. hook, types[type][hook])
		end
	end
end

Config.init = function(opts)
	opts = opts or {}
	opts = vim.tbl_deep_extend("force", _opts, opts)
	if not opts.openai_key then
		local err_msg = string.format("opts:new: invalid opts: missing openai_key\nopts: %s", vim.inspect(_opts))
		error(err_msg)
	end
	_plugin_opts.log_level = vim.tbl_contains(log_levels, opts.log_level) and opts.log_level or default_log_level
	_opts = opts

	_plugin_opts.dev = _plugin_opts.dev or _opts.dev
	if _plugin_opts.dev then
		_dev = vim.tbl_deep_extend("force", _dev, _opts.dev_opts)
		_dev.prompt.message = {}
		for word in _dev.prompt.user_prompt:gmatch("[^\n]+") do
			table.insert(_dev.prompt.message, word)
		end
	end

	init_event_hooks()
end

return Config
