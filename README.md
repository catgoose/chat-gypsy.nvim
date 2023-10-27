# Gypsy

<!--toc:start-->

- [Gypsy](#gypsy)
  - [Usage](#usage)
    - [Calling with `:lua require('chat-gypsy)...`](#calling-with-lua-requirechat-gypsy)
    - [Calling with vim user commands](#calling-with-vim-user-commands)
  - [Installation](#installation) - [Lazy.nvim](#lazynvim) - [Event hooks](#event-hooks)
  <!--toc:end-->

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

## Requirements

### tiktoken

[tiktoken](https://github.com/openai/tiktoken)

```bash
pip install tiktoken
```

### sqlite.lua

[sqlite.lua](https://github.com/kkharji/sqlite.lua)

```bash
sudo pacman -S sqlite # Arch
sudo apt-get install sqlite3 libsqlite3-dev # Ubuntu
sudo dnf install sqlite sqlite-devel # Fedora
```

## Installation

### Lazy.nvim

```lua
-- defaults
local opts = {
  log_level = "warn", -- trace, debug, info, warn, error, fatal
  openai = {
    openai_key = os.getenv("OPENAI_API_KEY"),
    openai_params = {
      model = "gpt-3.5-turbo",
      temperature = 0.7,
      messages = {
        {
          role = "system",
          content = "",
        },
      },
    },
  },
  ui = {
    highlight = {
     role = {
      error = "ErrorMsg",
      system = "LineNr",
      user = "Statement",
      assistant = "Boolean",
     },
     tokens = "LineNr",
     error_message = "Exception",
     heading = "MoreMsg",
    },
    layout_placement = "center",
    prompt = {
      start_insert = true,
    },
    config = {
      zindex = 50,
      border = {
        style = "rounded",
        text = {
          top_align = "left",
        },
        padding = {
          top = 1,
          left = 2,
          right = 2,
        },
      },
      win_options = {
        cursorline = false,
        winblend = 0,
        winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
        wrap = true,
        fillchars = "lastline: ",
      },
    },
    layout = {
      left = {
        prompt_height = 8,
        size = {
          width = "35%",
          height = "100%",
        },
        position = {
          row = "0%",
          col = "0%",
        },
      },
      right = {
        prompt_height = 8,
        size = {
          width = "35%",
          height = "100%",
        },
        position = {
          row = "0%",
          col = "100%",
        },
      },
      center = {
        prompt_height = 5,
        prompt_max_lines = 6,
        position = {
          row = "20%",
          col = "50%",
        },
        size = {
          width = "70%",
          height = "70%",
        },
      },
    },
  },
  hooks = {
    request = {
      start = function(content) end,
      chunk = function(chunk) end,
      complete = function(response) end,
      error = function(source, error_tbl) end,
    },
    models = {
      get = function(models) end,
      error = function(source, error_tbl) end
    }
  },
}

return {
  opts = opts,
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "kkharji/sqlite.lua"
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
    "GypsyClose"
  }
}
```

#### Event hooks

Several event hooks are provided for customization:

```lua
--- ... lazy config
    hooks = {
        request = {
            start = function(content)
              vim.print(content)
            end,
            chunk = function(chunk)
              vim.print(chunk)
            end,
            complete = function(response)
              vim.print(response)
            end,
            error = function(source, error_tbl)
              vim.print(string.format("error %s: %s", source, vim.inspect(error_tbl)))
            end,
        },
    },
--- ... rest of lazy config
```

| Hook             | Argument(s)       | Description                           |
| ---------------- | ----------------- | ------------------------------------- |
| request.start    | content           | Content is sent from user prompt      |
| request.chunk    | chunk             | Chunk is received from request stream |
| request.complete | response          | Response is received from openai      |
| request.error    | source, error_tbl | An error has occurred in a request    |
| models.get       | models            | Models retrieved from OpenAI          |
| models.error     | source, error_tbl | Error occurred retrieving models      |
| entries.start    | response          | Start response composing entries      |
| entries.complete | response          | Complete response composing entries   |

## TODO

- [ ] Create model picker
- [ ] Create templating for system prompts
- [ ] Check tokens before sending to model.
- [ ] Add to configuration the option to select which model to use for entry
      composition
- [ ] When requests are queued, show indicator in ui
- [ ] In history picker allow for selecting chats to mark as "Inactive"
