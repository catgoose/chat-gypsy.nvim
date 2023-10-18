local Log = require("chat-gypsy").Log
local Config = require("chat-gypsy").Config
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local pickers = require("telescope.pickers")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local writer = require("chat-gypsy.writer"):new():set_move_cursor(false)
local config_opts, symbols = Config.get("opts"), Config.get("symbols")
local sql = require("chat-gypsy.sql"):new()
local utils = require("chat-gypsy.utils")

local Telescope = {}

local function entry_ordinal(entry)
	local tags = vim.tbl_map(function(keyword)
		return symbols.hash .. keyword
	end, entry.keywords)
	return table.concat(tags, symbols.space) .. symbols.space .. entry.name
end

local entry_display = function(item)
	local win_width = vim.api.nvim_win_get_width(0)
	local keywords_length = 0
	for _, keyword in pairs(item.value.keywords) do
		keywords_length = keywords_length + #keyword + 2
	end
	local items = {
		item.value.name,
		symbols.space,
		symbols.space:rep(win_width - keywords_length - #item.value.name - 3),
	}
	local highlights = {}
	local start = #table.concat(items, "")
	for _, keyword in pairs(item.value.keywords) do
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
		local current = selection.value
		Log.trace(string.format("history %s selected", vim.inspect(current)))
		require("chat-gypsy").Session:restore(current)
	end)
	return true
end

local define_preview = function(self, item)
	local entries = item.value
	vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
	vim.api.nvim_win_set_option(self.state.winid, "wrap", true)
	writer:set_bufnr(self.state.bufnr):set_winid(self.state.winid):reset()
	writer:newline():heading(entries.openai_params.model):newlines()
	writer:heading(entries.description):newlines()
	writer:horiz_line():newlines()
	for _, messages in pairs(entries.messages) do
		writer:from_role(messages.role, messages.time):newlines()
		if messages.role == "system" then
			writer:lines(messages.content, { hlgroup = config_opts.ui.highlight.role[messages.role] }):newlines()
		else
			writer:lines(messages.content):newlines()
		end
		writer:token_summary(messages.tokens, messages.role):newlines()
	end
end

local function collect_entries()
	local sessions = sql:get_sessions()
	local entries = {}
	for _, session in ipairs(sessions) do
		local sql_messages = sql:get_messages_for_session(session.id)
		local messages = {}
		local openai_params = {}
		local tokens = {
			system = 0,
			user = 0,
			assistant = 0,
			total = 0,
		}
		for _, message in ipairs(sql_messages) do
			tokens[message.role] = tokens[message.role] + message.tokens
			tokens.total = tokens.total + message.tokens
			local _tokens = utils.deepcopy(tokens)
			local role = message.role
			local content = message.content
			table.insert(messages, {
				role = role,
				tokens = _tokens,
				time = message.time,
				content = content,
			})
			table.insert(openai_params, {
				role = role,
				content = content,
			})
		end
		table.insert(entries, {
			id = session.id,
			name = session.name,
			description = session.description,
			keywords = utils.split_string(session.keywords, ",", false),
			messages = messages,
			openai_params = openai_params,
		})
	end
	return entries
end

local picker = function(entries, opts)
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

function Telescope.history(opts)
	opts = opts or {}
	local entries = collect_entries()
	picker(entries, opts)
end

return Telescope
