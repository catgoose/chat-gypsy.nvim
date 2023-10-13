local Log = require("chat-gypsy").Log
local History = require("chat-gypsy").History
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local pickers = require("telescope.pickers")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local writer = require("chat-gypsy.writer"):new():set_move_cursor(false)
local symbols = require("chat-gypsy").Config.get("symbols")

local Telescope = {}

local function entry_ordinal(item)
	local tags = vim.tbl_map(function(keyword)
		return symbols.hash .. keyword
	end, item.entries.keywords)
	return table.concat(tags, symbols.space) .. symbols.space .. item.entries.name
end

local entry_display = function(item)
	local win_width = vim.api.nvim_win_get_width(0)
	local keywords_length = 0
	for _, keyword in pairs(item.value.entries.keywords) do
		keywords_length = keywords_length + #keyword + 2
	end
	local items =
		{ item.value.entries.name, symbols.space:rep(win_width - keywords_length - #item.value.entries.name - 2) }
	local highlights = {}
	local start = #table.concat(items, "")
	for _, keyword in pairs(item.value.entries.keywords) do
		vim.list_extend(items, { symbols.hash, keyword, symbols.space })
		vim.list_extend(highlights, {
			{ { start, start + 1 }, "TelescopeResultsOperator" },
			{ { start + 1, start + 1 + #keyword }, "TelescopeResultsIdentifier" },
		})
		start = start + 1 + #keyword + 1
	end
	return table.concat(items), highlights
end

local entry_maker = function(item)
	return {
		value = item,
		display = entry_display,
		ordinal = entry_ordinal(item),
	}
end

local attach_mappings = function(prompt_bufnr)
	actions.select_default:replace(function()
		actions.close(prompt_bufnr)
		local selection = action_state.get_selected_entry()
		local current = {
			openai_params = selection.value.entries.openai_params,
			messages = selection.value.entries.messages,
		}
		Log.trace(string.format("history %s selected", vim.inspect(current)))
		require("chat-gypsy").Session:restore(current)
	end)
	return true
end

local define_preview = function(self, item)
	local entries = item.value.entries
	vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
	vim.api.nvim_win_set_option(self.state.winid, "wrap", true)
	writer:set_bufnr(self.state.bufnr):set_winid(self.state.winid):reset()
	writer:newline()
	writer:heading(entries.openai_params.model):newlines()
	writer:heading(entries.description):newlines()
	writer:horiz_line():newlines()
	for _, messages in pairs(entries.messages) do
		writer:from_role(messages.role, messages.time):newlines()
		if messages.role == "system" then
			writer:lines(messages.content):role_highlight(messages.role):newlines()
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
