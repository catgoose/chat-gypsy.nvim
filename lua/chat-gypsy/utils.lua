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

Utils.tbl_to_json_string = function(table, indent_level)
	if type(table) == "table" then
		indent_level = indent_level or 1
		local indent = string.rep("  ", indent_level) -- 2 spaces per level
		local json_str = "{\n"
		local comma = ""
		for k, v in pairs(table) do
			json_str = json_str .. comma .. indent .. '"' .. tostring(k) .. '": '
			if type(v) == "table" then
				json_str = json_str .. Utils.tbl_to_json_string(v, indent_level + 1)
			else
				json_str = json_str .. vim.json.encode(v)
			end
			comma = ",\n"
		end
		json_str = json_str .. "\n" .. string.rep("  ", indent_level - 1) .. "}"
		json_str = string.gsub(json_str, "\\", "")
		return json_str
	else
		local encoded_str = vim.json.encode(table)
		encoded_str = string.gsub(encoded_str, "\\", "")
		return encoded_str
	end
end

return Utils
