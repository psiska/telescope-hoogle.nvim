--local actions = require'telescope.actions'
local conf = require'telescope.config'.values
local entry_display = require'telescope.pickers.entry_display'
local mfinders = require'telescope.mfinders'
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
-- TODO move to some text utils


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
      {entry.module, 'HaskellModule'},
      {entry.package, 'HaskellPackage'},
      entry.ordinal,
    }
  end

  return function(line)
    local result = {}
    local hoogleJson = json.decode(line)
    for _, v in ipairs(hoogleJson) do
      local obj = {
        value = v['docs'] or "",
        module = v['module']['name'] or "",
        package = v['package']['name'],
        ordinal = v['item'],
        display = make_display,
        preview_command = previewEntry
      }
      table.insert(result, obj)
    end
    return result
  end
end

M.list = function(opts)
  opts = opts or {}
  opts.bin = opts.bin and vim.fn.expand(opts.bin) or vim.fn.exepath('hoogle')
  opts.cwd = utils.get_lazy_default(opts.cwd, vim.fn.getcwd)
  opts.entries_maker = utils.get_lazy_default(opts.entries_maker, gen_from_hoogle, opts)

  --A Sorter is called by the Picker on each item returned by the Finder. It return a number, which is equivalent to the "distance" between the current prompt and the entry returned by a finder.
  pickers.new(opts, {
    prompt_title = 'Hoogle query',
    finder = mfinders.new_multi_entries_job(function(prompt)
      if not prompt or string.len(prompt) < 3 then
        return nil
      end
      return { opts.bin, '--json', '--count=10', prompt}
      end,
      opts.entries_maker
      ),
    sorter = conf.file_sorter(opts),
    previewer = previewers.display_content.new(opts),
  }):find()
end

return M
