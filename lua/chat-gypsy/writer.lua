---@class WriterState
---@field winid number
---@field bufnr number
---@field win_width number
---@field line string
---@field row number

---@class Writer
---@field public new fun(cfg: { winid: number, bufnr: number }): Writer
---@field public reset fun(): Writer
---@field public set_move_cursor fun(state: boolean): Writer
---@field public init fun(): Writer
---@field public set_cursor fun(): Writer
---@field public newline fun(new_lines: number): Writer
---@field public newlines fun(): Writer
---@field public set_winid fun(winid: number): Writer
---@field public set_bufnr fun(bufnr: number): Writer
---@field public from_role fun(role: Role, model: string, time: number): Writer
---@field public lines fun(lines: string[]|string, highlight_cfg: { hlgroup: string, col_start: number }): Writer
---@field public heading fun(lines: string[]|string): Writer
---@field public calculate_tokens fun(content: string, role: Role, model: string): Writer
---@field public replay_tokens fun(tokens: Token[], role: Role, model: string): Writer
---@field public token_summary fun(tokens: Token[], role: Role, model: string): Writer
---@field public horiz_line fun(): Writer
---@field public append_chunk fun(chunk: string): Writer
---@field public error fun(err: string|{ error: { message: string } }): Writer
---@field private tokenizer Tokenizer
---@field private _ WriterState
---@field private format_role fun(role: Role, model: string): string
---@field private date fun(time: number, format: string): string
---@field private move_cursor boolean
---@field private is_buf fun(): boolean
---@field private set_lines fun(lines: string[]|string): Writer
---@return Writer

local History = require("chat-gypsy").History
local Config = require("chat-gypsy").Config
local Models = require("chat-gypsy.models")
local opts, symbols = Config.get("opts"), Config.get("symbols")
local Utils = require("chat-gypsy.utils")

local Writer = {}
Writer.__index = Writer

function Writer:new(cfg)
	local instance = {}
	setmetatable(instance, Writer)
	cfg = cfg or {
		winid = nil,
		bufnr = nil,
	}
	cfg.winid = cfg.winid or nil
	cfg.bufnr = cfg.bufnr or nil
	instance._ = {
		winid = cfg.winid,
		bufnr = cfg.bufnr,
		win_width = cfg.winid and vim.api.nvim_win_get_width(cfg.winid) or 0,
	}
	instance.tokenizer = require("chat-gypsy.tokenizer"):new()
	instance.move_cursor = true
	instance:reset()
	instance:init()
	return instance
end

function Writer:reset()
	self._.line = ""
	self._.row = 1
	return self
end

function Writer:set_move_cursor(state)
	if state == true then
		self.move_cursor = state
	end
	if state == false then
		self.move_cursor = state
	end
	return self
end

function Writer:init()
	self.is_buf = function()
		return self._.bufnr and vim.api.nvim_buf_is_valid(self._.bufnr)
	end

	self.set_lines = function(lines)
		if type(lines) ~= "table" then
			lines = { tostring(lines) }
		end
		if self.is_buf() then
			vim.api.nvim_buf_set_lines(self._.bufnr, self._.row - 1, -1, false, lines)
			self._.row = self._.row + #lines - 1
			self:set_cursor()
		end
		return self
	end

	self.format_role = function(role, model)
		if not role or not Utils.check_roles(role, true) then
			return
		end
		local model_config = Models.get_config(model)
		local source = role == "user" and "You"
			or role == "assistant" and model_config.model
			or role == "system" and "System"
			or role == "error" and "Error"
		return string.format("%s", source)
	end

	self.date = function(time, format)
		time = time or os.time()
		format = format or "%I:%M %p"
		local date = os.date(format, time)
		return date
	end
end

function Writer:set_cursor()
	if self._.winid and vim.api.nvim_win_is_valid(self._.winid) and self.move_cursor then
		vim.api.nvim_win_set_cursor(self._.winid, { self._.row, 0 })
	end
end

function Writer:newline(new_lines)
	new_lines = new_lines or 1
	for _ = 1, new_lines do
		self._.line = ""
		self._.row = self._.row + 1
		self.set_lines(self._.line)
	end
	return self
end

function Writer:newlines()
	self:newline(2)
	return self
end

function Writer:set_winid(winid)
	self._.winid = winid
	self._.win_width = vim.api.nvim_win_get_width(winid)
	return self
end

function Writer:set_bufnr(bufnr)
	self._.bufnr = bufnr
	return self
end

function Writer:from_role(role, model, time)
	if not Utils.check_roles(role, true) then
		return self
	end
	time = time or os.time()
	local role_format = self.format_role(role, model)
	local date = self.date(time, "%m/%d/%Y %I:%M%p")
	local line = string.format("%s%s%s", role_format, (" "):rep(self._.win_width - #role_format - #date), date)
	self:lines(line, { hlgroup = opts.ui.highlight.role[role] })
	return self
end

function Writer:lines(lines, highlight_cfg)
	if not lines then
		return self
	end
	if type(lines) == "string" then
		lines = Utils.string_to_lines_tbl(lines)
	end
	self.set_lines(lines)
	if highlight_cfg and highlight_cfg.hlgroup and self.is_buf() then
		highlight_cfg.col_start = highlight_cfg.col_start or 0
		vim.api.nvim_buf_add_highlight(
			self._.bufnr,
			-1,
			highlight_cfg.hlgroup,
			self._.row - #lines,
			highlight_cfg.col_start,
			-1
		)
	end
	return self
end

function Writer:heading(lines)
	if not lines then
		return self
	end
	lines = Utils.string_to_lines_tbl(lines)
	self:lines(lines, { hlgroup = opts.ui.highlight.heading })
	return self
end

function Writer:calculate_tokens(content, role, model)
	if not Utils.check_roles(role) then
		return self
	end
	content = type(content) == "table" and table.concat(content, "") or content
	local on_tokens = function(tokens)
		self:token_summary(tokens, role, model)
		History:add_message(content, role, tokens)
	end
	self.tokenizer:calculate(content, role, on_tokens)
	vim.cmd("silent! undojoin")
	return self
end

function Writer:replay_tokens(tokens, role, model)
	tokens = Utils.deep_copy(tokens)
	self.tokenizer:set(tokens)
	self:token_summary(tokens, role, model)
	vim.cmd("silent! undojoin")
	return self
end

function Writer:token_summary(tokens, role, model)
	local model_config = Models.get_config(model)
	local token_format = string.format(" %s (%s/%s) ", tokens[role], tokens.total, model_config.max_tokens)
	local summary = string.format("%s%s", symbols.space:rep(self._.win_width - #token_format), token_format)
	self:lines(summary, { hlgroup = opts.ui.highlight.tokens, col_start = self._.win_width - #token_format })
		:horiz_line()
	return self
end

function Writer:horiz_line()
	self.set_lines(symbols.horiz:rep(self._.win_width))
	return self
end

function Writer:append_chunk(chunk)
	local append = function(_chunk)
		self._.line = self._.line .. _chunk
		self.set_lines(self._.line)
	end
	if string.match(chunk, "\n") then
		for _chunk in chunk:gmatch(".") do
			if string.match(_chunk, "\n") then
				self:newline()
			else
				append(_chunk)
			end
		end
	else
		append(chunk)
	end
end

function Writer:error(err)
	local message = err and err.error and err.error.message or type(err) == "string" and err or "Unknown error"
	self:lines(message, { hlgroup = opts.ui.highlight.role.error })
	return self
end

return Writer
