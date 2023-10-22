local Validate = {}

Validate.openai_key = function(openai_key)
	if not openai_key or not (#openai_key > 0) then
		local err_msg =
			string.format("Missing OPENAI_API_KEY environment variable.  opts.openai: %s", vim.inspect(openai_key))
		error(err_msg)
		return false
	end
	return true
end

--  TODO: 2023-10-22 - How to handle opts types that can be of multiple
--  types?
local function validateTable(t, _t, path)
	path = path or ""
	for k, v in pairs(t) do
		local newPath = (#path > 0 and (path .. "." .. k)) or k
		local templateValue = _t[k]

		if templateValue == nil then
			error(string.format("Invalid k: %s", newPath))
		end

		local vType, templateType = type(v), type(templateValue)

		if vType ~= templateType then
			error(string.format("Type mismatch at opts.%s:\nexpected %s\ngot %s", newPath, templateType, vType))
		end

		if vType == "table" then
			validateTable(v, templateValue, newPath)
		end
	end
end

Validate.opts = function(t, _t)
	validateTable(t, _t)
end

return Validate
