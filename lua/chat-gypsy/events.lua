--- Events event emitter
---@class Events
---@field sub fun(event: string, callback: fun(...))
---@field unsub fun(event: string, callback: fun(...))
---@field pub fun(event: string, ...)
local Events = {}
local listeners = {}

function Events.sub(event, callback)
	if not listeners[event] then
		listeners[event] = {}
	end
	table.insert(listeners[event], callback)
end

function Events.unsub(event, callback)
	if not listeners[event] then
		return
	end

	for i, cb in ipairs(listeners[event]) do
		if cb == callback then
			table.remove(listeners[event], i)
			return
		end
	end
end

function Events.pub(event, ...)
	if not listeners[event] then
		return
	end

	for _, callback in ipairs(listeners[event]) do
		callback(...)
	end
end

return Events
