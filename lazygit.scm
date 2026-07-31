;; lazygit.hx — open lazygit in an embedded terminal, refresh buffers on close.
;;
;; Built on steel-pty: the shell is spawned in a PTY and we `exec lazygit` into
;; it, so quitting lazygit (`q`) closes the PTY, which steel-pty reports as EOF.
;; That EOF is our signal to tear the panel down and reload buffers from disk so
;; anything git touched (checkouts, stashes, resets) shows up immediately.

;; Pulls in `open-shell-command-in-terminal` and `close-command-terminal`.
;; Requiring this also loads steel-pty's terminal module (idempotent), so you do
;; not need a separate `(require "steel-pty/term.scm")` in init.scm.
(require "steel-pty/term.scm")

(require "helix/editor.scm")   ;; editor-focus, editor->doc-id, editor-document->path
(require "helix/misc.scm")     ;; set-status!
(require (prefix-in helix. "helix/commands.scm")) ;; helix.reload-all (typable command)

(provide lazygit-open
         lazygit-open-here)

;; Directory of a file path, e.g. /a/b/c.rs -> /a/b
(define (parent-dir path)
  (trim-end-matches path (string-append (path-separator) (file-name path))))

;; Reload every open buffer from disk after lazygit exits. Guarded so a modified
;; buffer that refuses to reload can't take down the callback.
(define (lazygit-reload!)
  (with-handler (lambda (_) void) (helix.reload-all)))

;; Spawn lazygit rooted at `dir`. `cd` first so git discovers the right repo,
;; then `exec` so lazygit replaces the shell and its exit closes the PTY.
(define (lazygit-in dir)
  (if (which "lazygit")
      (open-program-in-terminal "lazygit" "lazygit" dir lazygit-reload!)
      (set-status! "lazygit: binary not found on PATH")))

;;@doc
;; Open lazygit for the current workspace / project root.
(define (lazygit-open)
  (lazygit-in (helix-find-workspace)))

;;@doc
;; Open lazygit for the repository containing the current file
;; (falls back to the workspace root when no file is focused).
(define (lazygit-open-here)
  (define path (editor-document->path (editor->doc-id (editor-focus))))
  (lazygit-in (if (string? path) (parent-dir path) (helix-find-workspace))))

;;@doc
;; Close the lazygit terminal from the editor side. Normally unnecessary —
;; pressing `q` inside lazygit closes it and triggers the reload automatically.
(define (lazygit-close)
  (close-command-terminal))
