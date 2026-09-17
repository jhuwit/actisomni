cleanup_uv_lock_files = function(paths = c(tempdir(), dirname(tempdir()))) {
  paths = unique(normalizePath(paths, winslash = "/", mustWork = FALSE))
  paths = paths[dir.exists(paths)]

  lock_files = unlist(lapply(paths, function(path) {
    c(
      list.files(
        path = path,
        pattern = "^uv.*[.]lock$",
        full.names = TRUE,
        recursive = TRUE,
        include.dirs = FALSE
      ),
      list.files(
        path = path,
        pattern = "^torch-shm-dir.*",
        full.names = TRUE,
        recursive = TRUE,
        include.dirs = FALSE
      )
    )
  }))
  lock_files = unique(lock_files[file.exists(lock_files)])

  if (length(lock_files) > 0) {
    invisible(file.remove(lock_files))
  } else {
    invisible(logical())
  }
}
