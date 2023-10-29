Gypsy = {}

Gypsy.Log = {}
Gypsy.History = {}
Gypsy.Events = require("chat-gypsy.events")
Gypsy.Config = {}
Gypsy.Session = {}

Gypsy.setup = function(opts)
	Gypsy.Config = require("chat-gypsy.config")
	Gypsy.Config.init(opts)

	Gypsy.Log = require("chat-gypsy.logger").init()
	Gypsy.History = require("chat-gypsy.history"):new()
	Gypsy.Session = require("chat-gypsy.session"):new()

	require("chat-gypsy.usercmd").init()
	require("chat-gypsy.models").init()

	if Gypsy.Config.get("plugin_opts").dev then
		Gypsy.Log.trace("Gypsy:setup: dev mode enabled")
	end
end

Gypsy.toggle = function()
	Gypsy.Session:toggle()
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
