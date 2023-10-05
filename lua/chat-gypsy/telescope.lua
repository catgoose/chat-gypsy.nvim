local Log = require("chat-gypsy").Log
local History = require("chat-gypsy").History
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local pickers = require("telescope.pickers")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")

local Telescope = {}

local entry_maker = function(item)
	return {
		value = item.entries,
		display = string.format("%s: %s", item.entries.name, item.entries.description),
		ordinal = item.entries.name,
		file_path = item.entries.path.full,
	}
end

local attach_mappings = function(prompt_bufnr)
	actions.select_default:replace(function()
		actions.close(prompt_bufnr)
		local selection = action_state.get_selected_entry()
		Log.debug(string.format("history %s selected", vim.inspect(selection)))
		History:load_from_file_path(selection.file_path)
		-- local current = History:get_current()
		-- local chat = require("chat-gypsy.float"):new({
		-- 	mount = require("chat-gypsy").Config.get("opts").ui.behavior.mount,
		-- 	layout = require("chat-gypsy").Config.get("opts").ui.behavior.layout,
		-- 	render_history = false,
		-- })
		require("chat-gypsy").Session:restore()
	end)
	return true
end

--  TODO: 2023-10-02 - show entry display at the top of preview
local define_preview = function(self, entry)
	local render = require("chat-gypsy.render"):new()
	render:chat_from_history(self.state.bufnr, entry.file_path)
end

local get_picker_entries = function(entries, opts)
	pickers
		.new(opts, {
			prompt_title = "History",
			finder = finders.new_table({
				results = entries,
				entry_maker = entry_maker,
			}),
			sorter = conf.generic_sorter(),
			attach_mappings = attach_mappings,
			previewer = previewers.new_buffer_previewer({
				title = "Chat history",
				define_preview = define_preview,
			}),
		})
		:find()
end

local function history_picker(opts)
	History:get_picker_entries(get_picker_entries, opts)
end

function Telescope.history(opts)
	opts = opts or {}
	history_picker(opts)
end

return Telescope
