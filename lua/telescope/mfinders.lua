local Job = require('plenary.job')
local log = require('telescope.log')

local finders = {}

local _callable_obj = function()
  local obj = {}

  obj.__index = obj
  obj.__call = function(t, ...) return t:_find(...) end

  obj.close = function() end

  return obj
end

--[[ =============================================================

    JobMultiFinder

Uses an external Job to get results. Processes results as they arrive.
Support for creating more results from single entry.
Ideal for json input from external program.

For more information about how Jobs are implemented, checkout 'plenary.job'

-- ============================================================= ]]
local JobMultiFinder = _callable_obj()

--- Create a new finder command
---
---@param opts table Keys:
--     fn_command function The function to call
--
function JobMultiFinder:new(opts)
  opts = opts or {}

  assert(opts.entries_maker, "`entries_maker` should be provided for finder:new")

  local obj = setmetatable({
    entries_maker = opts.entries_maker,
    fn_command = opts.fn_command,
    cwd = opts.cwd,
    writer = opts.writer,

    -- Maximum number of results to process.
    --  Particularly useful for live updating large queries.
    maximum_results = opts.maximum_results,
  }, self)

  return obj
end

function JobMultiFinder:_find(prompt, process_result, process_complete)
  log.trace("Finding...")

  if self.job and not self.job.is_shutdown then
    log.debug("Shutting down old job")
    self.job:shutdown()
  end

  local on_output = function(_, line, _)
    if not line or line == "" then
      return
    end

    local entries = self.entries_maker(line)
    for _, i in ipairs (entries) do
      log.debug("processing_result: "..vim.inspect(i))
      process_result(i)
    end

    --process_result(line)
  end

  local opts = self:fn_command(prompt)
  if not opts then return end

  local writer = nil
  if opts.writer and Job.is_job(opts.writer) then
    writer = opts.writer
  elseif opts.writer then
    writer = Job:new(opts.writer)
  end

  self.job = Job:new {
    command = opts.command,
    args = opts.args,
    cwd = opts.cwd or self.cwd,

    maximum_results = self.maximum_results,

    writer = writer,

    enable_recording = false,

    on_stdout = on_output,
    on_stderr = on_output,

    on_exit = function()
      process_complete()
    end,
  }

  self.job:start()
end


-- local
--
---@param command_generator function (string): String Command list to execute.
---@param entries_maker function(line: string) => table
---         @key cwd string
finders.new_multi_entries_job = function(command_generator, entries_maker, maximum_results, cwd)
  return JobMultiFinder:new {
    fn_command = function(_, prompt)
      local command_list = command_generator(prompt)
      if command_list == nil then
        return nil
      end

      local command = table.remove(command_list, 1)

      return {
        command = command,
        args = command_list,
      }
    end,

    entries_maker = entries_maker,
    maximum_results = maximum_results,
    cwd = cwd,
  }
end

return finders
