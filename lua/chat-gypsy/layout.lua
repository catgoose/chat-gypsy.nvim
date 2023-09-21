local nui_lo = require("nui.layout")
local ev = require("nui.utils.autocmd").event
local config = require("chat-gypsy.config")
local symbols = config.symbols
local plugin_cfg, dev, opts = config.plugin_cfg, config.dev, config.opts
local Log = require("chat-gypsy").Log
local Events = require("chat-gypsy").Events
local utils = require("chat-gypsy.utils")

local Layout = {}
Layout.__index = Layout

local default_state = {
	hidden = false,
	focused_win = "prompt",
	prompt_winid = 0,
	chat_winid = 0,
	prompt_bufnr = 0,
	chat_bufnr = 0,
	mounted = false,
	layout = "float",
	current_line = 0,
	tokens = {
		current = 0,
		total = 0,
	},
}

function Layout.new(ui)
	local self = setmetatable({}, Layout)
	self.layout = ui.layout
	self.boxes = ui.boxes
	self.events = require("chat-gypsy.events").new()
	self.openai = require("chat-gypsy.openai").new(self.events)
	self._ = {}

	Events:sub("request:error", function(err)
		vim.schedule(function()
			self.set_lines_chat(self._.current_line, self._.current_line + 1, { "ERROR:", "" }, 2)
			local error = utils.tbl_to_json_string(err)
			self.set_lines_chat(self._.current_line, self._.current_line + 1, { "```json" }, 1)
			for line in error:gmatch("[^\n]+") do
				self.set_lines_chat(self._.current_line, self._.current_line + 1, { line }, 1)
			end
			self.set_lines_chat(self._.current_line, self._.current_line + 1, { "```" }, 1)
		end)
	end)

	self.focus_chat = function()
		vim.api.nvim_set_current_win(self._.chat_winid)
		self._.focused_win = "chat"
	end
	self.focus_prompt = function()
		vim.api.nvim_set_current_win(self._.prompt_winid)
		self._.focused_win = "prompt"
	end
	self.focus_last_win = function()
		if self._.focused_win == "chat" then
			vim.api.nvim_set_current_win(self._.chat_winid)
		end
		if self._.focused_win == "prompt" then
			vim.api.nvim_set_current_win(self._.prompt_winid)
		end
	end
	self.is_focused = function()
		return vim.tbl_contains({ self._.prompt_winid, self._.chat_winid }, vim.api.nvim_get_current_win())
	end

	self.set_ids = function()
		local set_winids = function()
			self._.chat_winid = self.layout._.box.box[1].component.winid
			self._.prompt_winid = self.layout._.box.box[2].component.winid
		end
		local set_bufnrs = function()
			self._.chat_bufnr = self.layout._.box.box[1].component.bufnr
			self._.prompt_bufnr = self.layout._.box.box[2].component.bufnr
		end
		set_winids()
		set_bufnrs()
		Log.trace("Setting winids and bufnrs for mounted layout")
		Log.trace(string.format("chat_winid: %s", self._.chat_winid))
		Log.trace(string.format("prompt_winid: %s", self._.prompt_winid))
		Log.trace(string.format("chat_bufnr: %s", self._.chat_bufnr))
		Log.trace(string.format("prompt_bufnr: %s", self._.prompt_bufnr))
	end

	local set_lines = function(bufnr, line_start, line_end, lines)
		if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_set_lines(bufnr, line_start, line_end, false, lines)
		end
	end
	self.set_lines_chat = function(line_start, line_end, lines, delta_current_lines)
		delta_current_lines = delta_current_lines or 0
		set_lines(self._.chat_bufnr, line_start, line_end, lines)
		if delta_current_lines > 0 then
			self._.current_line = self._.current_line + delta_current_lines
		end
	end
	self.set_lines_prompt = function(line_start, line_end, lines)
		set_lines(self._.prompt_bufnr, line_start, line_end, lines)
	end
	local set_cursor = function(winid, pos)
		if winid and vim.api.nvim_win_is_valid(winid) then
			vim.api.nvim_win_set_cursor(winid, pos)
		end
	end
	self.set_cursor_chat = function(pos)
		set_cursor(self._.chat_winid, pos)
	end
	self.chat_last_line = function()
		return vim.api.nvim_buf_line_count(self._.chat_bufnr)
	end

	self.mount = function()
		Log.trace("Mounting UI")
		self.layout:mount()
		self.reset_layout()
		self._.mounted = true
		self.set_ids()
		Log.trace("Configuring boxes")
		self:configure()
		if opts.ui.prompt.start_insert then
			vim.cmd.startinsert()
		end
	end
	self.unmount = function()
		self.layout:unmount()
		self.reset_layout()
		Events:pub("layout:unmount")
		self.events:pub("layout:unmount")
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
	end

	self.reset_layout = function()
		self._ = utils.deepcopy(default_state)
		self.set_ids()
	end
	return self
