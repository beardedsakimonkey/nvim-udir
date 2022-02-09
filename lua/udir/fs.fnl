(local uv vim.loop)
(local u (require :udir.util))

;; TODO: `assert` should only be used when it's indicative of a bug, or
;; something is unrecoverable, not when the user does something silly like
;; rename a file to itself.

(local M {})

(lambda assert-doesnt-exist [path]
  (assert (not (uv.fs_access path :R)) (string.format "%q already exists" path))
  nil)

(macro foreach-entry [path syms form]
  (let [name-sym (. syms 1)
        type-sym (. syms 2)]
    (assert (sym? name-sym))
    (assert (sym? type-sym))
    (assert (not= nil form))
    `(let [fs# (assert (uv.fs_scandir ,path))]
       (var done?# false)
       (while (not done?#)
         (let [(,name-sym ,type-sym) (uv.fs_scandir_next fs#)]
           (if (not ,name-sym)
               (do
                 (set done?# true)
                 ;; If the first return value is nil and the second
                 ;; return value is non-nil then there was an error.
                 (assert (not ,type-sym)))
               ,form))))))

(lambda delete-file [path]
  (assert (uv.fs_unlink path))
  (u.delete-buffer path))

(lambda delete-dir [path]
  (foreach-entry path [name type]
                 (if (= type :directory)
                     (delete-dir (u.join-path path name))
                     (delete-file (u.join-path path name))))
  (assert (uv.fs_rmdir path)))

(lambda move [src dest]
  (assert (uv.fs_rename src dest)))

(lambda copy-file [src dest]
  (assert (uv.fs_copyfile src dest)))

(lambda copy-dir [src dest]
  (local stat (assert (uv.fs_stat src)))
  (assert (uv.fs_mkdir dest stat.mode))
  (foreach-entry src [name type]
                 (let [src2 (u.join-path src name)
                       dest2 (u.join-path dest name)]
                   (if (= type :directory)
                       (copy-dir src2 dest2)
                       (copy-file src2 dest2)))))

(lambda symlink? [path]
  (local link (uv.fs_readlink path))
  (not= nil link))

;; --------------------------------------
;; PUBLIC
;; --------------------------------------

(lambda M.canonicalize [?path]
  "Returns the absolute filename, with symlinks resolved, extra `/` removed, and `.` and `..` resolved."
  (assert (uv.fs_realpath ?path)))

;; NOTE: Symlink dirs are considered directories
(lambda M.dir? [path]
  (local ?file-info (uv.fs_stat path))
  (if (not= nil ?file-info) (= :directory ?file-info.type) false))

(lambda M.list [path]
  "Returns a sequential table of {: name : type} items"
  (local ret [])
  (foreach-entry path [name type] ;; `type` can be "file", "directory", "link",
                 ;; `name` is the file's basename
                 (table.insert ret {: name : type}))
  ret)

(lambda M.assert-readable [path]
  (assert (uv.fs_access path :R))
  nil)

(lambda M.get-parent-dir [dir]
  "Returns the absolute path of the parent directory"
  (local parent-dir (M.canonicalize (.. dir u.sep "..")))
  (M.assert-readable parent-dir)
  parent-dir)

(lambda M.basename [?path]
  ;; Strip trailing slash
  (local ?path (if (vim.endswith ?path u.sep) (?path:sub 1 -2) ?path))
  (local split (vim.split ?path u.sep))
  (. split (length split)))

(lambda M.delete [path]
  (M.assert-readable path)
  (if (and (M.dir? path) (not (symlink? path)))
      (delete-dir path)
      (delete-file path))
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
  (local fd (assert (uv.fs_open path :w mode)))
  (assert (uv.fs_close fd))
  nil)

(lambda M.copy-or-move [should-move src dest]
  (assert (not= src dest))
  (M.assert-readable src)
  (if (M.dir? src)
      (let [op (if should-move move copy-dir)]
        ;; Moving from a dir to a file should fail
        (assert (M.dir? dest))
        ;; Moving from a dir to a dir should move to a subdirectory
        (op src (u.join-path dest (M.basename src))))
      (let [op (if should-move move copy-file)]
        (if (M.dir? dest)
            ;; Moving from a file to a dir should move it to a subdirectory
            (op src (u.join-path dest (M.basename src)))
            ;; Moving from a file to a file should overwrite the file
            (op src dest)))))

M

