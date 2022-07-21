local actions = require'telescope.actions'
local actions_state = require 'telescope.actions.state'
local conf = require'telescope.config'.values
local entry_display = require'telescope.pickers.entry_display'
local finders = require'telescope.finders'
local log = require'telescope.log'
local pickers = require'telescope.pickers'
local previewers = require'telescope.previewers'
local utils = require'telescope.utils'

local json = require'telescope.json'

local styleTable = {}
styleTable.pre = 'Comment'
styleTable.tt = 'Statement'
styleTable.a = 'Identifier'

local M = {}
local function splitToLines(input, delimiter)
  local result = { }
  local from  = 1
  local delim_from, delim_to = string.find( input, delimiter, from  )
  while delim_from do
    table.insert( result, string.sub( input, from , delim_from-1 ) )
    from  = delim_to + 1
    delim_from, delim_to = string.find( input, delimiter, from  )
  end
  table.insert( result, string.sub( input, from  ) )
  return result
end
local function tokenizeHtml(input)
  local delimiter = '\n'
  local go = true
  local cstr = input
  local result = {}
  while go do
    local startIdx, _, tag, _, tagVal, _, rem = cstr:find('<(%w+)>([%s\r\n\t]*)([^<]*)([%s\r\n\t]*)</%w+>(.*)')
    if startIdx ~= nil then
      local previous = cstr:sub(0, startIdx - 1)
      cstr = rem
      local textR1 = splitToLines(previous, delimiter)
      for _, v in pairs(textR1) do
        if #v ~= 0 then
          table.insert( result, { prev = v })
          if #textR1 > 1 then table.insert(result, { nl = true }) end
        end
      end
      -- process tag with newlines inside
      local tagR1 = splitToLines(tagVal, delimiter)
      for _, v in pairs(tagR1) do
        table.insert(result , { tag = tag, tagValue = v })
        if #tagR1 > 1 then table.insert(result, { nl = true }) end
      end
    else
      go = false
    end
  end
  return result
end

local function renderHtmlForBuffer(input, styleTable)
  local fullText = ''
  local currentLine = 0
  local textResult = {}
  local highLights = {}
  for _, v  in pairs(input) do
    if v.prev ~= nil then
      fullText = fullText .. v.prev
    elseif (v.nl ~= nil and v.nl == true) then
      table.insert(textResult, fullText)
      fullText = ''
      currentLine = currentLine + 1
    elseif (v.tag ~= nil and v.tagValue:len() > 0) then
      local hl = {}
      hl.type = styleTable[v.tag] or 'Identifier'
      hl.line = currentLine
      hl.beginPos = fullText:len()
      hl.endPos = fullText:len() + v.tagValue:len()
      table.insert(highLights, hl)
      fullText = fullText .. v.tagValue
    end

    --print("k: " .. vim.inspect(k))
    --print("v: " .. vim.inspect(v))
  end
  if fullText:len() > 0 then table.insert(textResult, fullText) end
  -- returns full text plus table of offsets to buffer highlight
  return textResult, highLights
end

local function previewEntry(entry, buffer)
  local intr = tokenizeHtml(entry.value)
  local text, highlightTable = renderHtmlForBuffer(intr, styleTable)

  --log.debug("got lines: "..vim.inspect(buf_lines))
  vim.api.nvim_buf_set_lines(buffer, 0, -1, true, text)
  for _,v in pairs(highlightTable) do
    log.debug("hl: "..vim.inspect(v))
    vim.api.nvim_buf_add_highlight(buffer, -1, v.type, v.line, v.beginPos, v.endPos)
  end
end

--[[
 schema is as follows:
 .docs -> String
 .item -> String -- map :: (a -> b) -> [a] -> [b]
 .module.name -> String -- prelude
 .module.url -> String -- https://hackage.haskell.org/package/base/docs/Prelude.html
 .package.name -> String -- base
 .package.url -> String
 .type -> String
 .url -> String -- https://hackage.haskell.org/package/base/docs/Prelude.html#v:map
]]

local function gen_from_hoogle(_)
  local displayer = entry_display.create{
    separator = ' ',
    items = {
      {width = 25, right_justify = false}, -- Module
      {width = 20, right_justify = true},  -- Package
      {remaining = true}, -- type
    },
  }

  local function make_display(entry)
    --log.debug("make_display:entry: "..vim.inspect(entry))
    return displayer{
      {entry.module_name, 'HaskellModule'},
      {entry.package, 'HaskellPackage'},
      entry.ordinal,
    }
  end

  return function(line)
    local v = json.decode(line)
    local obj = {
      value = v['docs'] or "",
      module_name = v['module']['name'] or "",
      type_sig = v['item'],
      package = v['package']['name'],
      ordinal = v['item'],
      url = v['url'] or "",
      display = make_display,
      preview_command = previewEntry
    }
    return obj
  end
end

local function copy_to_clipboard(text)
  local reg = vim.o.clipboard == 'unnamedplus' and '+' or '"'
  vim.fn.setreg(reg, text)
end

local function open_browser(url)
  if url ~= "" then
    local browser_cmd
    if vim.fn.has('unix') == 1 then
      browser_cmd = 'sensible-browser'
    end
    if vim.fn.has('mac') == 1 then
      browser_cmd = 'open'
    end

    vim.cmd(':silent !' .. browser_cmd .. ' ' .. vim.fn.fnameescape(url))
  end
end


local function prompt_fn(opts)
  local function hoogle_cmd(prompt)
    if not prompt or string.len(prompt) < 2 then
      return nil
    end
    return { opts.bin, '--jsonl', '--count=20', '-q',  prompt}
  end

  return hoogle_cmd
end

M.list = function(opts)
  opts = opts or {}
  opts.cwd = utils.get_lazy_default(opts.cwd, vim.fn.getcwd)
  opts.entry_maker = utils.get_lazy_default(opts.entry_maker, gen_from_hoogle, opts)
  opts.bin = opts.bin and vim.fn.expand(opts.bin) or vim.fn.exepath('hoogle')

  --A Sorter is called by the Picker on each item returned by the Finder. It return a number, which is equivalent to the "distance" between the current prompt and the entry returned by a finder.
  pickers.new(opts, {
    prompt_title = 'Hoogle query',
    finder = finders.new_job(prompt_fn(opts), opts.entry_maker, 20, opts.cwd),
    sorter = conf.file_sorter(opts),
    previewer = previewers.display_content.new(opts),
    attach_mappings = function(buf, map)
      map('i', '<CR>', function()
        local entry = actions_state.get_selected_entry()
        copy_to_clipboard(entry.type_sig)
        actions.close(buf)
      end)
      map('i', '<C-b>', function()
        local entry = actions_state.get_selected_entry()
        open_browser(entry.url)
        actions.close(buf)
      end)

      return true
    end
  }):find()
end

return M
