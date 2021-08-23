if not vim.g.loaded_qdir then
  vim.g.loaded_qdir = 1
  return vim.cmd("com! -bar -nargs=? -complete=dir Qdir call luaeval('require\"qdir\".qdir(_A)', <q-args>)")
end
