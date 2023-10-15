local Log = require("chat-gypsy").Log
local History = require("chat-gypsy").History
local Config = require("chat-gypsy").Config
local UI = require("chat-gypsy.ui")
local plugin_opts, dev, opts = Config.get("plugin_opts"), Config.get("dev"), Config.get("opts")
local utils = require("chat-gypsy.utils")
local nui_lo = require("nui.layout")
local ev = require("nui.utils.autocmd").event

local state = {
	hidden = false,
	mounted = false,
	focused_win = "prompt",
	chat = {
		bufnr = 0,
		winid = 0,
	},
	prompt = {
		bufnr = 0,
		winid = 0,
	},
}

Float = setmetatable({}, UI)
Float.__index = Float
setmetatable(Float, {
	__index = UI,
})

---@diagnostic disable-next-line: duplicate-set-field
function Float:init()
	self._ = {}
	self.request = require("chat-gypsy.request"):new()
	self.writer = require("chat-gypsy.writer"):new()

	self.init_state = function()
		self._ = utils.deepcopy(state)
		self._.chat.bufnr = self.layout._.box.box[1].component.bufnr
		self._.prompt.bufnr = self.layout._.box.box[2].component.bufnr
		self._.should_compose_entries = false
		self.writer:set_bufnr(self._.chat.bufnr)
		self.writer:set_winid(self._.chat.winid)
		self.set_winids()
	end
	self.set_winids = function()
		self._.chat.winid = self.layout._.box.box[1].component.winid
		self._.prompt_winid = self.layout._.box.box[2].component.winid
		self.writer:set_winid(self._.chat.winid)
	end

	-- focus
	self.focus_chat = function()
		vim.api.nvim_set_current_win(self._.chat.winid)
		self._.focused_win = "chat"
	end
	self.focus_prompt = function()
		vim.api.nvim_set_current_win(self._.prompt_winid)
		self._.focused_win = "prompt"
	end
	self.focus_last_win = function()
		if self._.focused_win == "chat" then
			vim.api.nvim_set_current_win(self._.chat.winid)
		end
		if self._.focused_win == "prompt" then
			vim.api.nvim_set_current_win(self._.prompt_winid)
		end
	end
	self.is_focused = function()
		return vim.tbl_contains({ self._.prompt_winid, self._.chat.winid }, vim.api.nvim_get_current_win())
	end

	-- mounting
	self.mount = function()
		Log.trace("Mounting UI")
		self.layout:mount()
		self.init_state()
		self._.mounted = true
		Log.trace("Configuring boxes")
		self:configure()
		if opts.ui.behavior.prompt.start_insert then
			vim.cmd.startinsert()
		end
	end
	self.unmount = function()
		self.layout:unmount()
		self.request:shutdown_handlers()
		self._.instance = false
		--  QUESTION: 2023-10-08 - How does this function if there was an
		--  error?
		--  BUG: 2023-10-14 - Closing the float for a continued chat session
		--  resets history for chat
		if self._.should_compose_entries then
			History:compose_entries(self.request)
		end
	end
	self.hide = function()
		self.layout:hide()
		self._.hidden = true
	end
	self.show = function()
		self.layout:show()
		self._.hidden = false
		self.set_winids()
		self.focus_last_win()
		self.writer:set_cursor()
	end

	-- writing callbacks
	self.system_writer = function(history)
		self._.should_compose_entries = false
		self.writer:from_role(history.role):newlines()
		self.writer:lines(history.content, { hlgroup = opts.ui.highlight.role[history.role] }):newlines()
		self.writer:calculate_tokens(history.content, history.role):newlines()
	end
	self.before_request = function()
		vim.api.nvim_buf_set_lines(self._.prompt.bufnr, 0, -1, false, {})
		self._.should_compose_entries = true
	end
	self.on_chunk_stream_start = function(lines)
		self._.should_compose_entries = false
		self.writer:from_role("user"):newlines():lines(lines):newlines()
		self.writer:calculate_tokens(lines, "user"):newlines()
		self.writer:from_role("assistant"):newlines()
	end
	self.on_chunk = function(chunk)
		self.writer:append_chunk(chunk)
	end
	self.on_chunks_complete = function(chunks)
		self.writer:newlines():calculate_tokens(chunks, "assistant"):newlines()
		self._.should_compose_entries = true
	end
	self.on_chunk_error = function(err)
		self.writer:from_role("error"):newlines()
		self.writer:error(err):newline()
		self._.should_compose_entries = false
	end

	self:actions()
end

function Float:actions()
	if self.ui_opts.mount then
		self.mount()
	end
	if self.ui_opts.restore_history then
		Log.trace(string.format("Restoring history: %s", vim.inspect(self.ui_opts.current)))
		self.request:set_openai_params(self.ui_opts.current.openai_params)
		History:set_id(self.ui_opts.current.id)
		for _, message in ipairs(self.ui_opts.current.messages) do
			if message.role == "system" then
				self.writer:from_role(message.role):newlines()
				self.writer:lines(message.content, { hlgroup = opts.ui.highlight.role[message.role] }):newlines()
			else
				self.writer:from_role(message.role):newlines():lines(message.content):newlines()
			end
			self.writer:replay_tokens(message.tokens, message.role):newlines()
			History:replay(message)
		end
	end
end

function Float:configure()
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
		if self.ui_opts.placement == "center" then
			local n_lines = vim.api.nvim_buf_line_count(e.buf)
			local center = opts.ui.layout.center
			n_lines = n_lines < center.prompt_max_lines and n_lines or center.prompt_max_lines
			self.layout:update(nui_lo.Box({
				nui_lo.Box(self.boxes.chat, {
					size = "100%",
				}),
				nui_lo.Box(self.boxes.prompt, {
					size = n_lines + center.prompt_height - 1,
				}),
			}, { dir = "col" }))
		end
	end)

	local send_prompt = function(prompt_lines)
		if prompt_lines[1] == "" and #prompt_lines == 1 then
			return
		end

		self.request:send(
			prompt_lines,
			self.before_request,
			self.system_writer,
			self.on_chunk_stream_start,
			self.on_chunk,
			self.on_chunks_complete,
			self.on_chunk_error
		)
	end

	if plugin_opts.dev and dev.prompt.enabled and not self.ui_opts.restore_history then
		send_prompt(dev.prompt.message)
	end

	self.boxes.prompt:map("n", "<Enter>", function()
		local prompt_lines = vim.api.nvim_buf_get_lines(self._.prompt.bufnr, 0, -1, false)
		send_prompt(prompt_lines)
	end, {})

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

return Float
