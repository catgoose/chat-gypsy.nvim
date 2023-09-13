# Gypsy

## Usage

```lua
require('chat-gypsy').toggle()
```

```lua
GypsyToggle
```

- Opens prompt/chat popup that can be used interact with Openai
- Popup is destroyed with 'q' in normal mode
- Calling `require('chat-gypsy').toggle()` or causing popup to lose focus will hide
  the popup while preserving buffer contents

## Installation

### Lazy.nvim

```lua
-- defaults
local opts = {
    openai_key = os.getenv("OPENAI_API_KEY"),
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
            --"<cmd>lua require('gypsy').toggle()<cr>",
            desc = "Gypsy",
            mode = { "n" }
        },
    },
    cmd = { "GypsyToggle", "GypsyOpen", "GypsyClose" }
}
```
