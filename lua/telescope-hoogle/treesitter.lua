local html = require'telescope-hoogle.html'

local M = {}

local styleTable = {
  ['<pre>'] = 'Comment',
  ['<tt>'] = 'Statement',
  ['<a>'] = 'Identifier',
  ['<i>'] = 'Constant',
  ['<b>'] = 'Constant',
  ['<h1>'] = 'Label',
  ['<h2>'] = 'Label',
  ['<h3>'] = 'Label',
  ['<h4>'] = 'Label',
}

local prefixTable = {
  ['<pre>'] = {elem = '\n',   removeWrap = true},
  ['<h1>'] =  {elem = '\n\n', removeWrap = true},
  ['<h2>'] =  {elem = '\n\n', removeWrap = true},
  ['<h3>'] =  {elem = '\n\n', removeWrap = true},
  ['<h4>'] =  {elem = '\n\n', removeWrap = true},
  ['<li>'] =  {elem = '\n- ', removeWrap = false},
}

local suffixTable = {
  ['<pre>'] = {elem = '\n',   removeWrap = true},
  ['<h1>'] =  {elem = '\n\n', removeWrap = true},
  ['<h2>'] =  {elem = '\n\n', removeWrap = true},
  ['<h3>'] =  {elem = '\n\n', removeWrap = true},
  ['<h4>'] =  {elem = '\n\n', removeWrap = true},
  ['<ul>'] =  {elem = '\n',   removeWrap = true},
  ['<ol>'] =  {elem = '\n',   removeWrap = true},
}

local function parseHighlights(input, removeWrap)
  local result = {}
  local resultLen = 0
  local highlights = {}
  local insidePre = false
  local stripNewlineAtBegin = false

  -- Get the text from a node object.
  -- treesitter's html parser does not include whitespaces
  -- at the begin and at the end of the text elemnt.
  -- This function includes those.
  local function get_text(node)
    local _, _, start = node:start()
    local _, _, end_ = node:end_()
    local prev = node:prev_sibling()
    local next_ = node:next_sibling()

    if prev then
      local _, _, prev_end = prev:end_()
      start = prev_end
    end

    if next_ then
      local _, _, next_start = next_:start()
      end_ = next_start
    end

    return input:sub(start + 1, end_)
  end

  -- Hoogle returns the doc as a wrapped text
  -- This function use some heuristic to unwrap the text
  local function removeTextWrap(text)
    if not insidePre then
      text = text:gsub('\n+', '\n')
      if stripNewlineAtBegin then
        text = text:gsub('^\n', '')
        stripNewlineAtBegin = false
      end
      text = text:gsub('\n', ' ')
    end
    return text
  end

  -- Insert prefix or suffix to the result table
  local function insertFix(fixTable, tag)
      local fix = fixTable[tag]
      if fix and (fix.removeWrap == false or fix.removeWrap == removeWrap) then
        table.insert(result, fix.elem)
        resultLen = resultLen + fix.elem:len()
      end
  end

  local function travel(node)
    local nodeSymbol = node:symbol()
    local childCount = node:child_count()

    -- node:type() would return a string but macthing to symbol id (int)
    -- is way more faster
    if nodeSymbol == 15 then
      -- text = 15
      local text = get_text(node)
      if removeWrap then
        text = removeTextWrap(text)
      end
      text = html.decode(text)
      table.insert(result, text)
      resultLen = resultLen + text:len()
    elseif nodeSymbol == 30 then
      -- start_tag = 30
      local nodeStr = vim.treesitter.query.get_node_text(node, input)
      if nodeStr == '<pre>' then insidePre = true end

      insertFix(prefixTable, nodeStr)

      if styleTable[nodeStr] then
        table.insert(highlights, {
          ['type'] = nodeStr,
          beginPos = resultLen
        })
      end
    elseif nodeSymbol == 34 then
      -- end_tag = 34
      local nodeStr = vim.treesitter.query.get_node_text(node, input):gsub('/', '')
      if nodeStr == '<pre>' then insidePre = false end
      if suffixTable[nodeStr] then stripNewlineAtBegin = true end

      insertFix(suffixTable, nodeStr)

      if styleTable[nodeStr] then
        for i = #highlights, 1, -1 do
          if highlights[i]['type'] == nodeStr then
            highlights[i]['type'] = styleTable[nodeStr]
            highlights[i]['endPos'] = resultLen
            break
          end
        end
      end
    end

    if childCount > 0 then
      for child, _ in node:iter_children() do
        travel(child)
      end
    end
  end

  local tsparser = vim.treesitter.get_string_parser(input, "html")
  local root = tsparser:parse()[1]:root()
  travel(root)
  return table.concat(result), highlights
end

local function convertToLines(text, highlights)
  local lines = vim.split(text, '\n')
  local lens = {}
  local lineHighlights = {}

  for i, line in ipairs(lines) do
    lens[i] = line:len()
  end

  local pos = 0
  for i, len in ipairs(lens) do
    local lineNumber = i - 1
    local lineBeginPos = pos
    local lineEndPos = pos + len

    for _, h in ipairs(highlights) do
      local highlightBeginPos = h['beginPos']
      local highlightEndPos = h['endPos']
      local highlightType = h['type']

      local highlightStart = lineBeginPos <= highlightBeginPos and highlightBeginPos <= lineEndPos
      local highlightEnd = lineBeginPos <= highlightEndPos and highlightEndPos <= lineEndPos
      local highlightFullLine = highlightBeginPos < lineBeginPos and lineEndPos < highlightEndPos

      local highlightRelativeBegin = highlightBeginPos - lineBeginPos
      local highlightRelativeEnd = highlightEndPos - lineBeginPos

      if highlightStart and highlightEnd then
        -- Highlight is inside the current line
        table.insert(lineHighlights, {
          ['line'] = lineNumber,
          ['type'] = h['type'],
          ['beginPos'] = highlightRelativeBegin,
          ['endPos'] = highlightRelativeEnd
        })
      elseif highlightStart and not highlightEnd then
        -- Highlight starts on the current line and continues over the current line
        table.insert(lineHighlights, {
          ['line'] = lineNumber,
          ['type'] = highlightType,
          ['beginPos'] = highlightRelativeBegin,
          ['endPos'] = len
        })
      elseif not highlightStart and highlightEnd then
        -- Highlight has begin from previous lines and ends on the current line
        table.insert(lineHighlights, {
          ['line'] = lineNumber,
          ['type'] = highlightType,
          ['beginPos'] = 0,
          ['endPos'] = highlightRelativeEnd
        })
      elseif highlightFullLine then
        -- Highlight has begin from previous lines and continues over the current line
        table.insert(lineHighlights, {
          ['line'] = lineNumber,
          ['type'] = highlightType,
          ['beginPos'] = 0,
          ['endPos'] = len
        })
      end
    end
      pos = pos + len + 1
  end

  return lines, lineHighlights
end

M.render = function(input, opts)
  local removeWrap = opts.remove_wrap or false
  local text, highlightTable = parseHighlights(input, removeWrap)
  return convertToLines(text, highlightTable)
end

return M
