local Log = require("chat-gypsy").Log

---@class Sqlite
---@field lib table
---@field open fun(uri: string, opts: table): Database
---@field Database Database

---@class Database
---@field eval fun(query: string, params: table): table
---@field create fun(tbl: string, schema: table): boolean
---@field insert fun(tbl: string, data: table): boolean
---@field update fun(tbl: string, data: table): boolean
---@field delete fun(tbl: string, data: table): boolean

---@class Table
---@field new fun(self: Table, db: Database, tbl: string): Table
---@field create fun(self: Table, schema: table): boolean
---@field insert fun(self: Table, data: table): boolean
---@field update fun(self: Table, data: table): boolean
---@field delete fun(self: Table, data: table): boolean

---@class Sql
---@field sqlite Sqlite
---@field db Database
---@field tbl Table
---@field status fun(success: boolean, err: string, data: any): table
---@field new fun(self: Sql): Sql
---@field initialize fun(self: Sql): nil
---@field cleanup fun(self: Sql): nil
---@field new_session fun(self: Sql, openai_params: table): table
---@field get_sessions fun(self: Sql): table
---@field get_messages_for_session fun(self: Sql, id: number): table
---@field insert_message fun(self: Sql, message: table): table
---@field session_summary fun(self: Sql, id: number, summary: table): table
---@field inactivate fun(self: Sql, id: number): table

local Sql = {}
Sql.__index = Sql

function Sql:new()
	setmetatable(self, Sql)
	local uri = string.format("%s", vim.fn.stdpath("data"))
	self.sqlite = require("sqlite.db")
	self.db = self.sqlite:open(uri .. "/chat-gypsy.db", { open_mode = "rwc" })
	self.tbl = require("sqlite.tbl")

	self.status = function(success, err, data)
		return {
			success = success,
			err = success and nil or err,
			data = data,
		}
	end

	Log.trace(string.format("Opened database %s", uri))
	self:initialize()
	-- self.db:update("sessions", { where = { active = 0 }, set = { active = 1 } })
	self:cleanup()
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
		initialized = { type = "integer", default = 0 },
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

function Sql:cleanup()
	self.db:delete("sessions", { initialized = 0 })
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
	local success = #created > 0
	local err = "No session created"
	return self.status(success, err, created[1].id)
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
  WHERE active = 1
  ORDER BY updatedAt DESC
  ]])
	local success = type(sessions) == "table"
	local err = "No sessions found"
	return self.status(success, err, sessions)
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
  WHERE active = 1
  AND session = :id
  ORDER BY m.time ASC
	 ]],
		{ id = id }
	)
	local success = type(messages) == "table" and #messages > 0
	local err = "No messages found"
	return self.status(success, err, messages)
end

function Sql:insert_message(message)
	local success = message.session and self.db:insert("messages", message)
	local err = not message.session and "No session id provided" or "No message inserted"
	return self.status(success, err, message)
end

function Sql:session_summary(id, summary)
	local success = id
		and summary
		and summary.name
		and summary.description
		and summary.keywords
		and self.db:update("sessions", {
			where = { id = id },
			set = {
				name = summary.name,
				description = summary.description,
				keywords = table.concat(summary.keywords, ","),
				updatedAt = os.time(),
				initialized = true,
				active = true,
			},
		})
	local err = not success and not id and "No session id provided"
		or not summary and "No summary provided"
		or not summary.name and "No name provided"
		or not summary.description and "No description provided"
		or not summary.keywords and "No keywords provided"
		or not success and "No session updated"
		or nil
	return self.status(success, err, summary)
end

function Sql:inactivate(id)
	local success = id and self.db:update("sessions", { where = { id = id }, set = { active = false } })
	local err = not success and not id and "No session id provided" or not success and "Error updating session" or nil
	return self.status(success, err, id)
end

return Sql
