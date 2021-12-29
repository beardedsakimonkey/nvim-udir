(local fs (require :qdir.fs))
(local store (require :qdir.store))
(local u (require :qdir.util))
(local api vim.api)

(local M {})

;; --------------------------------------
;; RENDER
;; --------------------------------------

(lambda sort-in-place [files]
  (table.sort files #(if (= $1.type $2.type) (< $1.name $2.name)
                         :else (= $1.type :directory)))
  nil)

(lambda render-virttext [ns files]
  (api.nvim_buf_clear_namespace 0 ns 0 -1)
  ;; Add virtual text to each directory
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
  (noremap :n buf {:q "<Cmd>lua require'qdir'.quit()<CR>"
                   :h "<Cmd>lua require'qdir'[\"up-dir\"]()<CR>"
                   :- "<Cmd>lua require'qdir'[\"up-dir\"]()<CR>"
                   :l "<Cmd>lua require'qdir'.open()<CR>"
                   :<CR> "<Cmd>lua require'qdir'.open()<CR>"
                   :s "<Cmd>lua require'qdir'.open('split')<CR>"
                   :v "<Cmd>lua require'qdir'.open('vsplit')<CR>"
                   :t "<Cmd>lua require'qdir'.open('tabedit')<CR>"
                   :R "<Cmd>lua require'qdir'.reload()<CR>"
                   :d "<Cmd>lua require'qdir'.delete()<CR>"
                   :+ "<Cmd>lua require'qdir'.create()<CR>"
                   :r "<Cmd>lua require'qdir'.rename()<CR>"
                   :m "<Cmd>lua require'qdir'.rename()<CR>"
                   :c "<Cmd>lua require'qdir'.copy()<CR>"}))

(lambda cleanup [buf]
  ;; This is useful in case no other buffer exists
  (api.nvim_buf_delete buf {:force true})
  (store.remove buf))

(fn M.quit []
  (let [{: alt-buf : origin-buf : buf} (store.get)]
    (if alt-buf (u.set-current-buf alt-buf))
    (u.set-current-buf origin-buf)
    ;; FIXME: This should restore the original value of 'modfiable' (also in
    ;; `open`)
    (set vim.opt_local.modifiable true)
    (cleanup buf)
    nil))

(fn M.up-dir []
  (let [state (store.get)
        cwd state.cwd
        parent-dir (fs.get-parent-dir state.cwd)]
    ;; Cache hovered filename
    (local hovered-filename (u.get-line))
    (if hovered-filename (tset state.hovered-filenames state.cwd
                               hovered-filename))
    (tset state :cwd parent-dir)
    (render state)
    (u.update-statusline state.cwd)
    (u.set-cursor-pos (fs.basename cwd)))
  nil)

(fn M.open [cmd]
  (let [state (store.get)
        filename (u.get-line)]
    (if (= filename "") (u.err "Empty filename") :else
        (let [path (u.join-path state.cwd filename)
              realpath (fs.canonicalize path)]
          (if (fs.is-dir? path)
              (if cmd
                  (vim.cmd (.. cmd " " (vim.fn.fnameescape realpath)))
                  :else
                  (do
                    (tset state :cwd realpath)
                    (render state)
                    (local hovered-file (. state.hovered-filenames realpath))
                    (u.update-statusline state.cwd)
                    (u.set-cursor-pos hovered-file)))
              :else
              ;; It's a file
              (do
                ;; Update the altfile
                (u.set-current-buf state.origin-buf)
                ;; Open the file
                (vim.cmd (.. (or cmd :edit) " " (vim.fn.fnameescape realpath)))
                (set vim.opt_local.modifiable true)
                (cleanup state.buf)))))))

(fn M.reload []
  (let [state (store.get)]
    (render state)))

(fn M.delete []
  (let [state (store.get)
        filename (u.get-line)]
    (if (= filename "") (u.err "Empty filename") :else
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
    (if (= filename "") (u.err "Empty filename") :else
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

;; --------------------------------------
;; INITIALIZATION
;; --------------------------------------

(fn M.init [cfg]
  (let [cfg (or cfg {})]
    ;; Whether to automatically open Qdir when editing a directory
    (when cfg.auto-open
      (vim.cmd "aug qdir")
      (vim.cmd :au!)
      (vim.cmd "au BufEnter * if !empty(expand('%')) && isdirectory(expand('%')) && !get(b:, 'is_qdir') | Qdir | endif")
      (vim.cmd "aug END"))))

;; This gets called by the `:Qdir` command
(fn M.qdir []
  (let [origin-buf (api.nvim_get_current_buf)
        alt-buf (let [n (vim.fn.bufnr "#")]
                  (if (= n -1) nil n))
        cwd (let [p (vim.fn.expand "%:p:h")]
              (if (not= p "") (fs.canonicalize p) nil))
        origin-filename (let [p (vim.fn.expand "%")]
                          (if (not= p "") (fs.basename (fs.canonicalize p)) nil))
        win (vim.fn.win_getid)
        buf (assert (u.find-or-create-buf cwd win))
        ns (api.nvim_create_namespace (.. :qdir. buf))
        hovered-filenames {}
        state {: buf
               : win
               : origin-buf
               : alt-buf
               : cwd
               : ns
               : hovered-filenames}]
    (setup-keymaps buf)
    (store.set! buf state)
    (render state)
    (u.set-cursor-pos origin-filename)))

M

