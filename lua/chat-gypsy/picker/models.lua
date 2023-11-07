---@class TelescopeModels
---@field public init fun()
---@field public pick fun(opts: table)
---@field private Models Models
---@field private Events Events
---@field private telescope table
---@field private config table
---@field private attach_mappings fun(prompt_bufnr: number): boolean
---@field private picker fun(entries: table, opts: table)
---@field private set_config fun(path: table)

local TelescopeProto = require("chat-gypsy.picker.prototype")

local TelescopeModels = setmetatable({}, TelescopeProto)
TelescopeModels.__index = TelescopeModels
setmetatable(TelescopeModels, {
	__index = TelescopeProto,
})

---@diagnostic disable-next-line: duplicate-set-field
function TelescopeModels:init()
	self.set_config({ "openai_models", "opts" })

	self.attach_mappings = function(prompt_bufnr)
		self.telescope.actions.select_default:replace(function()
			self.telescope.actions.close(prompt_bufnr)
			local selection = self.telescope.action_state.get_selected_entry()
			self.Events.pub("hook:models:set", selection.value)
		end)
		return true
	end

	self.picker = function(entries, opts)
		self.telescope.pickers
			.new(opts, {
				prompt_title = "Models",
				finder = self.telescope.finders.new_table({
					results = entries,
				}),
				sorter = self.telescope.conf.generic_sorter(),
				attach_mappings = self.attach_mappings,
				layout_strategy = self.config.opts.telescope.models.layout_strategy,
				layout_config = self.config.opts.telescope.models.layout_config,
			})
			:find()
	end
end

---@diagnostic disable-next-line: duplicate-set-field
function TelescopeModels:pick(opts)
	local entries = self.Models.names
	self.picker(entries, opts)
end

return TelescopeModels
