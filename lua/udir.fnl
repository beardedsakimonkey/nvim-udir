(local fs (require :udir.fs))
(local store (require :udir.store))
(local u (require :udir.util))
(local api vim.api)
(local uv vim.loop)

(local M {})

;; -- Render -------------------------------------------------------------------

(fn sort-by-name [files]
  (table.sort files (fn [a b]
                      (if (= (= :directory a.type) (= :directory b.type))
                          (< a.name b.name)
                          (= :directory a.type)))))

(fn add-hl-and-virttext [cwd ns files]
  (api.nvim_buf_clear_namespace 0 ns 0 -1)
  (each [i file (ipairs files)]
    (let [path (u.join-path cwd file.name)
          (?virttext ?hl) (match file.type
                            :directory (values u.sep :UdirDirectory)
                            :link (values (.. "@ → "
                                              (or (uv.fs_readlink path) "???"))
                                          :UdirSymlink)
                            :file (if (fs.executable? path)
                                      (values "*" :UdirExecutable)
                                      (values nil :UdirFile)))]
      (when ?virttext
        (api.nvim_buf_set_extmark 0 ns (- i 1) (length file.name)
                                  {:virt_text [[?virttext :UdirVirtText]]
                                   :virt_text_pos :overlay})
        (api.nvim_buf_set_extmark 0 ns (- i 1) 0
                                  {:end_col (length file.name) :hl_group ?hl})))))

