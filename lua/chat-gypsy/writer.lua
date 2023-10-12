local History = require("chat-gypsy").History
local Config = require("chat-gypsy").Config
local models = require("chat-gypsy.models")
local opts, symbols = Config.get("opts"), Config.get("symbols")
local utils = require("chat-gypsy.utils")

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
		tokens = {
			system = 0,
			user = 0,
			assistant = 0,
			total = 0,
		},
	}
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
	self.set_lines = function(lines)
		if type(lines) == "string" then
			lines = { lines }
		end
		if self._.bufnr and vim.api.nvim_buf_is_valid(self._.bufnr) then
			vim.api.nvim_buf_set_lines(self._.bufnr, self._.row - 1, -1, false, lines)
			self._.row = self._.row + #lines - 1
			self:set_cursor()
		end
	end

	self.format_role = function(role)
		if not role or not utils.check_roles(role, true) then
			return
		end
		local model_config = models.get_config(opts.openai_params.model)
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

	self.newline = function(new_lines)
		new_lines = new_lines or 1
		for _ = 1, new_lines do
			self._.line = ""
			self._.row = self._.row + 1
			self.set_lines(self._.line)
		end
		return self
	end
end

function Writer:set_cursor()
	if self._.winid and vim.api.nvim_win_is_valid(self._.winid) and self.move_cursor then
		vim.api.nvim_win_set_cursor(self._.winid, { self._.row, 0 })
	end
end

function Writer:newlines()
	self.newline(2)
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

function Writer:from_role(role, time)
	if not utils.check_roles(role, true) then
		return self
	end
	time = time or os.time()
	local role_display = self.format_role(role)
	local date = self.date(time, "%m/%d/%Y %I:%M%p")
	local line = string.format("%s%s%s", role_display, (" "):rep(self._.win_width - #role_display - #date), date)
	self.set_lines(line)
	self:highlight(role, line)
	return self
end

function Writer:highlight(role, lines)
	vim.api.nvim_buf_add_highlight(self._.bufnr, -1, opts.ui.highlight.role[role], self._.row - #{ lines }, 0, -1)
	return self
end

function Writer:lines(lines)
	if not lines then
		return self
	end
	if type(lines) == "string" then
		lines = utils.string_split(lines, "\n")
	end
	self.set_lines(lines)
	return self
end

function Writer:calculate_tokens(message, role)
	if not utils.check_roles(role) then
		return self
	end
	message = message or ""
	message = type(message) == "table" and table.concat(message, "") or message
	local on_tokens = function(tokens)
		tokens = tokens or 0
		self._.tokens[role] = tokens
		self._.tokens.total = self._.tokens.total + self._.tokens[role]
		self:token_summary(self._.tokens, role)
		History:add_message(message, role, self._.tokens)
	end
	utils.get_tokens(message, on_tokens)
	vim.cmd("silent! undojoin")
	return self
end

function Writer:token_summary(tokens, role)
	local model_config = models.get_config(opts.openai_params.model)
	local tokens_display = string.format(
		" %s %s (%s/%s) %s",
		symbols.left_arrow,
		tokens[role],
		tokens.total,
		model_config.max_tokens,
		symbols.right_arrow
	)
	local summary = string.format("%s%s", symbols.horiz:rep(self._.win_width - #tokens_display + 4), tokens_display)
	self.set_lines(summary)
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
				self.newline()
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
	self.set_lines(message)
	self:highlight("error", message)
	return self
end

return Writer
