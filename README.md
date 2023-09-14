# Gypsy

## Usage

### Calling with `:lua require('chat-gypsy)...`

```lua
require('chat-gypsy').toggle()
require("chat-gypsy").open()
require("chat-gypsy").close()
require("chat-gypsy").hide()
require("chat-gypsy").show()
```

### Calling with vim user commands

```lua
GypsyToggle
GypsyOpen
GypsyClose
GypsyHide
GypsyShow
```

- Opens prompt/chat popup that can be used interact with Openai
- Chat is destroyed with 'q' in normal mode
- Chat history is saved until chat window is destroyed
- Calling `require('chat-gypsy').toggle()` will toggle chat window.
  - If chat window is not focused on `toggle` is called it will focus the chat.

Presently only one chat window and one request can be active at once. If a
prompt is sent and the window destroyed, the next chat request will not be
sent until the previous request is completed.

Likewise, if a response is being generated the next prompt can be sent, but
it will not clear the prompt buffer until the previous request is completed.

## Installation

### Lazy.nvim

```lua
-- defaults
local opts = {
    openai_key = os.getenv("OPENAI_API_KEY"),
    openai_params = {
        model = "gpt-3.5-turbo",
        messages = {
            {
            role = "system",
            content = "",
            },
        },
    },
    log_level = "warn", -- trace, debug, info, warn, error, fatal
    ui = {
        prompt = {
            start_insert = true,
        },
    },
}

return {
    opts = opts,
    dependencies = {
        "nvim-lua/plenary.nvim",
        "MunifTanjim/nui.nvim",
    },
    keys = {
        {
            "<leader>x",
            "<cmd>GypsyToggle<cr>"
            --"<cmd>lua require('chat-gypsy').toggle()<cr>",
            desc = "Gypsy",
            mode = { "n" }
        },
    },
    cmd = {
        "GypsyToggle",
        "GypsyOpen",
        "GypsyClose",
        "GypsyOpen",
        "GypsyCLose"
    }
}
```
