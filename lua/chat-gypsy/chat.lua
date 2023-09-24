Chat = {}
local generate_random_id = function()
	local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	local result = ""

	for _ = 1, 8 do
		local rand = math.random(#charset)
		result = result .. string.sub(charset, rand, rand)
	end

	return result
end

Chat.history = {}

Chat.add = function(prompt_message, response_message, tokens_tbl)
	if not Chat.history.id then
		Chat.history = {
			id = generate_random_id(),
			createdAt = os.time(),
			updatedAt = os.time(),
			messages = {},
		}
	end
	table.insert(Chat.history.messages, {
		type = "prompt",
		message = prompt_message,
		time = os.time(),
		tokens = tonumber(tokens_tbl.prompt),
	})
	table.insert(Chat.history.messages, {
		type = "response",
		message = response_message,
		time = os.time(),
		tokens = tonumber(tokens_tbl.response),
	})
	Chat.history.updatedAt = os.time()
end

return Chat
