local Log = require("chat-gypsy").Log
local History = require("chat-gypsy").History
local Events = require("chat-gypsy").Events
local Config = require("chat-gypsy").Config
local models = require("chat-gypsy.models")
local opts, symbols = Config.get("opts"), Config.get("symbols")
local utils = require("chat-gypsy.utils")

local ChatRender = {}
ChatRender.__index = ChatRender

function ChatRender:new(cfg)
	cfg = cfg or {
		winid = nil,
		bufnr = nil,
	}
	cfg.winid = cfg.winid or nil
	cfg.bufnr = cfg.bufnr or nil
	setmetatable(self, ChatRender)
	self._ = {
		winid = cfg.winid,
		bufnr = cfg.bufnr,
		win_width = cfg.winid and vim.api.nvim_win_get_width(cfg.winid) or 0,
		tokens = {
			user = 0,
			assistant = 0,
			total = 0,
		},
		line = "",
		lines = {},
		line_nr = 0,
	}
	self:init()
	return self
end

function ChatRender:reset()
	self._.line = ""
	self._.lines = {}
	self._.line_nr = 0
end

function ChatRender:init()
	self.set_lines = function(lines)
		if self._.bufnr and vim.api.nvim_buf_is_valid(self._.bufnr) then
			vim.api.nvim_buf_set_lines(self._.bufnr, self._.line_nr, self._.line_nr + 1, false, lines)
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

	self.identity_for = function(agent)
		local model_config = models.get_config(opts.openai_params.model)
		local source = agent == "user" and "You" or agent == "assistant" and model_config.model
		local lines = { string.format("%s (%s):", source, os.date("%H:%M")), "", "" }
		self.set_lines(lines)
	end

	self.set_cursor = function(line)
		if self._.winid and vim.api.nvim_win_is_valid(self._.winid) then
			line = line == 0 and 1 or line
			vim.api.nvim_win_set_cursor(self._.winid, { line, 0 })
		end
	end
end

function ChatRender:newline(new_lines)
	new_lines = new_lines or 1
	for _ = 1, new_lines do
		self._.line_nr = self._.line_nr + 1
		self._.line = ""
		self.set_lines({ self._.line, self._.line })
		self.set_cursor(self._.line_nr + 1)
	end
end

function ChatRender:set_winid(winid)
	self._.winid = winid
	self._.win_width = vim.api.nvim_win_get_width(winid)
end

function ChatRender:set_bufnr(bufnr)
	self._.bufnr = bufnr
end

function ChatRender:from_agent(identity)
	if not identity or not vim.tbl_contains({ "user", "assistant" }, identity) then
		return
	end
	self.identity_for(identity)
end

function ChatRender:lines(lines)
	self.set_lines(lines)
end

function ChatRender:summarize_prompt(lines)
	local message = table.concat(lines, "\n")
	local on_tokens = function(tokens)
		tokens = tokens or 0
		self._.tokens.user = tokens
		self._.tokens.total = self._.tokens.total + self._.tokens.user
		self.token_summary(self._.tokens.user)
		History:add_chat(message, self._.tokens)
	end
	utils.get_tokens(message, on_tokens)
	vim.cmd("silent! undojoin")
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
				self:newline()
			else
				append(_chunk)
			end
		end
	else
		append(chunk)
	end
end

function ChatRender:summarize_chat(chunks)
	self.insert_line()
	Events.pub("hook:request:complete", self._.lines)
	Log.trace(string.format("on_complete: chunks: %s", vim.inspect(chunks)))
	local on_tokens = function(tokens)
		tokens = tokens or 0
		self._.tokens.assistant = tokens
		self._.tokens.total = self._.tokens.total + self._.tokens.assistant
		self.token_summary(self._.tokens.assistant)
		History:add_chat(table.concat(chunks, ""), self._.tokens)
	end
	utils.get_tokens(chunks, on_tokens)
	vim.cmd("silent! undojoin")
end

function ChatRender:add_error(err)
	local message = err and err.error and err.error.message or type(err) == "string" and err or "Unknown error"
	local message_lines = { message }
	self.set_lines(message_lines)
	Log.trace(
		string.format("adding error highlight to chat buffer: %s, current_chat_line: %s", self._.bufnr, self._.line_nr)
	)
	vim.api.nvim_buf_add_highlight(self._.bufnr, -1, "ErrorMsg", self._.line_nr - #message_lines + 1, 0, -1)
	self._.line_nr = self._.line_nr + #message_lines + 1
	self.set_cursor(self._.line_nr)
	--  TODO: 2023-10-08 - display error summary (hr symbol without tokens)
	self:newline()
end

function ChatRender:from_history(file_path)
	local contents = utils.decode_json_from_path(file_path)
	for _, tbl in pairs(contents.messages) do
		if tbl.role == "user" then
			self:add_user({ tbl.message })
			-- self:summarize_prompt(tbl.message)
			vim.print(tbl.message)
			-- vim.print(self._.bufnr)
		end
		-- self:add_user({ tbl.messages })
		-- vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { message_tbls.role, "" })
		-- for line in message_tbls.message:gmatch("[^\n]+") do
		-- 	vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { line })
		-- end
		-- vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "" })
	end
end

return ChatRender
