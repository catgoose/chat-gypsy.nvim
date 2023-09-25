local Events = {}
Events.__index = Events

function Events:new()
	setmetatable(self, Events)
	self.listeners = {}
	return self
end

function Events:sub(event, callback)
	if not self.listeners[event] then
		self.listeners[event] = {}
	end
	table.insert(self.listeners[event], callback)
end

function Events:unsub(event, callback)
	if not self.listeners[event] then
		return
	end

	for i, cb in ipairs(self.listeners[event]) do
		if cb == callback then
			table.remove(self.listeners[event], i)
			return
		end
	end
end

function Events:pub(event, ...)
	if not self.listeners[event] then
		return
	end

	for _, callback in ipairs(self.listeners[event]) do
		callback(...)
	end
end

return Events
