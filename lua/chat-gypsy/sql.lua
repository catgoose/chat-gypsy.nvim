local plugin_opts = require("chat-gypsy").Config.get("plugin_opts")
local Log = require("chat-gypsy").Log

local Sql = {}
Sql.__index = Sql

function Sql:new()
	setmetatable(self, Sql)
	local uri = string.format("%s", vim.fn.stdpath("data"))
	self.sqlite = require("sqlite.db")
	self.db = self.sqlite:open(uri .. "/chat-gypsy.db", { open_mode = "rwc" })
	self.tbl = require("sqlite.tbl")
	Log.debug(string.format("Opened database %s", uri))
	self:initialize()
	return self
end

function Sql:initialize()
	local strftime = self.sqlite.lib.strftime
	self.db:create("sessions", {
		id = true,
		temperature = { type = "number", required = true },
		model = { type = "string", required = true },
		updatedAt = { type = "date", default = strftime("%s", "now") },
		createdAt = { type = "date", default = strftime("%s", "now") },
		name = { type = "string", default = "'Untitled chat'" },
		description = { type = "string", default = "'No description'" },
		keywords = { type = "string", default = "'default,untitled'" },
		active = { type = "integer", default = 0 },
		ensure = true,
	})
	self.db:create("messages", {
		id = true,
		role = { type = "string", required = true },
		tokens = { type = "integer", default = 0 },
		timestamp = { type = "date", default = strftime("%s", "now") },
		content = { type = "string", required = true },
		session = {
			type = "integer",
			reference = "sessions.id",
			on_delete = "cascade",
			on_update = "cascade",
		},
		ensure = true,
	})
end

function Sql:new_session(openai_params)
	local session = {
		temperature = openai_params.temperature,
		model = openai_params.model,
	}
	self.db:insert("sessions", session)
end

function Sql:get_sessions()
	local sessions = self.db:select("sessions")
	return sessions
end

return Sql
