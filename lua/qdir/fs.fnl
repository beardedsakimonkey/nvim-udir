(local uv vim.loop)
(local u (require :qdir.util))

(local M {})

(lambda assert-readable [path]
  (assert (uv.fs_access path :R))
  nil)

(lambda assert-doesnt-exist [path]
  (assert (not (uv.fs_access path :R)) (string.format "%q already exists" path))
  nil)

(lambda delete-file [path]
  (assert (uv.fs_unlink path))
  (u.delete-buffer path))

(lambda delete-dir [path]
  (let [fs (assert (uv.fs_scandir path))]
    (var done? false)
    (while (not done?)
      (let [(name type) (uv.fs_scandir_next fs)]
        (if (not name) (set done? true) :else
            (if (= type :directory) (delete-dir (u.join-path path name))
                :else (delete-file (u.join-path path name))))))
    (assert (uv.fs_rmdir path))))

(lambda is-symlink? [path]
  (local link (uv.fs_readlink path))
  (not= link nil))

(fn copy-file [src dest]
  (assert (uv.fs_copyfile src dest)))

;; TODO: Factor our the scandir stuff
(fn copy-dir [src dest]
  (local stat (assert (uv.fs_stat src)))
  (assert (uv.fs_mkdir dest stat.mode))
  ;; For each entry in `src`, copy it to `dest`
  (let [fs (assert (uv.fs_scandir src))]
    (var done? false)
    (while (not done?)
      (let [(name type) (uv.fs_scandir_next fs)]
        (if (not name) (set done? true) :else
            (let [src2 (u.join-path src name)
                  dest2 (u.join-path dest name)]
              (if (= type :directory) (copy-dir src2 dest2)
                  :else (copy-file src2 dest2))))))))

;; --------------------------------------
;; PUBLIC
;; --------------------------------------

(lambda M.canonicalize [path]
  "Returns the absolute filename, with symlinks resolved, extra `/` removed, and `.` and `..` resolved."
  (assert (uv.fs_realpath path)))

;; NOTE: Symlink dirs are considered directories
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
  (let [parent-dir (M.canonicalize (.. dir u.sep ".."))]
    (assert-readable parent-dir)
    parent-dir))

(lambda M.basename [path]
  (local path-without-trailing-slash
         (if (vim.endswith path u.sep) (path:sub 1 -2) path))
  (local split (vim.split path-without-trailing-slash u.sep))
  (. split (length split)))

(lambda M.delete [path]
  (if (and (M.is-dir? path) (not (is-symlink? path))) (delete-dir path)
      :else (delete-file path))
  nil)

(lambda M.create-dir [path]
  (assert-doesnt-exist path)
  ;; 755 = RWX for owner, RX for group/other
  (local mode (tonumber :755 8))
  (assert (uv.fs_mkdir path mode))
  nil)

(lambda M.create-file [path]
  (assert-doesnt-exist path)
  ;; 644 = RW for owner, R for group/other
  (local mode (tonumber :644 8))
  (assert (uv.fs_open path :w mode))
  nil)

(lambda M.rename [path newpath]
  (assert-doesnt-exist newpath)
  (assert (uv.fs_rename path newpath))
  nil)

(lambda M.copy [src dest]
  (assert-doesnt-exist dest)
  (if (M.is-dir? src) (copy-dir src dest)
      :else (copy-file src dest)))

M

