(local api vim.api)

(local M {})

(local buf-states {})

(λ M.set! [buf state]
  (tset buf-states (tostring buf) state)
  nil)

(λ M.remove! [buf]
  (table.remove buf-states (tostring buf))
  nil)

(λ M.get []
  (let [buf (api.nvim_get_current_buf)]
    (assert (not (= -1 buf)))
    (let [state (. buf-states (tostring buf))]
      (assert state))))

M

