if not vim.g.loaded_udir then
  vim.g.loaded_udir = 1
  return vim.cmd("com! -bar -nargs=? -complete=dir Udir call luaeval('require\"udir\".udir(_A)', <q-args>)")
else
  return nil
end
