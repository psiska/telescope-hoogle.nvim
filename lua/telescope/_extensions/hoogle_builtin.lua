--local actions = require'telescope.actions'
local conf = require'telescope.config'.values
local entry_display = require'telescope.pickers.entry_display'
local finders = require'telescope.finders'
--local from_entry = require'telescope.from_entry'
--local path = require'telescope.path'
local pickers = require'telescope.pickers'
local previewers = require'telescope.previewers'
local utils = require'telescope.utils'

--local os_home = vim.loop.os_homedir()

local M = {}
--print("hb: here?")

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

local function gen_from_hoogle(opts)
  -- opts: { bin = "/home/psiska/.cabal/bin/hoogle",  cwd = "/home/psiska/.config/nvim/plugged"}
  --print ('hen dostal som opts')
  --print(vim.inspect(opts))
  local displayer = entry_display.create{
    separator = ' ',
    items = {{}},
  }

  local function make_display(entry)
    print("make_display")
    print(vim.inspect(entry))
    local original = entry.item
    return displayer{entry.item}
   --return displayer{
   --  {('%.2f'):format(entry.value), 'TelescopeResultsIdentifier'},
   --  dir,
   --}
  end
  return function(line)
    print("gen_from_hoogle")
    print(vim.inspect(line))
    print("gen_from_hoogle - end")
    local result = {}
    --[[
    return vim.schedule_wrap(function()
      local hoogleJson = vim.fn.json_decode(line)
      for _, v in ipairs(hoogleJson) do
        table.insert(result, {
          value = v.docs,
          ordinal = v.item,
          path = v.module.name .. ' in ' .. v.package.name,
          make_display = make_display
        })
      end
    end)
    ]]
    return {
      value = line,
      ordinal = line,
      path = line,
      make_display = make_display
    }
   
    --[[
    local hoogleJson = vim.fn.json_decode(line)
    -- TODO print lines and split and create individual objects.
    for i, v in ipairs(hoogleJson) do
      table.insert(result, {
        value = v.docs,
        ordinal = v.item,
        path = v.module.name .. ' in ' .. v.package.name,
        make_display = make_display
      })
    end
    return result
    ]]
  end
end

-- TODO use once we are going to create previewer
local function previewEntry(entry, buffer)
  vim.api.nvim_buf_set_lines(buffer, 0, -1, true, {entry.value})
end

M.list = function(opts)
  --print('entered list')
  opts = opts or {}
  opts.bin = opts.bin and vim.fn.expand(opts.bin) or vim.fn.exepath('hoogle')
  -- opts.cmd = utils.get_default(opts.cmd, {vim.o.shell, '-c', 'z -l'})
  opts.cwd = utils.get_lazy_default(opts.cwd, vim.fn.getcwd)
  opts.entry_maker = utils.get_lazy_default(opts.entry_maker, gen_from_hoogle, opts)

  --[[
  -- TODO just create updateable fZinder: https://github.com/nvim-telescope/telescope.nvim/blob/3e58e1ab7d4c80fec7d9b02e3f27503bd72f21ff/scratch/simple_rg.lua
  -- TODO an directly include the 
  -- -- Uhh, finder should probably just GET the results
-- and then update some table.
-- When updating the table, we should call filter on those items
-- and then only display ones that pass the filter
local rg_finder = telescope.finders.new {
  fn_command = function(_, prompt)
    return string.format('rg --vimgrep %s', prompt)
  end,

  responsive = false
}

local p = telescope.pickers.new {
  previewer = telescope.previewers.vim_buffer
}
p:find {
  prompt = 'grep',
  finder = rg_finder
}
  --]]

  --A Sorter is called by the Picker on each item returned by the Finder. It return a number, which is equivalent to the "distance" between the current prompt and the entry returned by a finder.
  pickers.new(opts, {
    prompt_title = 'Hoogle query',
    finder = finders.new_job(function(prompt)
      print ('received prompt: ' .. prompt)
      if not prompt or prompt == "" then
        return nil
      end
      return { opts.bin, '--json', '--count=3', prompt}
      end,
      opts.entry_maker
      ),
    --finder = finders.new_oneshot_job(
    --  { opts.bin, '--json', '--count=3'}, -- | jq -c '.[]'
    --  opts
    --),
    sorter = conf.file_sorter(opts),
    --previewer = previewers.display_content.new(opts),
    previewer = previewers.cat.new(opts),
  }):find()
end
    --[[attach_mappings = function(prompt_bufnr)
      actions._goto_file_selection:replace(function(_, cmd)
        local entry = actions.get_selected_entry()
        actions.close(prompt_bufnr)
        local dir = from_entry.path(entry)
        if cmd == 'edit' then
          require'telescope.builtin'.find_files{cwd = dir}
        elseif cmd == 'new' then
          vim.cmd('cd '..dir)
          print('chdir to '..dir)
        elseif cmd == 'vnew' then
          vim.cmd('lcd '..dir)
          print('lchdir to '..dir)
        end
      end)
      return true
    end,]]

--print("defined list")
return M
