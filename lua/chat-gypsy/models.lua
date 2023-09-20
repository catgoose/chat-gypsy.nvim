local config = require("chat-gypsy.config")
local openai_models = config.openai_models
local opts = config.opts
local Log = require("chat-gypsy").Log
local curl = require("plenary.curl")

Models = {}

local getModels = function()
	local models = {}
	local handler = curl.get({
		url = "https://api.openai.com/v1/models",
		headers = {
			content_type = "application/json",
			Authorization = "Bearer " .. opts.openai_key,
		},
		callback = function(response)
			local body = vim.json.decode(response.body)

			if response.status ~= 200 then
				error(vim.inspect(body))
			else
				if body.data then
					for _, model in ipairs(body.data) do
						table.insert(models, model.id)
					end
				end
			end
		end,
	})
	handler:after_success(function()
		local model_priority = {}
		for _, m in ipairs(openai_models) do
			model_priority[m.model] = m.priority
		end
		models = vim.tbl_filter(function(model)
			return model_priority[model] ~= nil
		end, models)
		table.sort(models, function(a, b)
			return model_priority[a] < model_priority[b]
		end)
		Log.debug("getModels: success: " .. vim.inspect(models))
		M.names = models
	end)
end

M.init = function()
	getModels()
end

M.names = {}

return M
