(local fs (require :qdir.fs))
(local store (require :qdir.store))
(local u (require :qdir.util))
(local api vim.api)
(local uv vim.loop)

(local M {})

;; --------------------------------------
;; CONFIGURATION
;; --------------------------------------

(tset M :keymap
      {:quit "<Cmd>lua require'qdir'.quit()<CR>"
       :up-dir "<Cmd>lua require'qdir'[\"up-dir\"]()<CR>"
       :open "<Cmd>lua require'qdir'.open()<CR>"
       :open-split "<Cmd>lua require'qdir'.open('split')<CR>"
       :open-vsplit "<Cmd>lua require'qdir'.open('vsplit')<CR>"
       :open-tab "<Cmd>lua require'qdir'.open('tabedit')<CR>"
       :reload "<Cmd>lua require'qdir'.reload()<CR>"
       :delete "<Cmd>lua require'qdir'.delete()<CR>"
       :create "<Cmd>lua require'qdir'.create()<CR>"
       :rename "<Cmd>lua require'qdir'.rename()<CR>"
       :copy "<Cmd>lua require'qdir'.copy()<CR>"
       :cd "<Cmd>lua require'qdir'.cd()<CR>"
       :toggle-hidden-files "<Cmd>lua require'qdir'[\"toggle-hidden-files\"]()<CR>"})

(local config {:keymaps {:q M.keymap.quit
                         :h M.keymap.up-dir
                         :- M.keymap.up-dir
                         :l M.keymap.open
                         :<CR> M.keymap.open
                         :s M.keymap.open-split
                         :v M.keymap.open-vsplit
                         :t M.keymap.open-tab
                         :R M.keymap.reload
                         :d M.keymap.delete
                         :+ M.keymap.create
                         :r M.keymap.rename
                         :m M.keymap.rename
                         :c M.keymap.copy
                         :C M.keymap.cd
                         :gh M.keymap.toggle-hidden-files}
               :show-hidden-files true
               :is-file-hidden (fn []
                                 false)
               :watch-fs false})

(fn M.setup [cfg]
  (let [cfg (or cfg {})]
    ;; Whether to automatically open Qdir when editing a directory
    (when cfg.auto-open
      (vim.cmd "aug qdir")
      (vim.cmd :au!)
      (vim.cmd "au BufEnter * if !empty(expand('%')) && isdirectory(expand('%')) && !get(b:, 'is_qdir') | Qdir | endif")
      (vim.cmd "aug END"))
    (when cfg.keymaps
      (tset config :keymaps cfg.keymaps))
    (when (not= nil cfg.show-hidden-files)
      (tset config :show-hidden-files cfg.show-hidden-files))
    (when (not= nil cfg.watch-fs)
      (tset config :watch-fs cfg.watch-fs))
    (when cfg.is-file-hidden
      (tset config :is-file-hidden cfg.is-file-hidden))))

;; --------------------------------------
;; RENDER
;; --------------------------------------

(lambda sort-in-place [files]
  (table.sort files #(if (= $1.type $2.type) (< $1.name $2.name)
                         :else (= $1.type :directory)))
  nil)

(lambda render-virttext [ns files]
  (api.nvim_buf_clear_namespace 0 ns 0 -1)
  ;; Add virtual text to each directory/symlink
  (each [i file (ipairs files)]
    (let [(virttext hl) (match file.type
                          :directory (values u.sep :Directory)
                          :link (values "@" :Constant))]
      (when virttext
        (api.nvim_buf_set_extmark 0 ns (- i 1) (length file.name)
                                  {:virt_text [[virttext :Comment]]
                                   :virt_text_pos :overlay})
        (api.nvim_buf_set_extmark 0 ns (- i 1) 0
                                  {:end_col (length file.name) :hl_group hl})))))

