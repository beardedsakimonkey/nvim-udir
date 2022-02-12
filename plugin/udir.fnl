(when (not vim.g.loaded_udir)
  (set vim.g.loaded_udir 1)
  (vim.cmd "hi default link UdirFile       Normal")
  (vim.cmd "hi default link UdirDirectory  Directory")
  (vim.cmd "hi default link UdirSymlink    Constant")
  (vim.cmd "hi default link UdirExecutable Special")
  (vim.cmd "hi default link UdirVirtText   Comment")
  (vim.cmd "com! -bar -nargs=? -complete=dir Udir call luaeval('require\"udir\".udir(_A)', <q-args>)"))

