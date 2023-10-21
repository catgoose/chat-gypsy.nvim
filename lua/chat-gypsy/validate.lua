local Log = require("chat-gypsy").Log

local Validate = {}

local logError = function(err_msg, throw)
	Log.error(err_msg)
	if throw then
		error(err_msg)
	end
end

Validate.openai_key = function(openai_key, throw)
	throw = throw or false
	if not openai_key or not (#openai_key > 0) then
		local err_msg =
			string.format("Missing OPENAI_API_KEY environment variable.  opts.openai: %s", vim.inspect(openai_key))
		logError(err_msg, throw)
		return false
	end
	return true
end

--  TODO: 2023-10-21 - Validate programmatically based on Config._opts
Validate.opts = function(o, throw)
	throw = throw or false
	vim.validate({
		{ o.openai, "t" },
		{ o.openai.openai_key, "s" },
		{ o.openai.openai_params, "t" },
		{ o.openai.openai_params.model, "s" },
		{ o.openai.openai_params.temperature, "n" },
		{ o.openai.openai_params.messages, "t" },
		{ o.openai.openai_params.messages[1], "t" },
		{ o.openai.openai_params.messages[1].role, "s" },
		{ o.openai.openai_params.messages[1].content, "s" },
		{ o.ui, "t" },
		{ o.ui.highlight, "t" },
		{ o.ui.highlight.role, "t" },
		{ o.ui.highlight.role.error, "s" },
		{ o.ui.highlight.role.system, "s" },
		{ o.ui.highlight.role.user, "s" },
		{ o.ui.highlight.role.assistant, "s" },
		{ o.ui.highlight.tokens, "s" },
		{ o.ui.highlight.error_message, "s" },
		{ o.ui.highlight.heading, "s" },
		{ o.ui.layout_placement, "s" },
		{ o.ui.prompt, "t" },
		{ o.ui.prompt.start_insert, "b" },
		{ o.ui.config, "t" },
		{ o.ui.config.zindex, "n" },
		{ o.ui.config.border, "t" },
		{ o.ui.config.border.style, "s" },
		{ o.ui.config.border.text, "t" },
		{ o.ui.config.border.text.top_align, "s" },
		{ o.ui.config.border.padding, "t" },
		{ o.ui.config.border.padding.top, "n" },
		{ o.ui.config.border.padding.left, "n" },
		{ o.ui.config.border.padding.right, "n" },
		{ o.ui.config.win_options, "t" },
		{ o.ui.config.win_options.cursorline, "b" },
		{ o.ui.config.win_options.winblend, "n" },
		{ o.ui.config.win_options.winhighlight, "s" },
		{ o.ui.config.win_options.wrap, "b" },
		{ o.ui.config.win_options.fillchars, "s" },
		{ o.ui.layout, "t" },
		{ o.ui.layout.left, "t" },
		{ o.ui.layout.left.prompt_height, "n" },
		{ o.ui.layout.left.size, "t" },
		{ o.ui.layout.left.size.width, "s" },
		{ o.ui.layout.left.size.height, "s" },
		{ o.ui.layout.left.position, "t" },
		{ o.ui.layout.left.position.row, "s" },
		{ o.ui.layout.left.position.col, "s" },
		{ o.ui.layout.right, "t" },
		{ o.ui.layout.right.prompt_height, "n" },
		{ o.ui.layout.right.size, "t" },
		{ o.ui.layout.right.size.width, "s" },
		{ o.ui.layout.right.size.height, "s" },
		{ o.ui.layout.right.position, "t" },
		{ o.ui.layout.right.position.row, "s" },
		{ o.ui.layout.right.position.col, "s" },
		{ o.ui.layout.center, "t" },
		{ o.ui.layout.center.prompt_height, "n" },
		{ o.ui.layout.center.prompt_max_lines, "n" },
		{ o.ui.layout.center.position, "t" },
		{ o.ui.layout.center.position.row, "s" },
		{ o.ui.layout.center.position.col, "s" },
		{ o.ui.layout.center.size, "t" },
		{ o.ui.layout.center.size.width, "s" },
		{ o.ui.layout.center.size.height, "s" },
		{ o.hooks, "t" },
		{ o.hooks.request, "t" },
		{ o.hooks.request.start, "f" },
		{ o.hooks.request.chunk, "f" },
		{ o.hooks.request.complete, "f" },
		{ o.hooks.request.error, "f" },
		{ o.hooks.models, "t" },
		{ o.hooks.models.get, "f" },
		{ o.hooks.models.error, "f" },
		{ o.hooks.entries, "t" },
		{ o.hooks.entries.start, "f" },
		{ o.hooks.entries.complete, "f" },
		{ o.dev_opts, "t" },
		{ o.dev_opts.prompt, "t" },
		{ o.dev_opts.prompt.user_prompt, "s" },
		{ o.dev_opts.prompt.enabled, "b" },
		{ o.dev_opts.request, "t" },
		{ o.dev_opts.request.throw_error, "b" },
		{ o.dev_opts.request.error, "s" },
	})
end

return Validate
