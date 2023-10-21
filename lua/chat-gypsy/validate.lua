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

local function validateTable(o, _o, throw, path)
	path = path or ""
	for key, value in pairs(o) do
		local newPath = (#path > 0 and (path .. "." .. key)) or key
		local templateValue = _o[key]

		if templateValue == nil then
			error(string.format("Invalid key: %s", newPath), throw)
		end

		local valueType, templateType = type(value), type(templateValue)

		if valueType ~= templateType then
			error(string.format("Type mismatch at %s:\nexpected %s\ngot %s", newPath, templateType, valueType), throw)
		end

		if valueType == "table" then
			validateTable(value, templateValue, newPath)
		end
	end
end

Validate.opts = function(o, _o)
	validateTable(o, _o)
end

return Validate
