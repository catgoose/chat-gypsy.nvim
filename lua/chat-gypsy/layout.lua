local Log = require("chat-gypsy").Log
local Events = require("chat-gypsy").Events
local History = require("chat-gypsy").History
local nui_lo = require("nui.layout")
local ev = require("nui.utils.autocmd").event
local config = require("chat-gypsy.config")
local symbols = config.symbols
local plugin_cfg, dev, opts = config.plugin_cfg, config.dev, config.opts
local utils = require("chat-gypsy.utils")
local models = require("chat-gypsy.models")

local Layout = {}
Layout.__index = Layout

local state = {
	hidden = false,
	focused_win = "prompt",
	mounted = false,
	type = "float",
	prompt = {
		bufnr = 0,
		winid = 0,
	},
	response = {
		bufnr = 0,
		winid = 0,
		win_width = 0,
		line = "",
		lines = {},
		line_nr = 0,
	},
	tokens = {
		prompt = 0,
		response = 0,
		total = 0,
	},
}

function Layout:new(ui)
	setmetatable(self, Layout)
	self._ = {}
	self.layout = ui.layout
	self.boxes = ui.boxes
	self.openai = require("chat-gypsy.openai"):new()

	self.init_state = function()
		self._ = utils.deepcopy(state)
		self.set_ids()
		self._.response.win_width = vim.api.nvim_win_get_width(self._.response.winid)
	end
	self.set_ids = function()
		self._.response.winid = self.layout._.box.box[1].component.winid
		self._.prompt_winid = self.layout._.box.box[2].component.winid
		self._.response.bufnr = self.layout._.box.box[1].component.bufnr
		self._.prompt.bufnr = self.layout._.box.box[2].component.bufnr
		Log.trace("Setting winids and bufnrs for mounted layout")
		Log.trace(string.format("response.winid: %s", self._.response.winid))
		Log.trace(string.format("prompt_winid: %s", self._.prompt_winid))
		Log.trace(string.format("response_bufnr: %s", self._.response.bufnr))
		Log.trace(string.format("prompt_bufnr: %s", self._.prompt.bufnr))
	end

	self.focus_response = function()
		vim.api.nvim_set_current_win(self._.response.winid)
		self._.focused_win = "response"
	end
	self.focus_prompt = function()
		vim.api.nvim_set_current_win(self._.prompt_winid)
		self._.focused_win = "prompt"
	end
	self.focus_last_win = function()
		if self._.focused_win == "response" then
			vim.api.nvim_set_current_win(self._.response.winid)
		end
		if self._.focused_win == "prompt" then
			vim.api.nvim_set_current_win(self._.prompt_winid)
		end
	end
	self.is_focused = function()
		return vim.tbl_contains({ self._.prompt_winid, self._.response.winid }, vim.api.nvim_get_current_win())
	end

	self.response_set_cursor = function(line)
		if self._.response.winid and vim.api.nvim_win_is_valid(self._.response.winid) then
			line = line == 0 and 1 or line
			vim.api.nvim_win_set_cursor(self._.response.winid, { line, 0 })
		end
	end
	self.response_set_lines = function(lines, new_lines)
		new_lines = new_lines or false
		if self._.response.bufnr and vim.api.nvim_buf_is_valid(self._.response.bufnr) then
			vim.api.nvim_buf_set_lines(
				self._.response.bufnr,
				self._.response.line_nr,
				self._.response.line_nr + 1,
				false,
				lines
			)
			if new_lines then
				self._.response.line_nr = self._.response.line_nr + #lines
				self.response_set_cursor(self._.response.line_nr)
			end
		end
	end

	--  TODO: 2023-09-24 - highlight name
	self.message_source = function(type)
		local model_config = models.get_config(opts.openai_params.model)
		if not type then
			return
		end
		if not vim.tbl_contains({ "prompt", "response" }, type) then
			return
		end
		local source = type == "prompt" and "You" or model_config.model
		local lines = { string.format("%s (%s):", source, os.date("%H:%M")), "", "" }
		self.response_set_lines(lines, true)
	end

	self.response_token_summary = function(tokens)
		local model_config = models.get_config(opts.openai_params.model)
		local tokens_display = string.format(
			" Tokens: %s %s (%s/%s) %s",
			symbols.left_arrow,
			tokens,
			self._.tokens.total,
			model_config.max_tokens,
			symbols.right_arrow
		)
		--  TODO: 2023-09-24 - add highlighting
		local summary = symbols.horiz:rep(self._.response.win_width - #tokens_display + 4) .. tokens_display
		local lines = { summary, "", "" }
		self.response_set_lines(lines)
		self.response_set_cursor(self._.response.line_nr + #lines)
		self._.response.line_nr = self._.response.line_nr + #lines
	end

	self.insert_response_line = function()
		table.insert(self._.response.lines, self._.response.line)
	end

	-- self.restore = function()
	-- 	self.history:read()
	-- 	local history = self.history:get()
	-- 	local response = vim.tbl_filter(function(message)
	-- 		return message.type == "response"
	-- 	end, history.messages)
	-- 	for _, message in ipairs(response) do
	-- 		local lines = vim.split(message.message, "\n")
	-- 		for _, line in ipairs(lines) do
	-- 			self.response_set_lines({ line }, true)
	-- 		end
	-- 		self.response_token_summary()
	-- 	end
	-- end

	self.mount = function()
		Log.trace("Mounting UI")
		self.layout:mount()
		self.init_state()
		self._.mounted = true
		Log.trace("Configuring boxes")
		self:configure()
		if opts.ui.prompt.start_insert then
			vim.cmd.startinsert()
		end
		-- self.restore()
	end
	self.unmount = function()
		self.layout:unmount()
		Events.pub("layout:unmount")
		Events.pub("request:shutdown")
	end
	self.hide = function()
		self.layout:hide()
		self._.hidden = true
	end
	self.show = function()
		self.layout:show()
		self._.hidden = false
		self.set_ids()
		self.focus_last_win()
		self.response_set_cursor(self._.response.line_nr)
	end
	return self
end

function Layout:configure()
	for _, box in pairs(self.boxes) do
		box:map("n", "q", function()
			self.unmount()
		end, { noremap = true })
		box:on(ev.BufLeave, function(e)
			if box.winid and vim.api.nvim_win_is_valid(box.winid) then
				vim.api.nvim_win_set_buf(box.winid, e.buf)
			end
		end)
		box:on({
			ev.BufDelete,
		}, function()
			self.unmount()
		end)
	end

	self.boxes.prompt:on(ev.InsertEnter, function()
		local esc = vim.api.nvim_replace_termcodes("<ESC>", true, false, true)
		vim.api.nvim_feedkeys(esc, "n", true)
		vim.api.nvim_feedkeys("i", "n", true)
	end, { once = true })
	self.boxes.prompt:on({
		ev.TextChangedI,
		ev.TextChanged,
	}, function(e)
		if self._.type == "float" then
			local n_lines = vim.api.nvim_buf_line_count(e.buf)
			local float = opts.ui.layout.float
			n_lines = n_lines < float.prompt_max_lines and n_lines or float.prompt_max_lines
			self.layout:update(nui_lo.Box({
				nui_lo.Box(self.boxes.response, {
					size = "100%",
				}),
				nui_lo.Box(self.boxes.prompt, {
					size = n_lines + float.prompt_height - 1,
				}),
			}, { dir = "col" }))
		end
	end)

	local send_prompt = function(prompt_lines)
		if prompt_lines[1] == "" and #prompt_lines == 1 then
			return
		end
		local prompt_message = table.concat(prompt_lines, "\n")
		local function newln(n)
			n = n or 1
			for _ = 1, n do
				self._.response.line_nr = self._.response.line_nr + 1
				self._.response.line = ""
				self.response_set_lines({ self._.response.line, self._.response.line })
				self.response_set_cursor(self._.response.line_nr + 1)
			end
		end
		local function append(chunk)
			self._.response.line = self._.response.line .. chunk
			self.response_set_lines({ self._.response.line })
			self.response_set_cursor(self._.response.line_nr + 1)
		end
		local on_chunk = function(chunk)
			if string.match(chunk, "\n") then
				for _chunk in chunk:gmatch(".") do
					if string.match(_chunk, "\n") then
						self.insert_response_line()
						newln()
					else
						append(_chunk)
					end
				end
			else
				append(chunk)
			end
		end
		local on_start = function()
			self.response_set_cursor(self._.response.line_nr + 1)
			self.message_source("prompt")
			for _, line in ipairs(prompt_lines) do
				self.response_set_lines({ line }, true)
			end
			local on_tokens = function(tokens)
				tokens = tokens or 0
				self._.tokens.prompt = tokens
				self._.tokens.total = self._.tokens.total + self._.tokens.prompt
				newln()
				self.response_token_summary(self._.tokens.prompt)
			end
			utils.get_tokens(prompt_message, on_tokens)
			vim.cmd("silent! undojoin")
			self.message_source("response")
		end
		local before_start = function()
			vim.api.nvim_buf_set_lines(self._.prompt.bufnr, 0, -1, false, {})
		end
		local on_complete = function(chunks)
			self.insert_response_line()
			Events.pub("hook:request:complete", self._.response.lines)
			Log.trace(string.format("on_complete: chunks: %s", vim.inspect(chunks)))
			local on_tokens = function(tokens)
				tokens = tokens or 0
				self._.tokens.response = tokens
				self._.tokens.total = self._.tokens.total + self._.tokens.response
				newln(2)
				self.response_token_summary(self._.tokens.response)

				History.add(prompt_message, table.concat(chunks, ""), self._.tokens)
			end
			utils.get_tokens(chunks, on_tokens)
			vim.cmd("silent! undojoin")
		end
		local on_error = function(err)
			local message = err and err.error and err.error.message or type(err) == "string" and err or "Unknown error"
			local preamble = { message, "" }
			self.response_set_lines(preamble, true)
			Log.trace(
				string.format(
					"adding error highlight to response buffer: %s, current_response_line: %s",
					self._.response.bufnr,
					self._.response.line_nr
				)
			)
			for i = 0, #preamble do
				vim.api.nvim_buf_add_highlight(
					self._.response.bufnr,
					-1,
					"ErrorMsg",
					self._.response.line_nr - #preamble + i,
					0,
					-1
				)
			end
			self.response_token_summary()
		end
		self.openai:send_prompt(prompt_message, before_start, on_start, on_chunk, on_complete, on_error)
	end
	if plugin_cfg.dev and dev.prompt.enabled then
		send_prompt(dev.prompt.message)
	end
	self.boxes.prompt:map("n", "<Enter>", function()
		local prompt_lines = vim.api.nvim_buf_get_lines(self._.prompt.bufnr, 0, -1, false)
		send_prompt(prompt_lines)
	end, {})

	local modes = { "n", "i" }
	for _, mode in ipairs(modes) do
		self.boxes.prompt:map(mode, "<C-k>", function()
			self.focus_response()
		end, { noremap = true, silent = true })
		self.boxes.response:map(mode, "<C-j>", function()
			self.focus_prompt()
		end, { noremap = true, silent = true })
	end
end

return Layout
