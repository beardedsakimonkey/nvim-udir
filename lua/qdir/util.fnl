(local api vim.api)

(local M {})

;; In vim, buffer names must be unique. If we name buffers according to their
;; working directory, and we have two windows open at the same directory, they
;; would be sharing the same buffer. This is undesirable because all changes to
;; one window happens in lockstep with the other. To avoid this, we append a
;; unique ID to buffer names.
(var buf-name-id 1)

(fn get-buf-name-id []
  (local id buf-name-id)
  (set buf-name-id (+ buf-name-id 1))
  id)

(lambda M.update-statusline [cwd]
  (set vim.opt_local.statusline (.. " " cwd)))

(lambda M.find-or-create-buf [cwd win]
  (let [existing-buf (vim.fn.bufnr (.. "^" cwd "$"))]
    (var buf nil)
    (if (= existing-buf -1)
        (do
          ;; Buffer doesn't exist yet, so create it
          (set buf (api.nvim_create_buf false true))
          (assert (not (= buf -1)))
          (api.nvim_buf_set_name buf (.. "Qdir [" (get-buf-name-id) "]")))
        :else
        (set buf existing-buf))
    (api.nvim_buf_set_var buf :is_qdir true)
    ;; Triggers BufEnter
    (api.nvim_set_current_buf buf)
    ;; Triggers ftplugin, so must get called after setting the current buffer
    (api.nvim_buf_set_option buf :filetype :qdir)
    ;; We don't update the buffer name when changing the working directory
    ;; because that makes things a bit hairy. For instance, it introduces a bug
    ;; when changing to an alt buffer that was an Qdir buffer, and the directory
    ;; listing was out of sync with our state. So we instead update the
    ;; statusline manually.
    (M.update-statusline cwd)
    buf))

(lambda M.set-current-buf [buf]
  (when (and buf (vim.fn.bufexists buf))
    ;; Fail silently. It can happen if we've deleted the origin-buf
    (pcall api.nvim_set_current_buf buf)
    nil))

(lambda M.set-lines [buf start end strict-indexing replacement]
  ;; (set vim.opt.modifiable true)
  (api.nvim_buf_set_lines buf start end strict-indexing replacement)
  ;; (set vim.opt.modifiable false)
  nil)

(lambda M.get-line []
  (let [[row _col] (api.nvim_win_get_cursor 0)
        [fst] (api.nvim_buf_get_lines 0 (- row 1) row true)]
    (assert fst)))

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
  (vim.cmd "norm! :<esc>"))

M

