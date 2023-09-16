local nui_lo = require("nui.layout")
local ev = require("nui.utils.autocmd").event
local config = require("chat-gypsy.config")
local cfg, dev, opts = config.cfg, config.dev, config.opts
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
}

function Layout.new(ui)
	local self = setmetatable({}, Layout)
	self.layout = ui.layout
	self.boxes = ui.boxes
	self.openai = require("chat-gypsy.openai").new()

	self.focus_chat = function()
		vim.api.nvim_set_current_win(self.state.chat_winid)
		self.state.focused_win = "chat"
	end
	self.focus_prompt = function()
		vim.api.nvim_set_current_win(self.state.prompt_winid)
		self.state.focused_win = "prompt"
	end
	self.focus_last_win = function()
		if self.state.focused_win == "chat" then
			vim.api.nvim_set_current_win(self.state.chat_winid)
		end
		if self.state.focused_win == "prompt" then
			vim.api.nvim_set_current_win(self.state.prompt_winid)
		end
	end
	self.is_focused = function()
		return vim.tbl_contains({ self.state.prompt_winid, self.state.chat_winid }, vim.api.nvim_get_current_win())
	end

	self.set_ids = function()
		local set_winids = function()
			self.state.chat_winid = self.layout._.box.box[1].component.winid
			self.state.prompt_winid = self.layout._.box.box[2].component.winid
		end
		local set_bufnrs = function()
			self.state.chat_bufnr = self.layout._.box.box[1].component.bufnr
			self.state.prompt_bufnr = self.layout._.box.box[2].component.bufnr
		end
		set_winids()
		set_bufnrs()
		Log.debug("Setting winids and bufnrs for mounted layout")
		Log.debug(string.format("chat_winid: %s", self.state.chat_winid))
		Log.debug(string.format("prompt_winid: %s", self.state.prompt_winid))
		Log.debug(string.format("chat_bufnr: %s", self.state.chat_bufnr))
		Log.debug(string.format("prompt_bufnr: %s", self.state.prompt_bufnr))
	end

	self.set_lines = function(bufnr, line_start, line_end, lines)
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_set_lines(bufnr, line_start, line_end, false, lines)
		end
	end
	self.set_cursor = function(winid, pos)
		if vim.api.nvim_win_is_valid(winid) then
			vim.api.nvim_win_set_cursor(winid, pos)
		end
	end

	self.mount = function()
		Log.debug("Mounting UI")
		self.layout:mount()
		self.reset_layout()
		self.state.mounted = true
		self.set_ids()
		Log.debug("Configuring boxes")
		self:configure()
		if opts.ui.prompt.start_insert then
			vim.cmd.startinsert()
		end
	end
	self.unmount = function()
		self.layout:unmount()
		self.reset_layout()
		Events:pub("layout:unmount")
	end
	self.hide = function()
		self.layout:hide()
		self.state.hidden = true
	end
	self.show = function()
		self.layout:show()
		self.state.hidden = false
		self.set_ids()
		self.focus_last_win()
	end

	self.reset_layout = function()
		self.state = utils.deepcopy(default_state)
		self.set_ids()
	end
	self.reset_layout()
	return self
end

function Layout:configure()
	for _, box in pairs(self.boxes) do
		box:map("n", "q", function()
			self.unmount()
		end, { noremap = true })

		-- protects against loading other buffers in the prompt window
		box:on(ev.BufLeave, function(e)
			vim.schedule(function()
				if box.winid and vim.api.nvim_win_is_valid(box.winid) and self.layout._.mounted == true then
					vim.api.nvim_win_set_buf(box.winid, e.buf)
				end
			end)
		end)

		-- Destroy UI when any layout buffer is deleted
		box:on({
			ev.BufDelete,
		}, function()
			self.unmount()
		end)
	end

	local line_n = 0
	local line = ""
	local prompt_send = function(prompt_lines)
		if prompt_lines[1] == "" and #prompt_lines == 1 then
			return
		end
		local chat_lines = ""
		local function newl(bufnr, n)
			n = n or 1
			for _ = 1, n do
				line_n = line_n + 1
				line = ""
				self.set_lines(bufnr, line_n, -1, { line })
				self.set_cursor(self.state.chat_winid, { line_n, 0 })
			end
		end
		local function append(chunk)
			line = line .. chunk
			chat_lines = chat_lines .. chunk
			self.set_lines(self.state.chat_bufnr, line_n, -1, { line })
		end
		local on_chunk = function(chunk)
			--  TODO: 2023-09-16 - is this check required?
			if self.boxes.chat.bufnr == self.state.chat_bufnr then
				if string.match(chunk, "\n") then
					for _chunk in chunk:gmatch(".") do
						if string.match(_chunk, "\n") then
							chat_lines = chat_lines .. "\n"
							newl(self.state.chat_bufnr)
						else
							append(_chunk)
						end
					end
				else
					append(chunk)
				end
			end
		end
		local on_start = function()
			self.set_cursor(self.state.chat_winid, { line_n > 0 and line_n or 1, 0 })
		end
		local on_complete = function(chunks)
			Log.debug(string.format("on_complete: chunks: %s", vim.inspect(chunks)))
			newl(self.state.chat_bufnr, 2)
			Events:pub("hook:request:complete", chat_lines)
			vim.cmd("silent! undojoin")
		end

		self.openai:sendPrompt(prompt_lines, on_start, on_chunk, on_complete)
	end

	if cfg.dev and dev.prompt.enabled then
		prompt_send(dev.prompt.message)
	end

	-- Send prompt on enter
	self.boxes.prompt:map("n", "<Enter>", function()
		local prompt_lines = vim.api.nvim_buf_get_lines(self.state.prompt_bufnr, 0, -1, false)
		self.set_lines(self.state.prompt_bufnr, 0, -1, {})
		prompt_send(prompt_lines)
	end, {})
	-- nui doesn't quite start on line 1 so we need to send an escape to
	-- reinitialize
	self.boxes.prompt:on(ev.InsertEnter, function()
		local esc = vim.api.nvim_replace_termcodes("<ESC>", true, false, true)
		vim.api.nvim_feedkeys(esc, "n", true)
		vim.api.nvim_feedkeys("i", "n", true)
	end, { once = true })
	-- Expand prompt size until max_lines is reached in height
	self.boxes.prompt:on({
		ev.TextChangedI,
		ev.TextChanged,
	}, function(e)
		if self.state.layout == "float" then
			local n_lines = vim.api.nvim_buf_line_count(e.buf)
			local float = cfg.ui.layout.float
			n_lines = n_lines < float.max_lines and n_lines or float.max_lines
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

	-- Move between popups
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
