local TelescopePrototype = {}
TelescopePrototype.__index = TelescopePrototype

function TelescopePrototype:new()
	setmetatable(self, TelescopePrototype)
	self.Log = require("chat-gypsy").Log
	self.telescope = {
		finders = require("telescope.finders"),
		conf = require("telescope.config").values,
		pickers = require("telescope.pickers"),
		actions = require("telescope.actions"),
		action_state = require("telescope.actions.state"),
		previewers = require("telescope.previewers"),
	}
	self.writer = require("chat-gypsy.writer"):new():set_move_cursor(false)
	self.config = {
		opts = require("chat-gypsy").Config.get("opts"),
		symbols = require("chat-gypsy").Config.get("symbols"),
	}
	self.sql = require("chat-gypsy.sql"):new()
	self.utils = require("chat-gypsy.utils")

	self:init()
	return self
end

function TelescopePrototype:history(opts)
	require("chat-gypsy.telescope.history").history(opts)
end

function TelescopePrototype:models(opts)
	require("chat-gypsy.telescope.models").models(opts)
end

function TelescopePrototype:init()
	self.Log.warn("TelescopePrototype:init: not implemented")
end

return TelescopePrototype
