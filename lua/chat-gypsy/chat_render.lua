local History = require("chat-gypsy").History
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
	}
	self.move_cursor = true
	self:reset()
	self:init()
	return self
end

function ChatRender:reset()
	self._.line = ""
	self._.lines = {}
	self._.row = 1
	return self
end

function ChatRender:set_move_cursor(state)
	if state == true then
		self.move_cursor = state
	end
	if state == false then
		self.move_cursor = state
	end
	return self
end

function ChatRender:init()
	self.set_lines = function(lines)
		if type(lines) == "string" then
			lines = { lines }
		end
		if self._.bufnr and vim.api.nvim_buf_is_valid(self._.bufnr) then
			vim.api.nvim_buf_set_lines(self._.bufnr, self._.row - #lines, -1, false, lines)
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
		local summary = symbols.horiz:rep(self._.win_width - #tokens_display + 4) .. tokens_display
		local lines = { summary }
		self.set_lines(lines)
	end

	self.identity_for = function(agent, override)
		local model_config = models.get_config(opts.openai_params.model)
		local source = override and override
			or agent == "user" and "You"
			or agent == "assistant" and model_config.model
			or agent == "error" and "Error"
		local lines = { string.format("%s (%s):", source, os.date("%H:%M")) }
		--  TODO: 2023-10-08 - add highlighting for each agent type
		self.set_lines(lines)
	end

	self.set_cursor = function(line)
		if self._.winid and vim.api.nvim_win_is_valid(self._.winid) then
			vim.api.nvim_win_set_cursor(self._.winid, { line, 0 })
		end
	end
end

function ChatRender:newline(new_lines)
	new_lines = new_lines or 1
	for _ = 1, new_lines do
		self._.row = self._.row + 1
		self._.line = ""
		self.set_lines(self._.line)
		if self.move_cursor then
			self.set_cursor(self._.row)
		end
	end
	return self
end

function ChatRender:set_winid(winid)
	self._.winid = winid
	self._.win_width = vim.api.nvim_win_get_width(winid)
	return self
end

function ChatRender:set_bufnr(bufnr)
	self._.bufnr = bufnr
	return self
end

function ChatRender:agent(identity, override)
	if not identity or not vim.tbl_contains({ "user", "assistant", "error" }, identity) then
		return
	end
	self.identity_for(identity, override)
	self:newline()
	return self
end

function ChatRender:lines(lines)
	self.set_lines(lines)
	self:newline()
	return self
end

function ChatRender:calculate_tokens(agent, data)
	if not vim.tbl_contains({ "user", "assistant" }, agent) then
		return
	end
	local delimin_char = agent == "user" and "\n" or agent == "assistant" and "" or nil
	local message = table.concat(data, delimin_char)
	local on_tokens = function(tokens)
		tokens = tokens or 0
		self._.tokens[agent] = tokens
		self._.tokens.total = self._.tokens.total + self._.tokens[agent]
		self.token_summary(self._.tokens[agent])
		History:add_message(message, agent, self._.tokens)
	end
	utils.get_tokens(message, on_tokens)
	vim.cmd("silent! undojoin")
	self:newline()
	return self
end

function ChatRender:add_lines_by_chunks(chunk)
	local append = function(_chunk)
		self._.line = self._.line .. _chunk
		self.set_lines(self._.line)
		self.set_cursor(self._.row)
	end
	if string.match(chunk, "\n") then
		for _chunk in chunk:gmatch(".") do
			if string.match(_chunk, "\n") then
				table.insert(self._.lines, self._.line)
				self:newline()
			else
				append(_chunk)
			end
		end
	else
		append(chunk)
	end
end

function ChatRender:add_error(err)
	local message = err and err.error and err.error.message or type(err) == "string" and err or "Unknown error"
	local message_lines = { message }
	self.set_lines(message_lines)
	vim.api.nvim_buf_add_highlight(self._.bufnr, -1, "ErrorMsg", self._.row - #message_lines, 0, -1)
	self:newline()
	return self
end

function ChatRender:from_history(file_path)
	local contents = utils.decode_json_from_path(file_path)
	local model = contents.openai_params.model
	for _, messages in pairs(contents.messages) do
		if messages.role == "user" then
			self:agent(messages.role):newline(2)
			self:lines(messages.message):newline()
		end
		if messages.role == "assistant" then
			self:agent(messages.role, model):newline(2)
			local message = utils.string_split(messages.message, "\n")
			self:lines(message):newline()
		end
	end
end

return ChatRender
