local config = require("chat-gypsy.config")
local openai_models = config.openai_models
local opts = config.opts
local Log = require("chat-gypsy").Log
local curl = require("plenary.curl")
local Events = require("chat-gypsy").Events

Models = {}

local get_models = function()
	curl.get({
		url = "https://api.openai.com/v1/models",
		headers = {
			content_type = "application/json",
			Authorization = "Bearer " .. opts.openai_key,
		},
		callback = function(response)
			if response.status ~= 200 then
				local ok, err = pcall(vim.json.decode, response.body)
				if ok then
					if err.error then
						err.error.http_status = response.status
					end
					Events:pub("hook:request:error", "get_models", err)
					if type(err) == "table" then
						err = vim.inspect(err)
					end
					Log.error(string.format("get_models: error: %s", err))
					error(err)
				end
				Models.success = false
			else
				local body = vim.json.decode(response.body)
				if body.data then
					local models = {}
					for _, model in ipairs(body.data) do
						table.insert(models, model.id)
					end
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
					if #models > 0 then
						M.names = models
						M.success = true
					end
				end
			end
		end,
	})
end

M.init = function()
	get_models()
end

M.names = {}
M.success = false

return M
