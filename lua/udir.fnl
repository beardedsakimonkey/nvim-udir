(local fs (require :udir.fs))
(local store (require :udir.store))
(local u (require :udir.util))
(local api vim.api)
(local uv vim.loop)

(local M {})

;; --------------------------------------
;; CONFIGURATION
;; --------------------------------------

(tset M :map
      {:quit "<Cmd>lua require'udir'.quit()<CR>"
       :up_dir "<Cmd>lua require'udir'[\"up-dir\"]()<CR>"
       :open "<Cmd>lua require'udir'.open()<CR>"
       :open_split "<Cmd>lua require'udir'.open('split')<CR>"
       :open_vsplit "<Cmd>lua require'udir'.open('vsplit')<CR>"
       :open_tab "<Cmd>lua require'udir'.open('tabedit')<CR>"
       :reload "<Cmd>lua require'udir'.reload()<CR>"
       :delete "<Cmd>lua require'udir'.delete()<CR>"
       :create "<Cmd>lua require'udir'.create()<CR>"
       :move "<Cmd>lua require'udir'.move()<CR>"
       :copy "<Cmd>lua require'udir'.copy()<CR>"
       :toggle_hidden_files "<Cmd>lua require'udir'[\"toggle-hidden-files\"]()<CR>"})

(local config {:keymaps {:q M.map.quit
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
               :show-hidden-files true
               :is-file-hidden #false})

(λ M.setup [?cfg]
  (local cfg (or ?cfg {}))
  ;; Whether to automatically open Udir when editing a directory
  (when (not= false cfg.auto_open)
    (vim.cmd "aug udir | au!")
    (vim.cmd "au BufEnter * if !empty(expand('%')) && isdirectory(expand('%')) && !get(b:, 'is_udir') | call luaeval(\"require'udir'.udir('', true)\") | endif")
    (vim.cmd "aug END"))
  (when cfg.keymaps
    (tset config :keymaps cfg.keymaps))
  (when (not= nil cfg.show_hidden_files)
    (tset config :show-hidden-files cfg.show_hidden_files))
  (when cfg.is_file_hidden
    (tset config :is-file-hidden cfg.is_file_hidden)))

;; --------------------------------------
;; RENDER
;; --------------------------------------

(λ sort! [files]
  (table.sort files #(if (= $1.type $2.type)
                         (< $1.name $2.name)
                         (= :directory $1.type)))
  files)

(λ render-virttext [cwd ns files]
  (api.nvim_buf_clear_namespace 0 ns 0 -1)
  ;; Add virtual text to each directory/symlink
  (each [i file (ipairs files)]
    (let [path (u.join-path cwd file.name)
          (?virttext ?hl) (match file.type
                            :directory (values u.sep :UdirDirectory)
                            :link (values (.. "@ → "
                                              (assert (uv.fs_readlink path)))
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

(λ render [state]
  (local {: buf : cwd} state)
  (local files (fs.list cwd))

  (fn not-hidden? [file]
    (if config.show-hidden-files true
        (not (config.is-file-hidden file files cwd))))

  (local visible-files (vim.tbl_filter not-hidden? files))
  (sort! visible-files)
  (u.set-lines buf 0 -1 false (vim.tbl_map #$1.name visible-files))
  (render-virttext cwd state.ns visible-files))

;; --------------------------------------
;; KEYMAPS
;; --------------------------------------

(λ noremap [mode buf mappings]
  (each [lhs rhs (pairs mappings)]
    (api.nvim_buf_set_keymap buf mode lhs rhs
                             {:nowait true :noremap true :silent true})))

(λ setup-keymaps [buf]
  (noremap :n buf config.keymaps))

(λ cleanup [state]
  (api.nvim_buf_delete state.buf {:force true})
  (store.remove! state.buf))

(λ update-cwd [state path]
  (tset state :cwd path))

(λ M.quit []
  (local {: ?alt-buf : origin-buf &as state} (store.get))
  (when ?alt-buf
    (u.set-current-buf ?alt-buf))
  (u.set-current-buf origin-buf)
  (cleanup state))

(λ M.up-dir []
  (local state (store.get))
  (local cwd state.cwd)
  (local parent-dir (fs.get-parent-dir state.cwd))
  (local ?hovered-file (u.get-line))
  (when ?hovered-file
    (tset state.hovered-files state.cwd ?hovered-file))
  (update-cwd state parent-dir)
  (render state)
  (u.update-buf-name state.buf state.cwd)
  (u.set-cursor-pos (fs.basename cwd) :or-top))

(λ M.open [?cmd]
  (local state (store.get))
  (local filename (u.get-line))
  (when (not= "" filename)
    (local path (fs.realpath (u.join-path state.cwd filename)))
    (fs.assert-readable path)
    (if (fs.dir? path)
        (if ?cmd
            (vim.cmd (.. ?cmd " " (vim.fn.fnameescape path)))
            (do
              (update-cwd state path)
              (render state)
              (u.update-buf-name state.buf state.cwd)
              (local ?hovered-file (. state.hovered-files path))
              (u.set-cursor-pos ?hovered-file :or-top)))
        (do
          (u.set-current-buf state.origin-buf) ; Update the altfile
          (vim.cmd (.. (or ?cmd :edit) " " (vim.fn.fnameescape path)))
          (cleanup state)))))

(λ M.reload []
  (local state (store.get))
  (render state))

(λ M.delete []
  (local state (store.get))
  (local filename (u.get-line))
  (if (= "" filename)
      (u.err "Empty filename")
      (let [path (u.join-path state.cwd filename)
            _ (print (string.format "Are you sure you want to delete %q? (y/n)"
                                    path))
            input (vim.fn.getchar)
            confirmed? (= :y (vim.fn.nr2char input))]
        (when confirmed?
          (fs.delete path)
          (render state))
        (u.clear-prompt))))

(λ copy-or-move [should-move]
  (local state (store.get))
  (local filename (u.get-line))
  (if (= "" filename)
      (u.err "Empty filename")
      (let [src (u.join-path state.cwd filename)
            prompt (if should-move "Move to: " "Copy to: ")
            name (vim.fn.input prompt)]
        (when (not= "" name)
          (let [dest (u.join-path state.cwd name)]
            (fs.copy-or-move should-move src dest)
            (render state)
            (u.clear-prompt)
            (u.set-cursor-pos (fs.basename dest)))))))

(λ M.move []
  (copy-or-move true))

(λ M.copy []
  (copy-or-move false))

(λ M.create []
  (local state (store.get))
  (local name (vim.fn.input "New file: "))
  (when (not= name "")
    (local path (u.join-path state.cwd name))
    (if (vim.endswith name u.sep)
        (fs.create-dir path)
        (fs.create-file path))
    (render state)
    (u.clear-prompt)
    (u.set-cursor-pos (fs.basename path))))

(λ M.toggle-hidden-files []
  (local state (store.get))
  (local ?hovered-file (u.get-line))
  (set config.show-hidden-files (not config.show-hidden-files))
  (render state)
  (u.set-cursor-pos ?hovered-file))

;; --------------------------------------
;; INITIALIZATION
;; --------------------------------------

;; This gets called by the `:Udir` command
(λ M.udir [dir ?from-au]
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
                  (if (not= "" p) (fs.realpath p) (assert (vim.loop.cwd)))))
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

