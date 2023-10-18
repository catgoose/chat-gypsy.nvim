local Log = require("chat-gypsy").Log

local Sql = {}
Sql.__index = Sql

function Sql:new()
	setmetatable(self, Sql)
	local uri = string.format("%s", vim.fn.stdpath("data"))
	self.sqlite = require("sqlite.db")
	self.db = self.sqlite:open(uri .. "/chat-gypsy.db", { open_mode = "rwc" })
	self.tbl = require("sqlite.tbl")
	Log.trace(string.format("Opened database %s", uri))
	self:initialize()
	return self
end

--  TODO: 2023-10-18 - check if database is locked
function Sql:initialize()
	local strftime = self.sqlite.lib.strftime
	-- self.db:drop("sessions")
	-- self.db:drop("messages")
	self.db:create("sessions", {
		id = true,
		temperature = { type = "number", required = true },
		model = { type = "string", required = true },
		updatedAt = { type = "date", default = strftime("%s", "now") },
		createdAt = { type = "date", default = strftime("%s", "now") },
		--  TODO: 2023-10-18 - this is duplicated in request
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
		time = { type = "date", default = strftime("%s", "now") },
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
	local created = self.db:eval(
		[[
    INSERT INTO sessions (temperature, model)
    VALUES (:temperature, :model)
    returning id;
  ]],
		{ temperature = openai_params.temperature, model = openai_params.model }
	)
	if #created > 0 then
		return created[1].id
	else
		return nil
	end
end

function Sql:get_sessions()
	local sessions = self.db:eval([[
  SELECT
    s.id
    , s.temperature
    , s.model
    , s.name
    , s.description
    , s.keywords
  FROM sessions s
  WHERE active = 0
  ORDER BY updatedAt DESC
  ]])
	return sessions
end

function Sql:get_messages_for_session(id)
	local messages = self.db:eval(
		[[
  SELECT
    m.role
    , m.tokens
    , m.time
    , m.content
  FROM messages m
  LEFT JOIN sessions s ON s.id = m.session
  WHERE active = 0
  AND session = :id
  ORDER BY m.time ASC
	 ]],
		{ id = id }
	)
	return messages
end

function Sql:insert_message(message)
	self.db:insert("messages", message)
end

function Sql:touch_session(id)
	self.db:update("sessions", {
		where = { id = id },
		set = { updatedAt = os.time() },
	})
end

function Sql:session_summary(id, summary)
	local keywords = table.concat(summary.keywords, ",")
	self.db:update("sessions", {
		where = { id = id },
		set = {
			name = summary.name,
			description = summary.description,
			keywords = keywords,
		},
	})
	self:touch_session(id)
end

return Sql
