(local api vim.api)

(local M {})

(lambda M.find-or-create-buf [cwd win]
  (let [existing-buf (vim.fn.bufnr (.. "^" cwd "$"))]
    (var buf nil)
    (if (= existing-buf -1)
        (do
          ;; Buffer doesn't exist yet, so create it
          (set buf (api.nvim_create_buf false true))
          (assert (not= -1 buf))
          (api.nvim_buf_set_name buf cwd))
        :else
        (set buf existing-buf))
    (api.nvim_buf_set_var buf :is_udir true)
    ;; Triggers BufEnter
    (api.nvim_set_current_buf buf)
    ;; Triggers ftplugin, so must get called after setting the current buffer
    (api.nvim_buf_set_option buf :filetype :udir)
    buf))

(lambda M.set-current-buf [buf]
  (when (and buf (vim.fn.bufexists buf))
    ;; Fail silently. It can happen if we've deleted the origin-buf
    (pcall api.nvim_set_current_buf buf)
    nil))

(lambda M.set-lines [buf start end strict-indexing replacement]
  (set vim.opt_local.modifiable true)
  (api.nvim_buf_set_lines buf start end strict-indexing replacement)
  (set vim.opt_local.modifiable false)
  nil)

(lambda M.get-line []
  (let [[row _col] (api.nvim_win_get_cursor 0)
        [line] (api.nvim_buf_get_lines 0 (- row 1) row true)]
    line))

(lambda find-index [list predicate]
  (each [i item (ipairs list)]
    (when (predicate item)
      (lua "return i")))
  nil)

(lambda M.find-line [predicate]
  "Returns the first line number that matches the predicate, otherwise nil"
  (let [lines (api.nvim_buf_get_lines 0 0 -1 false)]
    (find-index lines predicate)))

(lambda M.delete-buffer [name]
  (let [bufs (vim.fn.getbufinfo {:bufloaded 1 :buflisted 1})]
    (each [_ buf (pairs bufs)]
      (when (= buf.name name)
        (api.nvim_buf_delete buf.bufnr {})))))

(lambda M.clear-prompt []
  (vim.cmd "norm! :"))

(tset M :sep (package.config:sub 1 1))

(lambda M.join-path [fst snd]
  (.. fst M.sep snd))

(fn M.set-cursor-pos [filename or-top]
  (var line (if or-top 1 nil))
  (if filename
      (let [found (M.find-line #(= $1 filename))]
        (if (not= found nil) (set line found))))
  (if (not= nil line) (api.nvim_win_set_cursor 0 [line 0])))

(fn M.err [msg]
  (api.nvim_err_writeln msg))

M

