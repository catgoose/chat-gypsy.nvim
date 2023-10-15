local Tokens = {}
Tokens.__index = Tokens

function Tokens:new()
	local instance = {}
	setmetatable(instance, Tokens)
	instance._ = {
		tokens = {
			system = 0,
			user = 0,
			assistant = 0,
			total = 0,
		},
	}
	self:init()
	return instance
end

function Tokens:init()
	self.get_tokens = function(string, on_tokens_success)
		local escaped_string = string.gsub(string, '"', '\\"')
		local ok, result = pcall(
			vim.api.nvim_exec2,
			string.format(
				[[
python3 << EOF
import tiktoken
encoder = tiktoken.get_encoding("cl100k_base")
encoded = encoder.encode("""%s""")
print(len(encoded))
EOF
]],
				escaped_string
			),
			{ output = true }
		)
		local output = 0
		if ok then
			output = result.output
		end
		if on_tokens_success then
			local tokens = tonumber(output)
			on_tokens_success(tokens)
		end
	end
end

function Tokens:calculate(message, role, on_tokens)
	local on_tokens_success = function(tokens)
		tokens = tokens or 0
		self._.tokens[role] = tokens
		self._.tokens.total = self._.tokens.total + self._.tokens[role]
		on_tokens(self._.tokens)
	end
	self.get_tokens(message, on_tokens_success)
	vim.cmd("silent! undojoin")
	return self
end

return Tokens
