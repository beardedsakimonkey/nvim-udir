(local uv vim.loop)

(local M {})

(lambda assert-readable [path]
  (assert (uv.fs_access path :R))
  nil)

(lambda assert-doesnt-exist [path]
  (assert (not (uv.fs_access path :R)) (string.format "%q already exists" path))
  nil)

;; TODO: Use libuv
(lambda delete-dir [path]
  (vim.fn.system (.. "rm -rf " (vim.fn.fnameescape path))))

;; --------------------------------------
;; PUBLIC
;; --------------------------------------

(lambda M.canonicalize [path]
  "Returns the absolute filename, with symlinks resolved, extra `/` removed, and `.` and `..` resolved."
  (assert (uv.fs_realpath path)))

(lambda M.is-dir? [path]
  (assert-readable path)
  (let [file-info (uv.fs_stat path)]
    (= file-info.type :directory)))

(lambda M.list [path]
  "Returns a sequential table of {: name : type} items"
  (let [fs (assert (uv.fs_scandir path))
        ret []]
    (var done? false)
    (while (not done?)
      (let [(name type err-name) (uv.fs_scandir_next fs)]
        (if (= name nil) (do
                           (set done? true)
                           ;; If the first return value is nil and the second
                           ;; return value is non-nil then there was an error.
                           (assert (not type)))
            ;; `type` can be "file", "directory", "link"
            ;; `name` is the file's basename
            (table.insert ret {: name : type}))))
    ret))

(lambda M.get-parent-dir [dir]
  "Returns the absolute path of the parent directory"
  (let [parent-dir (M.canonicalize (.. dir "/.."))]
    (assert-readable parent-dir)
    parent-dir))

(lambda M.basename [path]
  (local path-without-trailing-slash
         (if (vim.endswith path "/") (path:sub 1 -1) path))
  (local split (vim.split path-without-trailing-slash "/"))
  (. split (length split)))

(lambda M.delete [path]
  (if (M.is-dir? path) (delete-dir path)
      :else (assert (uv.fs_unlink path))))

(lambda M.create-dir [path]
  (assert-doesnt-exist path)
  ;; 755 = RWX for owner, RX for group/other
  (local mode (tonumber :755 8))
  (assert (uv.fs_mkdir path mode)))

(lambda M.create-file [path]
  (assert-doesnt-exist path)
  ;; 644 = RW for owner, R for group/other
  (local mode (tonumber :644 8))
  (assert (uv.fs_open path :w mode))
  nil)

(lambda M.rename [path newpath]
  (assert-doesnt-exist newpath)
  (assert (uv.fs_rename path newpath)))

M

