(local api vim.api)

(local M {})

(local buf-states {})

(λ M.set! [buf state]
  (tset buf-states (tostring buf) state)
  nil)

(λ M.remove! [buf]
  (tset buf-states (tostring buf) nil)
  nil)

(λ M.get [?buf]
  (let [buf (or ?buf (api.nvim_get_current_buf))]
    (assert (not (= -1 buf)))
    (let [state (. buf-states (tostring buf))]
      (assert state))))

M