end

function Layout:configure()
	for _, box in pairs(self.boxes) do
		box:map("n", "q", function()
			self.unmount()
		end, { noremap = true })

		box:on(ev.BufLeave, function(e)
			vim.schedule(function()
				if box.winid and vim.api.nvim_win_is_valid(box.winid) then
					vim.api.nvim_win_set_buf(box.winid, e.buf)
				end
			end)
		end)

		box:on({
			ev.BufDelete,
		}, function()
			self.unmount()
		end)
	end

	local prompt_send = function(prompt_lines)
		if prompt_lines[1] == "" and #prompt_lines == 1 then
			return
		end
		local prompt_message = table.concat(prompt_lines, "\n")
		self._.current_line = self._.current_line == 1 and 0 or self._.current_line
		local line = ""
		local response_lines = ""
		local function newln(n)
			n = n or 1
			for _ = 1, n do
				self._.current_line = self._.current_line + 1
				line = ""
				self.set_lines_chat(self._.current_line, self._.current_line + 1, { line, line })
				self.set_cursor_chat({ self._.current_line + 1, 0 })
			end
		end
		local function append(chunk)
			line = line .. chunk
			response_lines = response_lines .. line
			self.set_lines_chat(self._.current_line, self._.current_line + 1, { line })
			self.set_cursor_chat({ self._.current_line + 1, 0 })
		end
		local on_chunk = function(chunk)
			if string.match(chunk, "\n") then
				for _chunk in chunk:gmatch(".") do
					if string.match(_chunk, "\n") then
						response_lines = response_lines .. _chunk
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
			self.set_cursor_chat({ self._.current_line + 1, 0 })
		end
		local on_complete = function(chunks)
			Events:pub("hook:request:complete", response_lines)
			Log.trace(string.format("on_complete: chunks: %s", vim.inspect(chunks)))
			vim.cmd("silent! undojoin")
			local on_tokens = function(tokens)
				self._.tokens.current = tokens
				self._.tokens.total = self._.tokens.total + self._.tokens.current
				local tokens_display = string.format(
					" %s Tokens: %s/%s %s",
					symbols.left_arrow,
					self._.tokens.current,
					self._.tokens.total,
					symbols.right_arrow
				)

				vim.print(tokens_display)
				vim.print(#tokens_display)

				local line_break_msg = symbols.horiz:rep(
					vim.api.nvim_win_get_width(self._.chat_winid) - #tokens_display + 4
				) .. tokens_display
				newln(2)
				self.set_lines_chat(self._.current_line, -1, { line_break_msg })
				newln(2)
			end
			utils.calculate_tokens(prompt_message, on_tokens)
		end

		self.openai:send_prompt(prompt_message, on_start, on_chunk, on_complete)
	end

	if plugin_cfg.dev and dev.prompt.enabled then
		prompt_send(dev.prompt.message)
	end

	self.boxes.prompt:map("n", "<Enter>", function()
		local prompt_lines = vim.api.nvim_buf_get_lines(self._.prompt_bufnr, 0, -1, false)
		self.set_lines_prompt(0, -1, {})
		prompt_send(prompt_lines)
	end, {})
	self.boxes.prompt:on(ev.InsertEnter, function()
		local esc = vim.api.nvim_replace_termcodes("<ESC>", true, false, true)
		vim.api.nvim_feedkeys(esc, "n", true)
		vim.api.nvim_feedkeys("i", "n", true)
	end, { once = true })
	self.boxes.prompt:on({
		ev.TextChangedI,
		ev.TextChanged,
	}, function(e)
		if self._.layout == "float" then
			local n_lines = vim.api.nvim_buf_line_count(e.buf)
			local float = opts.ui.layout.float
			n_lines = n_lines < float.prompt_max_lines and n_lines or float.prompt_max_lines
			self.layout:update(nui_lo.Box({
				nui_lo.Box(self.boxes.chat, {
					size = "100%",
				}),
				nui_lo.Box(self.boxes.prompt, {
					size = n_lines + float.prompt_height - 1,
				}),
			}, { dir = "col" }))
		end
	end)

	local modes = { "n", "i" }
	for _, mode in ipairs(modes) do
		self.boxes.prompt:map(mode, "<C-k>", function()
			self.focus_chat()
		end, { noremap = true, silent = true })
		self.boxes.chat:map(mode, "<C-j>", function()
			self.focus_prompt()
		end, { noremap = true, silent = true })
	end
end

return Layout
