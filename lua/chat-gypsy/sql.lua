local plugin_opts = require("chat-gypsy").Config.get("plugin_opts")
local Log = require("chat-gypsy").Log

local Sql = {}
Sql.__index = Sql

function Sql:new()
	setmetatable(self, Sql)
	self.sqlite = require("sqlite.db")
	self.tbl = require("sqlite.tbl")
	self.uri = string.format("%s/%s", vim.fn.stdpath("data"), plugin_opts.name)
	self.db = self.sqlite:open(self.uri .. "/chat-gypsy.db", { open_mode = "rwc" })
	Log.debug(string.format("Opened database %s", self.uri))
	self:check_tables()
	return self
end

function Sql:check_tables()
	self.db:create("sessions", {
		id = true,
		updatedAt = { type = "integer" },
		createdAt = { type = "integer" },
		ensure = true,
	})
	self.db:create("messages", {
		id = true,
		updatedAt = { type = "integer" },
		createdAt = { type = "integer" },
		session = {
			type = "integer",
			foreign_key = {
				table = "sessions",
				key = "id",
				on_delete = "cascade",
				on_update = "cascade",
			},
		},
		ensure = true,
	})

	self.db:insert("sessions", {
		updatedAt = os.time(),
		createdAt = os.time(),
	})

	local sessions = self.db:select("sessions")
	vim.print(sessions)
end

function Sql:drop()
	self.db:drop("sessions")
	self.db:drop("messages")
end

return Sql
