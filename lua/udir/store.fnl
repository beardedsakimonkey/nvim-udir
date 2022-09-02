(local api vim.api)

(local buf-states {})

(fn set! [buf state]
  (tset buf-states (tostring buf) state))

(fn remove! [buf]
  (tset buf-states (tostring buf) nil))

(fn get [?buf]
  (let [buf (or ?buf (api.nvim_get_current_buf))]
    (assert (not (= -1 buf)))
    (let [state (. buf-states (tostring buf))]
      (assert state))))

{: set! : remove! : get}

