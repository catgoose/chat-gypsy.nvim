---@class Gypsy
---@field Log Logger
---@field History History
---@field Events Events
---@field Config Config
---@field Session Session
---@field setup fun(opts: table)
---@field toggle fun()
---@field open fun()
---@field hide fun()
---@field show fun()
---@field close fun()
---@field history fun(opts: table)
---@field models fun(opts: table)

Gypsy = {}

Gypsy.Log = {}
---@diagnostic disable-next-line: missing-fields
Gypsy.History = {}
Gypsy.Events = require("chat-gypsy.core.events")
Gypsy.Config = {}
Gypsy.Session = {}
Gypsy.UI = {}

Gypsy.setup = function(opts)
	Gypsy.Config = require("chat-gypsy.config")
	Gypsy.Config.init(opts)

	Gypsy.Log = require("chat-gypsy.core.logger").init()
	Gypsy.History = require("chat-gypsy.chat.history"):new()
	Gypsy.Session = require("chat-gypsy.chat.session"):new()

	require("chat-gypsy.config.usercmd").init()
	require("chat-gypsy.ai.models").init()

	if Gypsy.Config.get("plugin_opts").dev then
		Gypsy.Log.trace("Gypsy:setup: dev mode enabled")
	end

	Gypsy.UI = require("chat-gypsy.ui"):new()
end

Gypsy.toggle = function()
	-- Gypsy.Session:toggle()
	Gypsy.UI:toggle()
end

Gypsy.open = function()
	Gypsy.Session:open()
end

Gypsy.hide = function()
	Gypsy.Session:hide()
end

Gypsy.show = function()
	Gypsy.Session:show()
end

Gypsy.close = function()
	Gypsy.Session:close()
end

Gypsy.history = function(opts)
	opts = opts or {}
	require("chat-gypsy.picker").history(opts)
end

Gypsy.models = function(opts)
	opts = opts or {}
	require("chat-gypsy.picker").models(opts)
end

return Gypsy