(fn render [state]
  (local {: buf : cwd} state)
  (local files (fs.list cwd))

  (fn visible? [file]
    (if M.config.show_hidden_files true
        (not (M.config.is_file_hidden file files cwd))))

  (local visible-files (vim.tbl_filter visible? files))
  ((or M.config.sort sort-by-name) visible-files)
  (u.set-lines buf 0 -1 false (vim.tbl_map #$1.name visible-files))
  (add-hl-and-virttext cwd state.ns visible-files))

;; -- Keymaps ------------------------------------------------------------------

(fn noremap [mode buf mappings]
  (each [lhs rhs (pairs mappings)]
    (vim.keymap.set mode lhs rhs {:nowait true :silent true :buffer buf})))

(fn setup-keymaps [buf]
  (noremap :n buf M.config.keymaps))

(fn cleanup [state]
  (api.nvim_buf_delete state.buf {:force true})
  (store.remove! state.buf))

(fn update-cwd [state path]
  (tset state :cwd path))

(fn M.quit []
  (local {: ?alt-buf : origin-buf &as state} (store.get))
  (when ?alt-buf
    (u.set-current-buf ?alt-buf))
  (u.set-current-buf origin-buf)
  (cleanup state))

(fn M.up_dir []
  (local state (store.get))
  (local cwd state.cwd)
  (local parent-dir (fs.get-parent-dir state.cwd))
  (local ?hovered-file (u.get-line))
  (when ?hovered-file
    (tset state.hovered-files state.cwd ?hovered-file))
  (update-cwd state parent-dir)
  (render state)
  (u.update-buf-name state.cwd)
  (u.set-cursor-pos (fs.basename cwd) :or-top))

(fn M.open [?cmd]
  (local state (store.get))
  (local filename (u.get-line))
  (when (not= "" filename)
    ;; fs_realpath also checks file existence
    (local (path msg) (uv.fs_realpath (u.join-path state.cwd filename)))
    (if (not path)
        (u.err msg)
        (if (fs.dir? path)
            (if ?cmd
                (vim.cmd (.. ?cmd " " (vim.fn.fnameescape path)))
                (do
                  (update-cwd state path)
                  (render state)
                  (u.update-buf-name state.cwd)
                  (local ?hovered-file (. state.hovered-files path))
                  (u.set-cursor-pos ?hovered-file :or-top)))
            (do
              (u.set-current-buf state.origin-buf) ; Update the altfile
              (vim.cmd (.. (or ?cmd :edit) " " (vim.fn.fnameescape path)))
              (cleanup state))))))

(fn M.reload []
  (local state (store.get))
  (render state))

(fn M.delete []
  (local state (store.get))
  (local filename (u.get-line))
  (if (= "" filename)
      (u.err "Empty filename")
      (let [path (u.join-path state.cwd filename)
            _ (print (string.format "Are you sure you want to delete %q? (y/n)"
                                    path))
            input (vim.fn.getchar)
            confirmed? (= :y (vim.fn.nr2char input))]
        (u.clear-prompt)
        (when confirmed?
          (local (ok? msg) (pcall fs.delete path))
          (if (not ok?)
              (u.err msg)
              (render state))))))

(fn copy-or-move [move?]
  (local filename (u.get-line))
  (if (= "" filename) (u.err "Empty filename")
      (let [state (store.get)]
        (vim.ui.input {:prompt (if move? "Move to: " "Copy to: ")
                       :completion :file}
                      (fn [name]
                        (u.clear-prompt)
                        (local src (u.join-path state.cwd filename))
                        (local (ok? msg)
                               (pcall fs.copy-or-move move? src name state.cwd))
                        (if (not ok?) (u.err msg)
                            (do
                              (render state)
                              (u.set-cursor-pos (fs.basename name)))))))))

(fn M.move []
  (copy-or-move true))

(fn M.copy []
  (copy-or-move false))

(fn M.create []
  (local state (store.get))
  (local path-saved vim.opt_local.path)
  (set vim.opt_local.path state.cwd)
  (vim.ui.input {:prompt "New file: " :completion :file_in_path}
                (fn [name]
                  (set vim.opt_local.path path-saved)
                  (u.clear-prompt)
                  (when name
                    (local path (u.join-path state.cwd name))
                    (local (ok? msg)
                           (if (vim.endswith name u.sep)
                               (pcall fs.create-dir path)
                               (pcall fs.create-file path)))
                    (if (not ok?) (u.err msg)
                        (do
                          (render state)
                          (u.set-cursor-pos (fs.basename path))))))))

(fn M.toggle_hidden_files []
  (local state (store.get))
  (local ?hovered-file (u.get-line))
  (set M.config.show_hidden_files (not M.config.show_hidden_files))
  (render state)
  (u.set-cursor-pos ?hovered-file))

;; -- Configuration ------------------------------------------------------------

;; For backwards compat
(tset M :map
      {:quit "<Cmd>lua require'udir'.quit()<CR>"
       :up_dir "<Cmd>lua require'udir'.up_dir()<CR>"
       :open "<Cmd>lua require'udir'.open()<CR>"
       :open_split "<Cmd>lua require'udir'.open('split')<CR>"
       :open_vsplit "<Cmd>lua require'udir'.open('vsplit')<CR>"
       :open_tab "<Cmd>lua require'udir'.open('tabedit')<CR>"
       :reload "<Cmd>lua require'udir'.reload()<CR>"
       :delete "<Cmd>lua require'udir'.delete()<CR>"
       :create "<Cmd>lua require'udir'.create()<CR>"
       :move "<Cmd>lua require'udir'.move()<CR>"
       :copy "<Cmd>lua require'udir'.copy()<CR>"
       :toggle_hidden_files "<Cmd>lua require'udir'.toggle_hidden_files()<CR>"})

(tset M :config {:keymaps {:q M.map.quit
                           :h M.map.up_dir
                           :- M.map.up_dir
                           :l M.map.open
                           :<CR> M.map.open
                           :s M.map.open_split
                           :v M.map.open_vsplit
                           :t M.map.open_tab
                           :R M.map.reload
                           :d M.map.delete
                           :+ M.map.create
                           :m M.map.move
                           :c M.map.copy
                           :. M.map.toggle_hidden_files}
                 :show_hidden_files true
                 :is_file_hidden #false
                 :sort sort-by-name})

;; For backwards compat
(fn M.setup [?cfg]
  (u.warn "`setup()` is now deprecated. Please see the readme.")
  (local cfg (or ?cfg {}))
  ;; Whether to automatically open Udir when editing a directory
  (when (= false cfg.auto_open)
    (u.warn "`auto_open` is no longer configurable."))
  (when cfg.keymaps
    (tset M.config :keymaps cfg.keymaps))
  (when (not= nil cfg.show_hidden_files)
    (tset M.config :show_hidden_files cfg.show_hidden_files))
  (when cfg.is_file_hidden
    (tset M.config :is_file_hidden cfg.is_file_hidden)))

;; -- Initialization -----------------------------------------------------------

(fn M.udir [dir ?from-au]
  ;; If we're executing from the BufEnter autocmd, the current buffer has
  ;; already changed, so the origin-buf is actually the altbuf, and we don't
  ;; know what the origin-buf's altbuf is.
  (let [has-altbuf (not= 0 (vim.fn.bufexists 0))
        origin-buf (if (and ?from-au has-altbuf) (vim.fn.bufnr "#")
                       (api.nvim_get_current_buf))
        ?alt-buf (if (or ?from-au (not has-altbuf)) nil (vim.fn.bufnr "#"))
        cwd (if (not= "" dir) (fs.realpath (vim.fn.expand dir))
                ;; `expand('%')` can be empty if in an unnamed buffer, like `:enew`, so
                ;; fallback to the cwd.
                (let [p (vim.fn.expand "%:p:h")]
                  (if (not= "" p) (fs.realpath p) (assert (uv.cwd)))))
        ?origin-filename (let [p (vim.fn.expand "%:p:t")]
                           (if (= "" p) nil p))
        buf (u.create-buf cwd)
        ns (api.nvim_create_namespace (.. :udir. buf))
        hovered-files {} ; map<realpath, filename>
        state {: buf : origin-buf : ?alt-buf : cwd : ns : hovered-files}]
    (setup-keymaps buf)
    (store.set! buf state)
    (render state)
    (u.set-cursor-pos ?origin-filename)))

M
