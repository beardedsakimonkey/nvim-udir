(local api vim.api)

(local M {})

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
(var buf-name-id 1)

(lambda get-buf-name-id []
  (local id buf-name-id)
  (set buf-name-id (+ buf-name-id 1))
  id)

(lambda M.update-buf-name [buf cwd]
  (local old-name (vim.fn.bufname))
  (local loaded-bufs (->> (vim.fn.getbufinfo)
                          ;; Don't filter out hidden buffers; that leads to
                          ;; occasional errors.
                          (vim.tbl_filter #(= 1 $1.loaded))
                          (vim.tbl_map #$1.name)))
  (local new-name (if (-> loaded-bufs (vim.tbl_contains cwd))
                      (.. cwd " " (get-buf-name-id))
                      cwd))
  ;; `file` is equivalent to nvim_buf_set_name, but allows us to use `keepalt`
  (vim.cmd (.. "sil keepalt file " (vim.fn.fnameescape new-name)))
  ;; Renaming a buffer creates a new buffer with the old name. Delete it.
  (M.delete-buffer old-name))

(lambda M.update-statusline [cwd]
  (set vim.opt_local.statusline (.. " " cwd)))

(lambda M.find-or-create-buf [cwd]
  ;; TODO: If you open udir from a file in dir X, and in another window, open udir
  ;; from another file in dir X, we want to create a brand new udir instance.
  (local existing-buf (vim.fn.bufnr (.. "^" cwd "$")))
  (var buf nil)
  (if (= existing-buf -1)
      (do
        ;; Buffer doesn't exist yet, so create it
        (set buf (api.nvim_create_buf false true))
        (assert (not (= buf -1)))
        ;; Don't use update-buf-name since it does stuff we don't need here
        (api.nvim_buf_set_name buf cwd))
      :else
      (set buf existing-buf))
  (api.nvim_buf_set_var buf :is_udir true)
  ;; Triggers BufEnter
  (api.nvim_set_current_buf buf)
  ;; Triggers ftplugin, so must get called after setting the current buffer
  (api.nvim_buf_set_option buf :filetype :udir)
  buf)

(lambda M.set-current-buf [buf]
  (when (vim.fn.bufexists buf)
    ;; Fail silently. It can happen if we've deleted (unloaded) the origin-buf
    (pcall api.nvim_set_current_buf buf)
    nil))

(lambda M.set-lines [buf start end strict-indexing replacement]
  (set vim.opt_local.modifiable true)
  (api.nvim_buf_set_lines buf start end strict-indexing replacement)
  (set vim.opt_local.modifiable false)
  nil)

(lambda M.get-line []
  (local [row _] (api.nvim_win_get_cursor 0))
  (local [line] (api.nvim_buf_get_lines 0 (- row 1) row true))
  line)

(lambda find-index [list predicate?]
  (var ?ret nil)
  (each [i item (ipairs list) :until (not= nil ?ret)]
    (when (predicate? item)
      (set ?ret i)))
  ?ret)

(lambda M.find-line [predicate?]
  "Returns the first line number that matches the predicate, otherwise nil"
  (local lines (api.nvim_buf_get_lines 0 0 -1 false))
  (find-index lines predicate?))

(lambda M.delete-buffer [name]
  (local bufs (vim.fn.getbufinfo))
  (each [_ buf (pairs bufs)]
    (when (= buf.name name)
      (api.nvim_buf_delete buf.bufnr {}))))

(lambda M.clear-prompt []
  (vim.cmd "norm! :"))

(tset M :sep (package.config:sub 1 1))

(lambda M.join-path [fst snd]
  (.. fst M.sep snd))

(lambda M.set-cursor-pos [?filename ?or-top]
  (var ?line (if ?or-top 1 nil))
  (if ?filename
      (let [?found (M.find-line #(= $1 ?filename))]
        (if (not= nil ?found) (set ?line ?found))))
  (if (not= nil ?line) (api.nvim_win_set_cursor 0 [?line 0])))

(lambda M.err [msg]
  (api.nvim_err_writeln msg))

M

