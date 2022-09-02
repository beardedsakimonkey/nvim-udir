(local uv vim.loop)
(local u (require :udir.util))

;; TODO: `assert` should only be used when it's indicative of a bug, or
;; something is unrecoverable, not when the user does something silly like
;; rename a file to itself.

;; NOTE: Symlink dirs are considered directories
(fn dir? [path]
  (local ?file-info (uv.fs_stat path))
  (if (not= nil ?file-info) (= :directory ?file-info.type) false))

(macro foreach-entry [path syms form]
  (let [name-sym (. syms 1)
        type-sym (. syms 2)]
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

(fn delete-file [path]
  (assert (uv.fs_unlink path))
  (u.delete-buffers path))

(fn delete-dir [path]
  (foreach-entry path [name type]
                 (if (= type :directory)
                     (delete-dir (u.join-path path name))
                     (delete-file (u.join-path path name))))
  (assert (uv.fs_rmdir path)))

(fn move [src dest]
  (assert (uv.fs_rename src dest))
  (when (not (dir? src))
    (u.rename-buffers src dest)))

(fn copy-file [src dest]
  (assert (uv.fs_copyfile src dest)))

(fn copy-dir [src dest]
  (local stat (assert (uv.fs_stat src)))
  (assert (uv.fs_mkdir dest stat.mode))
  (foreach-entry src [name type]
                 (let [src2 (u.join-path src name)
                       dest2 (u.join-path dest name)]
                   (if (= type :directory)
                       (copy-dir src2 dest2)
                       (copy-file src2 dest2)))))

(fn symlink? [path]
  (local link (uv.fs_readlink path))
  (not= nil link))

(fn abs? [path]
  (let [c (path:sub 1 1)]
    (= "/" c)))

(fn expand-tilde [path]
  (local res (path:gsub "^~" (os.getenv :HOME)))
  res)

(fn realpath [?path]
  (assert (uv.fs_realpath ?path)))

(fn executable? [path]
  (local ret (uv.fs_access path :X))
  ret)

(fn list [path]
  (local ret [])
  ;; `type` can be "file", "directory", "link". `name` is the file's basename
  (foreach-entry path [name type] (table.insert ret {: name : type}))
  ret)

(fn exists? [path]
  (uv.fs_access path ""))

(fn get-parent-dir [dir]
  (local parts (vim.split dir u.sep))
  (table.remove parts)
  (local parent (table.concat parts u.sep))
  (assert (exists? parent))
  parent)

(fn basename [path]
  ;; Strip trailing slash
  (local path (if (vim.endswith path u.sep) (path:sub 1 -2) path))
  (local parts (vim.split path u.sep))
  (. parts (length parts)))

(fn delete [path]
  (if (and (dir? path) (not (symlink? path)))
      (delete-dir path)
      (delete-file path)))

(fn create-dir [path]
  (if (exists? path) (u.err (: "%q already exists" :format path))
      (do
        ;; 755 = RWX for owner, RX for group/other
        (local mode (tonumber :755 8))
        (assert (uv.fs_mkdir path mode)))))

(fn create-file [path]
  (if (exists? path) (u.err (: "%q already exists" :format path))
      (do
        ;; 644 = RW for owner, R for group/other
        (local mode (tonumber :644 8))
        (local fd (assert (uv.fs_open path :w mode)))
        (assert (uv.fs_close fd)))))

(fn copy-or-move [move? src dest cwd]
  (assert (exists? src))
  ;; Canonicalize
  (local dest (expand-tilde dest))
  ;; Make absolute
  (local dest (if (abs? dest) dest (u.join-path cwd dest)))
  (assert (not= src dest))
  (if (dir? src)
      (let [op (if move? move copy-dir)]
        ;; Moving from a dir to a file should fail
        (assert (dir? dest))
        ;; Moving from a dir to a dir should move to a subdirectory
        (op src (u.join-path dest (basename src))))
      (let [op (if move? move copy-file)]
        (if (dir? dest)
            ;; Moving from a file to a dir should move it to a subdirectory
            (op src (u.join-path dest (basename src)))
            ;; Moving from a file to a file should overwrite the file
            (op src dest)))))

{: realpath
 : dir?
 : executable?
 : list
 : exists?
 : get-parent-dir
 : basename
 : delete
 : create-dir
 : create-file
 : copy-or-move}

