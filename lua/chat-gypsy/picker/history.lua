local TelescopeProto = require("chat-gypsy.picker.prototype")

local TelescopeHistory = setmetatable({}, TelescopeProto)
TelescopeHistory.__index = TelescopeHistory
setmetatable(TelescopeHistory, {
	__index = TelescopeProto,
})

---@diagnostic disable-next-line: duplicate-set-field
function TelescopeHistory:init()
	self.entry_ordinal = function(entry)
		local tags = vim.tbl_map(function(keyword)
			return self.config.symbols.hash .. keyword
		end, entry.keywords)
		return table.concat(tags, self.config.symbols.space) .. self.config.symbols.space .. entry.name
	end

	self.entry_display = function(item)
		local win_width = vim.api.nvim_win_get_width(0)
		local keywords_length = 0
		for _, keyword in pairs(item.value.keywords) do
			keywords_length = keywords_length + #keyword + 2
		end
		local items = {
			item.value.name,
			self.config.symbols.space,
			self.config.symbols.space:rep(win_width - keywords_length - #item.value.name - 3),
		}
		local highlights = {}
		local start = #table.concat(items, "")
		for _, keyword in pairs(item.value.keywords) do
			vim.list_extend(items, { self.config.symbols.hash, keyword, self.config.symbols.space })
			vim.list_extend(highlights, {
				{ { start, start + 1 }, "TelescopeHistoryResultsOperator" },
				{ { start + 1, start + 1 + #keyword }, "TelescopeHistoryResultsIdentifier" },
			})
			start = start + 1 + #keyword + 1
		end
		return table.concat(items), highlights
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
			local history = selection.value
			self.Log.trace(string.format("history %s selected", vim.inspect(history)))
			require("chat-gypsy").Session:restore(history)
		end)
		return true
	end

	self.define_preview = function(_self, item)
		local entries = item.value
		local model = entries.openai_params.model
		vim.api.nvim_buf_set_option(_self.state.bufnr, "filetype", "markdown")
		vim.api.nvim_win_set_option(_self.state.winid, "wrap", true)
		self.writer:set_bufnr(_self.state.bufnr):set_winid(_self.state.winid):reset()
		self.writer:newline():heading(model):newlines()
		self.writer:heading(entries.description):newlines()
		self.writer:horiz_line():newlines()
		for _, messages in pairs(entries.messages) do
			self.writer:from_role(messages.role, model, messages.time):newlines()
			if messages.role == "system" then
				self.writer
					:lines(messages.content, { hlgroup = self.config.opts.ui.highlight.role[messages.role] })
					:newlines()
			else
				self.writer:lines(messages.content):newlines()
			end
			self.writer:token_summary(messages.tokens, messages.role, model):newlines()
		end
	end

	self.collect_entries = function()
		local session_status = self.sql:get_sessions()
		if not session_status.success then
			return {}
		end
		local sessions = session_status.data
		local entries = {}
		for _, session in ipairs(sessions) do
			local message_status = self.sql:get_messages_for_session(session.id)
			if not message_status.success then
				goto continue
			end
			local sql_messages = message_status.data
			local messages = {}
			local openai_params = {
				model = session.model,
				temperature = session.temperature,
				messages = {},
			}
			local tokens = {
				system = 0,
				user = 0,
				assistant = 0,
				total = 0,
			}
			for _, message in ipairs(sql_messages) do
				tokens[message.role] = tokens[message.role] + message.tokens
				tokens.total = tokens.total + message.tokens
				local _tokens = self.utils.deep_copy(tokens)
				local role = message.role
				local content = tostring(message.content)
				table.insert(messages, {
					role = role,
					content = content,
					tokens = _tokens,
					time = message.time,
				})
				table.insert(openai_params.messages, {
					role = role,
					content = content,
				})
			end
			table.insert(entries, {
				id = session.id,
				name = tostring(session.name),
				description = tostring(session.description),
				keywords = self.utils.split_string(session.keywords, ",", false),
				messages = messages,
				openai_params = openai_params,
			})
			::continue::
		end
		return entries
	end

	self.picker = function(entries, opts)
		self.telescope.pickers
			.new(opts, {
				prompt_title = "History",
				finder = self.telescope.finders.new_table({
					results = entries,
					entry_maker = self.entry_maker,
				}),
				sorter = self.telescope.conf.generic_sorter(),
				attach_mappings = self.attach_mappings,
				previewer = self.telescope.previewers.new_buffer_previewer({
					title = "Chat history",
					define_preview = self.define_preview,
				}),
				wrap_results = true,
			})
			:find()
	end
end

---@diagnostic disable-next-line: duplicate-set-field
function TelescopeHistory:pick(opts)
	local entries = self.collect_entries()
	self.picker(entries, opts)
end

return TelescopeHistory
