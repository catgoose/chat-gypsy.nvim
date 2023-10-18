local Log = require("chat-gypsy").Log

local History = {}
History.__index = History

function History:new()
	setmetatable(self, History)
	self.session_id = -1
	self.sql = require("chat-gypsy.sql"):new()
	self:init()
	return self
end

function History:set_session_id(id)
	self.session_id = id
end

function History:init_current()
	self.session_id = -1
	self.current = {
		id = 0,
		createdAt = os.time(),
		updatedAt = os.time(),
		messages = {},
		openai_params = {},
		entries = {
			keywords = {},
		},
	}
end

function History:init()
	self:init_current()

	self.sort_keywords = function()
		local keywords = self.current.entries.keywords
		table.sort(keywords, function(a, b)
			return a < b
		end)
		self.current.entries.keywords = keywords
	end
end

function History:compose_entries(request)
	local on_complete = function()
		Log.debug(string.format("Composed entries for History id %s", self.current.id))
		self.sort_keywords()
		if self.session_id > 0 then
			self.sql:session_summary(self.session_id, self.current.entries)
		end
	end
	if #self.current.messages > 0 then
		--  NOTE: 2023-10-18 - It seems that the current history should be stored as
		--  state until the float is unmounted and written to db
		request:compose_entries(self.current, on_complete)
	end
end

function History:add_message(content, role, tokens)
	if self.session_id > 0 then
		local message = {
			role = role,
			content = content,
			time = os.time(),
			tokens = tokens[role],
			session = self.session_id,
		}
		self.sql:insert_message(message)
	end
end

return History
