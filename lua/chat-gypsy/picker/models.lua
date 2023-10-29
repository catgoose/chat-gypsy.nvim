local TelescopeProto = require("chat-gypsy.picker.prototype")

local TelescopeModels = setmetatable({}, TelescopeProto)
TelescopeModels.__index = TelescopeModels
setmetatable(TelescopeModels, {
	__index = TelescopeProto,
})

---@diagnostic disable-next-line: duplicate-set-field
function TelescopeModels:init()
	self.set_config({ "openai_models", "opts" })

	self.entry_display = function(item)
		return item.value.model
	end

	self.entry_ordinal = function(entry)
		return entry.model
	end

	self.entry_maker = function(item)
		return {
			value = item,
			display = self.entry_display,
			ordinal = self.entry_ordinal(item),
		}
	end

	self.attach_mappings = function(prompt_bufnr)
		self.telescope.actions.select_default:replace(function()
			self.telescope.actions.close(prompt_bufnr)
			local selection = self.telescope.action_state.get_selected_entry()
			local model = selection.value
		end)
		return true
	end

	self.picker = function(entries, opts)
		self.telescope.pickers
			.new(opts, {
				prompt_title = "Models",
				finder = self.telescope.finders.new_table({
					results = entries,
					entry_maker = self.entry_maker,
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
	local entries = self.config.openai_models
	self.picker(entries, opts)
end

return TelescopeModels
