---@class TelescopePrototype @telescope picker prototype
---@field public new fun(): TelescopePrototype
---@field public pick fun() @abstract
---@field public init fun() @abstract
---@field private Log table Logger
---@field private telescope table @telescope
---@field private config table @plugic config
---@field private set_config fun(config_key: string|table)
---@field private writer Writer
---@field private sql Sql
---@field private utils Utils
---@field private Events Events
---@field private Models Models

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
	self.config = {}
	self.writer = require("chat-gypsy.writer"):new():set_move_cursor(false)
	self.set_config = function(config_key)
		local set_config = function(key)
			self.config[key] = require("chat-gypsy").Config.get(key)
		end
		if type(config_key) == "table" then
			for _, key in ipairs(config_key) do
				set_config(key)
			end
			return
		end
		set_config(config_key)
	end
	self.sql = require("chat-gypsy.sql"):new()
	self.utils = require("chat-gypsy.utils")
	self.Events = require("chat-gypsy").Events
	self.Models = require("chat-gypsy.models")

	self:init()
	return self
end

function TelescopePrototype:pick(_)
	self.Log.warn("TelescopePrototype:pick: not implemented")
end

function TelescopePrototype:init()
	self.Log.warn("TelescopePrototype:init: not implemented")
end

return TelescopePrototype
