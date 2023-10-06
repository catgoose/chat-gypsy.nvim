local Log = require("chat-gypsy").Log
local History = require("chat-gypsy").History
local Events = require("chat-gypsy").Events
local Config = require("chat-gypsy").Config
local models = require("chat-gypsy.models")
local opts, symbols = Config.get("opts"), Config.get("symbols")
local utils = require("chat-gypsy.utils")

local ChatRender = {}
ChatRender.__index = ChatRender

function ChatRender:new(winid, bufnr)
	setmetatable(self, ChatRender)
	self._ = {
		winid = winid,
		bufnr = bufnr,
		tokens = {
			user = 0,
			assistant = 0,
			total = 0,
		},
		line = "",
		lines = {},
		line_nr = 0,
	}
	self._.win_width = vim.api.nvim_win_get_width(self._.winid)
	self:init()
	return self
end

function ChatRender:init()
	self.set_lines = function(lines, new_lines)
		new_lines = new_lines or false
		if self._.bufnr and vim.api.nvim_buf_is_valid(self._.bufnr) then
			vim.api.nvim_buf_set_lines(self._.bufnr, self._.line_nr, self._.line_nr + 1, false, lines)
			if new_lines then
				self._.line_nr = self._.line_nr + #lines
				self.set_cursor(self._.line_nr)
			end
		end
	end
	self.token_summary = function(tokens)
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
		local summary = symbols.horiz:rep(self._.win_width - #tokens_display + 4) .. tokens_display
		local lines = { summary, "", "" }
		self.set_lines(lines)
		self.set_cursor(self._.line_nr + #lines)
		self._.line_nr = self._.line_nr + #lines
	end
	self.insert_line = function()
		table.insert(self._.lines, self._.line)
	end

	self.message_source = function(type)
		local model_config = models.get_config(opts.openai_params.model)
		if not type then
			return
		end
		if not vim.tbl_contains({ "prompt", "chat" }, type) then
			return
		end
		local source = type == "prompt" and "You" or model_config.model
		local lines = { string.format("%s (%s):", source, os.date("%H:%M")), "", "" }
		self.set_lines(lines, true)
	end

	self.add_newline = function(new_lines)
		new_lines = new_lines or 1
		for _ = 1, new_lines do
			self._.line_nr = self._.line_nr + 1
			self._.line = ""
			self.set_lines({ self._.line, self._.line })
			self.set_cursor(self._.line_nr + 1)
		end
	end

	self.set_cursor = function(line)
		if self._.winid and vim.api.nvim_win_is_valid(self._.winid) then
			line = line == 0 and 1 or line
			vim.api.nvim_win_set_cursor(self._.winid, { line, 0 })
		end
	end
end

function ChatRender:add_prompt(lines)
	self.set_cursor(self._.line_nr + 1)
	self.message_source("prompt")
	for _, line in ipairs(lines) do
		self.set_lines({ line }, true)
	end
end

function ChatRender:add_prompt_summary(message)
	local on_tokens = function(tokens)
		tokens = tokens or 0
		self._.tokens.user = tokens
		self._.tokens.total = self._.tokens.total + self._.tokens.user
		self.add_newline()
		self.token_summary(self._.tokens.user)
		History:add_prompt(message, self._.tokens)
	end
	utils.get_tokens(message, on_tokens)
	vim.cmd("silent! undojoin")
	self.message_source("chat")
end

function ChatRender:add_lines_by_chunks(chunk)
	local append = function(_chunk)
		self._.line = self._.line .. _chunk
		self.set_lines({ self._.line })
		self.set_cursor(self._.line_nr + 1)
	end
	if string.match(chunk, "\n") then
		for _chunk in chunk:gmatch(".") do
			if string.match(_chunk, "\n") then
				self.insert_line()
				self.add_newline()
			else
				append(_chunk)
			end
		end
	else
		append(chunk)
	end
end

function ChatRender:add_chat_summary(chunks)
	self.insert_line()
	Events.pub("hook:request:complete", self._.lines)
	Log.trace(string.format("on_complete: chunks: %s", vim.inspect(chunks)))
	local on_tokens = function(tokens)
		tokens = tokens or 0
		self._.tokens.assistant = tokens
		self._.tokens.total = self._.tokens.total + self._.tokens.assistant
		self.add_newline(2)
		self.token_summary(self._.tokens.assistant)
		History:add_chat(table.concat(chunks, ""), self._.tokens)
	end
	utils.get_tokens(chunks, on_tokens)
	vim.cmd("silent! undojoin")
end

function ChatRender:add_error(err)
	local message = err and err.error and err.error.message or type(err) == "string" and err or "Unknown error"
	local preamble = { message, "" }
	self.set_lines(preamble, true)
	Log.trace(
		string.format("adding error highlight to chat buffer: %s, current_chat_line: %s", self._.bufnr, self._.line_nr)
	)
	for i = 0, #preamble do
		vim.api.nvim_buf_add_highlight(self._.bufnr, -1, "ErrorMsg", self._.line_nr - #preamble + i, 0, -1)
	end
	self.token_summary()
end

function ChatRender:set_cursor_to_line_nr()
	self.set_cursor(self._.line_nr)
end

function ChatRender:from_history(bufnr, file_path)
	vim.api.nvim_buf_set_option(bufnr, "filetype", "markdown")
	local contents = utils.decode_json_from_path(file_path)
	for _, message_tbls in pairs(contents.messages) do
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { message_tbls.role, "" })
		for line in message_tbls.message:gmatch("[^\n]+") do
			vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { line })
		end
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "" })
	end
end

return ChatRender
