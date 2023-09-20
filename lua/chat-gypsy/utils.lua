Utils = {}

Utils.deepcopy = function(orig)
	local t = type(orig)
	local copy
	if t == "table" then
		copy = {}
		for k, v in pairs(orig) do
			copy[k] = Utils.deepcopy(v)
		end
	else
		copy = orig
	end
	return copy
end

Utils.calculate_tokens = function(text, on_tokens)
	on_tokens = on_tokens or function(_) end
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
			text
		),
		{ output = true }
	)
	local output = 0
	if ok then
		output = result.output
	end
	on_tokens(output)
end

return Utils
