-- nvim-coach: a tiny always-on cheat sheet that teaches you Neovim as you go.
-- Shows a floating panel in the top-right corner whose content follows what
-- you're doing: normal mode, insert mode, visual selection, or folder browsing.

local M = {}

local api = vim.api
local ns = api.nvim_create_namespace("nvim_coach")
local state = { buf = nil, win = nil, enabled = true, sheet = nil, tip = nil }

-- ── Content ────────────────────────────────────────────────────────────────
local sheets = {
  normal = {
    title = " NORMAL · moving around ",
    sections = {
      { "MOVE", {
        { "h j k l", "left  down  up  right" },
        { "w / b", "next / previous word" },
        { "0 / $", "start / end of line" },
        { "gg / G", "top / bottom of file" },
        { "C-d / C-u", "half page down / up" },
        { "5j", "any move x5 (see line nums)" },
      } },
      { "EDIT", {
        { "i / a", "type before / after cursor" },
        { "o", "new line below + type" },
        { "x / dd", "delete char / line" },
        { "yy / p", "copy line / paste" },
        { "u / C-r", "undo / redo" },
        { "v", "start selecting" },
      } },
      { "SAVE & QUIT", {
        { ":w", "save" },
        { ":q", "quit" },
        { ":wq", "save and quit" },
        { ":q!", "quit, throw away changes" },
      } },
      { "GO BACK / FIND", {
        { "C-o / C-i", "jump back / forward" },
        { ":Ex", "back to the folder view" },
        { "/word", "search, n = next match" },
      } },
    },
  },
  insert = {
    title = " INSERT · typing ",
    sections = {
      { "YOU ARE TYPING", {
        { "Esc", "back to NORMAL (do this a lot!)" },
        { "C-w", "delete previous word" },
        { "C-u", "delete to start of line" },
        { "C-o cmd", "run one normal cmd, keep typing" },
      } },
    },
  },
  visual = {
    title = " VISUAL · selecting ",
    sections = {
      { "SELECTION", {
        { "h j k l", "grow / shrink selection" },
        { "y", "copy selection" },
        { "d", "delete (cut) selection" },
        { "> / <", "indent / unindent" },
        { "Esc", "cancel selection" },
      } },
    },
  },
  netrw = {
    title = " FOLDER · browsing files ",
    sections = {
      { "NAVIGATE", {
        { "j / k", "down / up the list" },
        { "Enter", "open file or folder" },
        { "-", "go up to parent folder" },
        { "/name", "jump to a file by name" },
      } },
      { "MANAGE", {
        { "%", "create a new file" },
        { "d", "create a new folder" },
        { "R / D", "rename / delete" },
        { ":q", "quit Neovim" },
      } },
    },
  },
}

local tips = {
  "Combine verbs + moves: dw deletes a word, d$ to end of line.",
  "ciw = change the word under the cursor.",
  ". repeats your last change. Try it after dd.",
  "* searches for the word under the cursor.",
  "% jumps between matching ( ) [ ] { }.",
  "zz centers the screen on the cursor.",
  "A appends at end of line, I inserts at start.",
  "f<char> jumps to the next <char> on the line.",
  "Ctrl-^ toggles between your last two files.",
  "Relative line numbers show how far 5j / 3k go.",
  "Stuck? Press Esc twice, then type :q! Enter.",
  ":help <topic> opens docs, e.g. :help motion",
}

-- ── Rendering ──────────────────────────────────────────────────────────────
local function setup_highlights()
  local set = function(name, opts)
    opts.default = true
    api.nvim_set_hl(0, name, opts)
  end
  set("CoachNormal", { link = "NormalFloat" })
  set("CoachBorder", { link = "FloatBorder" })
  set("CoachTitle", { link = "Title" })
  set("CoachHeader", { link = "Special" })
  set("CoachKey", { link = "Function" })
  set("CoachTip", { link = "Comment" })
end

