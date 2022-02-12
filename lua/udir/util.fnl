(local api vim.api)

(local M {})

(λ find-index [list predicate?]
  (var ?ret nil)
  (each [i item (ipairs list) :until (not= nil ?ret)]
    (when (predicate? item)
      (set ?ret i)))
  ?ret)

;; Returns the first line number that matches the predicate, otherwise nil
(λ find-line [predicate?]
  (local lines (api.nvim_buf_get_lines 0 0 -1 false))
  (find-index lines predicate?))

;; Problem: We'd like udir buffers to be completely unique (udir instances in
;; two different windows should be isolated), and also have a buffer name that
;; we can `:cd %` to.
;;
;; If we use the absolute path as the buffer name, buffers won't be unique. That
;; is, if we have two windows opened to the same path, they will share the
;; same buffer, and so actions performed in one would affect the other.
;;
;; One idea to work around this is to suffix buffer names that would otherwise
;; be unique with a number of repeated "/." in order to be unique. However,
;; vim's implementation of buffer renaming tries to fully resolve the name if
;; it's a path, so it will end up reusing the existing buffer.
;;
;; However, vim doesn't perform this resolution if the buffer name is a URI,
;; such as "file:///Users/blah", so we could use the suffix trick with that.
;; But, alas, `:cd`ing to a URI isn't supported.
;;
;; So, the best we can do is name a buffer by its path if it isn't currently
;; loaded, or otherwise name it by its path with an appended id, which makes it
;; unique but not `:cd`able.
(λ create-buf-name [cwd]
  (local loaded-bufs (->> (vim.fn.getbufinfo)
                          ;; Don't filter out hidden buffers; that leads to
                          ;; occasional errors.
                          (vim.tbl_filter #(= 1 $1.loaded))
                          (vim.tbl_map #$1.name)))
  (var new-name cwd)
  (var i 0)
  (while (-> loaded-bufs (vim.tbl_contains new-name))
    (set i (+ 1 i))
    (set new-name (.. cwd " [" i "]")))
  new-name)

(λ buf-has-var [buf var-name]
  (local (success ret) (pcall api.nvim_buf_get_var buf var-name))
  (if success ret false))

;; --------------------------------------
;; PUBLIC
;; --------------------------------------

(λ M.update-buf-name [buf cwd]
  (local old-name (vim.fn.bufname))
  (local new-name (create-buf-name cwd))
  ;; `file` is equivalent to nvim_buf_set_name, but allows us to use `keepalt`
  (vim.cmd (.. "sil keepalt file " (vim.fn.fnameescape new-name)))
  ;; Renaming a buffer creates a new buffer with the old name. Delete it.
  (M.delete-buffers old-name))

(λ M.create-buf [cwd]
  (local existing-buf (vim.fn.bufnr (.. "^" cwd "$")))
  (var buf nil)
  (if (not= -1 existing-buf)
      (if (buf-has-var existing-buf :is_udir)
          ;; If buffer exists and it's a udir buffer, create a new buffer
          (do
            (set buf (api.nvim_create_buf false true))
            (api.nvim_buf_set_name buf (create-buf-name cwd)))
          ;; If buffer exists and it's not a udir buffer, reuse it. This can
          ;; happen when launching nvim with a directory arg.
          (set buf existing-buf))
      ;; Buffer doesn't exist yet, so create it
      (do
        (set buf (api.nvim_create_buf false true))
        (api.nvim_buf_set_name buf cwd)))
  (assert (not= 0 buf))
  ;; Don't use update-buf-name since it does stuff we don't need here
  (api.nvim_buf_set_var buf :is_udir true)
  ;; Triggers BufEnter
  (api.nvim_set_current_buf buf)
  ;; Triggers ftplugin, so must get called after setting the current buffer
  (api.nvim_buf_set_option buf :filetype :udir)
  buf)

(λ M.set-current-buf [buf]
  (when (vim.fn.bufexists buf)
    ;; Fail silently. It can happen if we've deleted (unloaded) the origin-buf
    (pcall api.nvim_set_current_buf buf)
    nil))

(λ M.set-lines [buf start end strict-indexing replacement]
  (set vim.opt_local.modifiable true)
  (api.nvim_buf_set_lines buf start end strict-indexing replacement)
  (set vim.opt_local.modifiable false)
  nil)

(λ M.get-line []
  (local [row _] (api.nvim_win_get_cursor 0))
  (local [line] (api.nvim_buf_get_lines 0 (- row 1) row true))
  line)

(λ M.delete-buffers [name]
  (each [_ buf (pairs (vim.fn.getbufinfo))]
    (when (= buf.name name)
      (api.nvim_buf_delete buf.bufnr {}))))

(λ M.rename-buffers [old-name new-name]
  (each [_ buf (pairs (vim.fn.getbufinfo))]
    (when (= buf.name old-name)
      (api.nvim_buf_set_name buf.bufnr new-name)
      (api.nvim_buf_call buf.bufnr #(vim.cmd "silent! w!")))))

(λ M.clear-prompt []
  (vim.cmd "norm! :"))

(tset M :sep (package.config:sub 1 1))

(λ M.join-path [fst snd]
  (.. fst M.sep snd))

(λ M.set-cursor-pos [?filename ?or-top]
  (var ?line (if ?or-top 1 nil))
  (when ?filename
    (local ?found (find-line #(= $1 ?filename)))
    (when (not= nil ?found)
      (set ?line ?found)))
  (when (not= nil ?line)
    (api.nvim_win_set_cursor 0 [?line 0])))

(λ M.err [msg]
  (api.nvim_err_writeln msg))

M

