if vim.fn.executable'hoogle' == 0 then
  error("Unable to find hoogle executable on the path. Install it.")
end
local hoogle_builtin = require'telescope._extensions.hoogle_builtin'
return require'telescope'.register_extension{
  exports = {
    list = hoogle_builtin.list,
  },
}
