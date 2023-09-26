local Config = require("chat-gypsy").Config
local openai_models = Config.openai_models
local opts = Config.opts
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
					Events.pub("hook:models:error", "get_models", err)
					if type(err) == "table" then
						err = vim.inspect(err)
					end
					Log.error(string.format("get_models: error: %s", err))
					error(err)
				end
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
					Log.trace("getModels: success: " .. vim.inspect(models))
					Events.pub("hook:models:get", models)
					if #models > 0 then
						M.names = models
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

M.get_config = function(model)
	local found_model = vim.tbl_filter(function(m)
		return m.model == model
	end, openai_models)
	if not vim.tbl_contains(M.names, model) or not model or not found_model then
		return {
			model = "no_model_found",
			max_tokens = 0,
			priority = 1,
		}
	end
	return found_model[1]
end

return M
