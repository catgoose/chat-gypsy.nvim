local Log = require("chat-gypsy").Log
local Job = require("plenary.job")
local Path = require("plenary.path")

Utils = {}

Utils.generate_random_id = function(len)
	local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	local result = ""
	for _ = 1, len do
		local rand = math.random(#charset)
		result = result .. string.sub(charset, rand, rand)
	end
	return result
end

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

Utils.get_tokens = function(text, on_tokens)
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
	if on_tokens then
		local tokens = tonumber(output)
		on_tokens(tokens)
	end
end

Utils.tbl_to_json_string = function(table, indent_level)
	if type(table) == "table" then
		indent_level = indent_level or 1
		local indent = string.rep("  ", indent_level)
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

Utils.get_find_cmd = function()
	if vim.fn.executable("fdfind") == 1 then
		return {
			command = "fdfind",
			args = {
				"--type",
				"f",
				"--color",
				"never",
				"--exact-depth",
				"1",
				".",
			},
		}
	else
		Log.warn("No find utility found.  Install fdfind")
	end
end

Utils.find_files_in_directory = function(path, on_files_found, on_error)
	local find = Utils.get_find_cmd()
	local args = find.args
	args[#args + 1] = path

	local job = Job:new({
		command = find.command,
		args = args,
		on_exit = vim.schedule_wrap(function(response, exit_code)
			if exit_code == 0 then
				on_files_found(response:result())
			else
				on_error(string.format("Error: exit_code: %d", exit_code))
			end
		end),
		on_error = vim.schedule_wrap(function(err, data)
			on_error(string.format("Error: %s.  Command: %s. Args: %s. Data: %s", err, path, find.command, args, data))
		end),
	})
	job:start()
end

local read_file = function(path)
	return Path:new(path):read()
end

Utils.decode_json_from_path = function(file_path, on_error)
	local file = read_file(file_path)
	local ok, json = pcall(vim.json.decode, file)
	if ok and json then
		return json
	else
		on_error(string.format("Error parsing json from path: %s", file_path))
	end
end

return Utils
