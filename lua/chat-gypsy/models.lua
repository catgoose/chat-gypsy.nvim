local Config = require("chat-gypsy").Config
local Events = require("chat-gypsy").Events
local openai_models = Config.get("openai_models")
local opts = Config.get("opts")
local Log = require("chat-gypsy").Log
local curl = require("plenary.curl")
local validate = require("chat-gypsy.validate")

local Models = {}

local get_models = function()
	curl.get({
		url = "https://api.openai.com/v1/models",
		headers = {
			content_type = "application/json",
			Authorization = "Bearer " .. opts.openai.openai_key,
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
					if #models > 0 then
						Log.debug("getModels: success: " .. vim.inspect(models))
						Events.pub("hook:models:get", models)
					end
				end
			end
		end,
	})
end

Models.init = function()
	if not validate.openai_key(opts.openai.openai_key) then
		return
	end
	get_models()
end

Models.names = {}

Models.get_config = function(model)
	local found_model = vim.tbl_filter(function(m)
		return m.model == model
	end, openai_models)
	if not vim.tbl_contains(Models.names, model) or not model or not found_model then
		return {
			model = "no-model-found",
			max_tokens = 0,
			priority = 1,
		}
	end
	return found_model[1]
end

return Models
