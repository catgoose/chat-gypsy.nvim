---@class Tokenizer
---@field public new fun(self): Tokenizer
---@field public init fun(self: Tokenizer)
---@field public calculate fun(self, message: string, role: Role, on_tokens: fun(tokens: Token))
---@field public set fun(self, tokens: Token)
---@field private perform_calculation fun(str: string, on_tokens_success: fun(message_tokens: number))
---@field private tokens Token

local Tokenizer = {}
Tokenizer.__index = Tokenizer

function Tokenizer:new()
	local instance = {}
	setmetatable(instance, Tokenizer)
	instance.tokens = {
		system = 0,
		user = 0,
		assistant = 0,
		total = 0,
	}
	self:init()
	return instance
end

---@language python
local tiktoken = [[
python3 << EOF
import tiktoken
encoder = tiktoken.get_encoding("cl100k_base")
encoded = encoder.encode("""%s""")
print(len(encoded))
EOF
]]

function Tokenizer:init()
	self.perform_calculation = function(message, on_tokens_success)
		local escaped_string = string.gsub(message, '"', '\\"')
		local ok, result = pcall(vim.api.nvim_exec2, string.format(tiktoken, escaped_string), { output = true })
		local output = 0
		if ok then
			output = result.output
		end
		if on_tokens_success then
			local message_tokens = tonumber(output) or 0
			on_tokens_success(message_tokens)
		end
	end
end

function Tokenizer:calculate(message, role, on_tokens)
	local on_tokens_success = function(message_tokens)
		self.tokens[role] = message_tokens
		self.tokens.total = self.tokens.total + self.tokens[role]
		on_tokens(self.tokens)
	end
	self.perform_calculation(message, on_tokens_success)
	vim.cmd("silent! undojoin")
	return self
end

function Tokenizer:set(tokens)
	self.tokens = tokens
end

return Tokenizer
