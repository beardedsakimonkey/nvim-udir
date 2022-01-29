(local api vim.api)

(local M {})

(local buf-states {})

(lambda M.set! [buf state]
  (tset buf-states (tostring buf) state)
  nil)

(lambda M.remove! [buf]
  (table.remove buf-states (tostring buf))
  nil)

(lambda M.get []
  (let [buf (api.nvim_get_current_buf)]
    (assert (not (= buf -1)))
    (let [state (. buf-states (tostring buf))]
      (assert state))))

M

