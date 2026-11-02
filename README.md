# nvim-coach

A tiny, always-on cheat sheet that teaches you Neovim while you use it.

When you open Neovim, a small panel appears in the top-right corner with the
shortcuts you need right now. It changes with what you're doing:

| You are…               | The panel shows                                       |
| ---------------------- | ----------------------------------------------------- |
| Moving around (Normal) | `h j k l`, `w / b`, `gg / G`, save & quit, jump back  |
| Typing (Insert)        | `Esc` to get back, quick delete shortcuts             |
| Selecting (Visual)     | copy, cut, indent                                     |
| Browsing a folder      | open, go up with `-`, create / rename / delete files  |

A rotating **tip** at the bottom teaches you one slightly more advanced trick
at a time.

```
╭──── NORMAL · moving around ────╮
│ MOVE                           │
│  h j k l    left down up right │
│  w / b      next / prev word   │
│  gg / G     top / bottom       │
│ ...                            │
│ Tip: ciw = change the word     │
╰────────────────────────────────╯
```

## Install

No plugin manager needed. Add this to `~/.config/nvim/init.lua`:

```lua
vim.opt.rtp:prepend(vim.fn.expand("~/projects/nvim-coach"))
require("coach").setup()
```

Or with [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ dir = "~/projects/nvim-coach", config = function() require("coach").setup() end }
```

Requires Neovim 0.10+.

## Usage

| Key / command | Action                     |
| ------------- | -------------------------- |
| `F1`          | Hide / show the panel      |
| `:Coach`      | Hide / show the panel      |
| `:CoachTip`   | Show a new tip             |

The panel hides itself on small terminals so it never covers your code.

## Configure

```lua
require("coach").setup({
  toggle_key = "<leader>?", -- default: "<F1>"
})
```

Want to add your own shortcuts? The cheat sheets and tips are plain Lua tables
at the top of [`lua/coach/init.lua`](lua/coach/init.lua). Edit them as you learn.
