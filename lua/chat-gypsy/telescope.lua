local Log = require("chat-gypsy").Log
local History = require("chat-gypsy").History
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local pickers = require("telescope.pickers")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local writer = require("chat-gypsy.writer"):new():set_move_cursor(false)
local utils = require("chat-gypsy.utils")

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
		Log.trace(string.format("history %s selected", vim.inspect(selection)))
		History:load_from_file_path(selection.file_path)
		local current = History:get_current()
		require("chat-gypsy").Session:restore(current)
	end)
	return true
end

--  TODO: 2023-10-02 - show entry display at the top of preview
local define_preview = function(self, entry)
	vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
	vim.api.nvim_win_set_option(self.state.winid, "wrap", true)
	writer:set_bufnr(self.state.bufnr):set_winid(self.state.winid):reset()
	local contents = utils.decode_json_from_path(entry.file_path)
	for _, messages in pairs(contents.messages) do
		writer:from_role(messages.role, messages.time):newlines()
		if messages.role == "system" then
			writer:lines(messages.content):highlight(messages.role, messages.content):newlines()
		else
			writer:lines(messages.content):newlines()
		end
		writer:token_summary(messages.tokens, messages.role):newlines()
	end
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
			wrap_results = true,
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