local function build(sheet)
  local lines, marks = {}, {}
  local key_w = 0
  for _, sec in ipairs(sheet.sections) do
    for _, item in ipairs(sec[2]) do
      key_w = math.max(key_w, #item[1])
    end
  end

  for i, sec in ipairs(sheet.sections) do
    if i > 1 then table.insert(lines, "") end
    table.insert(lines, " " .. sec[1])
    table.insert(marks, { #lines - 1, 1, 1 + #sec[1], "CoachHeader" })
    for _, item in ipairs(sec[2]) do
      local key, desc = item[1], item[2]
      table.insert(lines, "  " .. key .. string.rep(" ", key_w - #key + 2) .. desc)
      table.insert(marks, { #lines - 1, 2, 2 + #key, "CoachKey" })
    end
  end

  table.insert(lines, "")
  table.insert(lines, " Tip: " .. state.tip)
  table.insert(marks, { #lines - 1, 0, -1, "CoachTip" })
  table.insert(lines, " F1 hide/show · :CoachTip new tip")
  table.insert(marks, { #lines - 1, 0, -1, "CoachTip" })

  local width = 0
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end
  return lines, marks, width + 1
end

local function close()
  if state.win and api.nvim_win_is_valid(state.win) then
    api.nvim_win_close(state.win, true)
  end
  state.win = nil
end

local function pick_sheet()
  local mode = api.nvim_get_mode().mode
  local m = mode:sub(1, 1)
  if m == "c" then return state.sheet end -- typing a :command, keep current
  if m == "i" or m == "R" then return "insert" end
  if m == "v" or m == "V" or m == "\22" then return "visual" end
  if vim.bo.filetype == "netrw" then return "netrw" end
  return "normal"
end

local function render()
  if not state.enabled then return close() end
  local name = pick_sheet() or "normal"
  state.sheet = name
  local sheet = sheets[name]
  local lines, marks, width = build(sheet)
  local height = #lines

  -- Don't cover your code on small terminals.
  if vim.o.columns < width + 50 or vim.o.lines < height + 4 then
    return close()
  end

  if not (state.buf and api.nvim_buf_is_valid(state.buf)) then
    state.buf = api.nvim_create_buf(false, true)
    vim.bo[state.buf].bufhidden = "hide"
  end
  vim.bo[state.buf].modifiable = true
  api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  for _, mk in ipairs(marks) do
    local row, s, e, hl = mk[1], mk[2], mk[3], mk[4]
    if e == -1 then e = #lines[row + 1] end
    api.nvim_buf_set_extmark(state.buf, ns, row, s, { end_col = e, hl_group = hl })
  end

  local cfg = {
    relative = "editor",
    anchor = "NE",
    row = 1,
    col = vim.o.columns - 1,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = { { sheet.title, "CoachTitle" } },
    title_pos = "center",
    focusable = false,
    zindex = 40,
    noautocmd = true,
  }

  if state.win and api.nvim_win_is_valid(state.win) then
    cfg.noautocmd = nil
    api.nvim_win_set_config(state.win, cfg)
  else
    state.win = api.nvim_open_win(state.buf, false, cfg)
    vim.wo[state.win].winhl = "NormalFloat:CoachNormal,FloatBorder:CoachBorder"
    vim.wo[state.win].winblend = 8
  end
end

local function new_tip()
  local prev = state.tip
  repeat
    state.tip = tips[math.random(#tips)]
  until state.tip ~= prev or #tips == 1
end

-- ── Public API ─────────────────────────────────────────────────────────────
function M.toggle()
  state.enabled = not state.enabled
  render()
end

function M.setup(opts)
  opts = opts or {}
  math.randomseed(os.time())
  new_tip()
  setup_highlights()

  local group = api.nvim_create_augroup("NvimCoach", { clear = true })
  api.nvim_create_autocmd(
    { "VimEnter", "ModeChanged", "BufEnter", "FileType", "VimResized", "WinEnter" },
    { group = group, callback = function() vim.schedule(render) end }
  )
  api.nvim_create_autocmd("ColorScheme", { group = group, callback = setup_highlights })

  api.nvim_create_user_command("Coach", M.toggle, { desc = "Toggle the Neovim coach panel" })
  api.nvim_create_user_command("CoachTip", function()
    new_tip()
    render()
  end, { desc = "Show a new Neovim tip" })

  local key = opts.toggle_key or "<F1>"
  vim.keymap.set({ "n", "i", "v" }, key, M.toggle, { desc = "Toggle Neovim coach" })

  if vim.v.vim_did_enter == 1 then vim.schedule(render) end
end

return M
