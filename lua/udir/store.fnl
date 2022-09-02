(local api vim.api)

(local M {})

(local buf-states {})

(fn M.set! [buf state]
  (tset buf-states (tostring buf) state))

(fn M.remove! [buf]
  (tset buf-states (tostring buf) nil))

(fn M.get [?buf]
  (let [buf (or ?buf (api.nvim_get_current_buf))]
    (assert (not (= -1 buf)))
    (let [state (. buf-states (tostring buf))]
      (assert state))))

M