(lambda render [state]
  (let [{: buf : cwd} state
        files (fs.list cwd)
        files (if config.show-hidden-files files :else
                  (vim.tbl_filter #(not (config.is-file-hidden $1 cwd)) files))
        _ (sort-in-place files)
        filenames (->> files
                       (vim.tbl_map #$1.name))]
    (u.set-lines buf 0 -1 false filenames)
    (render-virttext state.ns files)))

;; --------------------------------------
;; KEYMAPS
;; --------------------------------------

(lambda noremap [mode buf mappings]
  (each [lhs rhs (pairs mappings)]
    (api.nvim_buf_set_keymap buf mode lhs rhs
                             {:nowait true :noremap true :silent true})))

(lambda setup-keymaps [buf]
  (noremap :n buf config.keymaps))

(lambda cleanup [state]
  (api.nvim_buf_delete state.buf {:force true})
  (if config.watch-fs (state.event:stop))
  (store.remove state.buf))

;; This can cause an unavoidable cascading render when modifying a file from
;; Qdir
(fn on-fs-event [err filename _events]
  (assert (not err))
  (local state (store.get))
  (render state))

(lambda update-cwd [state path]
  (tset state :cwd path)
  (when config.watch-fs
    (assert (state.event:stop))
    (assert (state.event:start path {} (vim.schedule_wrap on-fs-event))))
  nil)

(fn M.quit []
  (let [state (store.get)
        {: alt-buf : origin-buf} state]
    (if alt-buf (u.set-current-buf alt-buf))
    (u.set-current-buf origin-buf)
    (cleanup state)
    nil))

(fn M.up-dir []
  (let [state (store.get)
        cwd state.cwd
        parent-dir (fs.get-parent-dir state.cwd)]
    ;; Cache hovered filename
    (local hovered-filename (u.get-line))
    (if hovered-filename (tset state.hovered-filenames state.cwd
                               hovered-filename))
    (update-cwd state parent-dir)
    (render state)
    (u.update-statusline state.cwd)
    (u.set-cursor-pos (fs.basename cwd) :or-top))
  nil)

(fn M.open [cmd]
  (let [state (store.get)
        filename (u.get-line)]
    (if (not= "" filename)
        (let [path (u.join-path state.cwd filename)
              realpath (fs.canonicalize path)]
          (if (fs.is-dir? path)
              (if cmd
                  (vim.cmd (.. cmd " " (vim.fn.fnameescape realpath)))
                  :else
                  (do
                    (update-cwd state realpath)
                    (render state)
                    (local hovered-file (. state.hovered-filenames realpath))
                    (u.update-statusline state.cwd)
                    (u.set-cursor-pos hovered-file :or-top)))
              :else
              ;; It's a file
              (do
                ;; Update the altfile
                (u.set-current-buf state.origin-buf)
                ;; Open the file
                (vim.cmd (.. (or cmd :edit) " " (vim.fn.fnameescape realpath)))
                (cleanup state)))))))

(fn M.reload []
  (let [state (store.get)]
    (render state)))

(fn M.delete []
  (let [state (store.get)
        filename (u.get-line)]
    (if (= "" filename) (u.err "Empty filename") :else
        (let [path (u.join-path state.cwd filename)
              _ (print (string.format "Are you sure you want to delete %q? (y/n)"
                                      path))
              input (vim.fn.getchar)
              confirmed? (= (vim.fn.nr2char input) :y)]
          (when confirmed?
            (fs.delete path)
            (render state))
          (u.clear-prompt)))))

(fn copy-or-rename [operation prompt]
  (let [state (store.get)
        filename (u.get-line)]
    (if (= "" filename) (u.err "Empty filename") :else
        (let [path (u.join-path state.cwd filename)
              name (vim.fn.input prompt)]
          (when (not= name "")
            (let [newpath (u.join-path state.cwd name)]
              (operation path newpath)
              (render state)
              (u.clear-prompt)
              (u.set-cursor-pos (fs.basename newpath))))))))

(fn M.rename []
  (copy-or-rename fs.rename "New name: "))

(fn M.copy []
  (copy-or-rename fs.copy "Copy to: "))

(fn M.create []
  (let [state (store.get)
        name (vim.fn.input "New file: ")]
    (when (not= name "")
      (let [path (u.join-path state.cwd name)]
        (if (vim.endswith name u.sep) (fs.create-dir path)
            :else (fs.create-file path))
        (render state)
        (u.clear-prompt)
        (u.set-cursor-pos (fs.basename path))))))

(fn M.toggle-hidden-files []
  (let [state (store.get)
        hovered-filename (u.get-line)]
    (set config.show-hidden-files (not config.show-hidden-files))
    (render state)
    (u.set-cursor-pos (fs.basename hovered-filename))))

(fn M.cd []
  (let [{: cwd} (store.get)]
    (vim.cmd (.. "cd " (vim.fn.fnameescape cwd)))
    (vim.cmd :pwd)))

;; --------------------------------------
;; INITIALIZATION
;; --------------------------------------

;; This gets called by the `:Qdir` command
(fn M.qdir []
  (let [origin-buf (api.nvim_get_current_buf)
        alt-buf (let [n (vim.fn.bufnr "#")]
                  (if (= n -1) nil n))
        cwd (let [p (vim.fn.expand "%:p:h")]
              (if (not= "" p) (fs.canonicalize p) nil))
        origin-filename (let [p (vim.fn.expand "%")]
                          (if (not= "" p) (fs.basename (fs.canonicalize p)) nil))
        win (vim.fn.win_getid)
        buf (assert (u.find-or-create-buf cwd win))
        ns (api.nvim_create_namespace (.. :qdir. buf))
        hovered-filenames {}
        event (assert (uv.new_fs_event))
        state {: buf
               : win
               : origin-buf
               : alt-buf
               : cwd
               : ns
               : hovered-filenames
               : event}]
    (setup-keymaps buf)
    (store.set! buf state)
    (render state)
    (u.set-cursor-pos origin-filename)
    ;; FIXME: This is sometimes causing an error on save
    (if config.watch-fs (event:start cwd {} (vim.schedule_wrap on-fs-event)))))

M

