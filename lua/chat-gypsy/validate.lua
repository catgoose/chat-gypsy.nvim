--- Validate module for chat-gypsy
---@class Validate
---@field openai_key fun(openai_key: string): boolean
---@field opts fun(t: table, _t: table)
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

local ui_layout_types = { "string", "number" }
local overrides = {
	["ui.layout.left.size.width"] = ui_layout_types,
	["ui.layout.left.size.height"] = ui_layout_types,
	["ui.layout.left.position.row"] = ui_layout_types,
	["ui.layout.left.position.col"] = ui_layout_types,
	["ui.layout.right.size.width"] = ui_layout_types,
	["ui.layout.right.size.height"] = ui_layout_types,
	["ui.layout.right.position.row"] = ui_layout_types,
	["ui.layout.right.position.col"] = ui_layout_types,
	["ui.layout.center.size.width"] = ui_layout_types,
	["ui.layout.center.size.height"] = ui_layout_types,
	["ui.layout.center.position.row"] = ui_layout_types,
	["ui.layout.center.position.col"] = ui_layout_types,
}

local validateError = function(path, expectedType, gotType)
	error(string.format("Type mismatch at opts.%s:\nexpected %s\ngot %s", path, expectedType, gotType))
end

local function validateTable(t, _t, path)
	path = path or ""
	for k, v in pairs(t) do
		local newPath = (#path > 0 and (path .. "." .. k)) or k
		local templateValue = _t[k]

		if templateValue == nil then
			error(string.format("Invalid k: %s", newPath))
		end

		local vType, templateType = type(v), type(templateValue)

		if overrides[newPath] and not vim.tbl_contains(overrides[newPath], vType) then
			validateError(
				newPath,
				#overrides[newPath] == 1 and overrides[newPath] or table.concat(overrides[newPath], " or "),
				vType
			)
		elseif vType ~= templateType then
			validateError(newPath, templateType, vType)
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
