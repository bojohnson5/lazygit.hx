;; lazygit.hx — open lazygit in an embedded terminal, refresh buffers on close,
;; and route lazygit's edit (e / E) into the running Helix instead of a nested $EDITOR.

(require "steel-pty/term.scm")
(require "helix/editor.scm")
(require "helix/misc.scm")
(require (prefix-in helix. "helix/commands.scm"))

(provide lazygit-open
         lazygit-open-here)

;;; --- state paths -----------------------------------------------------------

(define (getenv name)
  (with-handler (lambda (_) #f) (env-var name)))

(define *state-dir*
  (string-append (trim-end-matches (or (getenv "TMPDIR") "/tmp") "/")
                 "/lazygit-hx"))
(define *editlist* (string-append *state-dir* "/editlist"))
(define *override-config* (string-append *state-dir* "/config.yml"))
(define *edit-script* (string-append *state-dir* "/edit.sh"))

;;; --- find the user's lazygit config so our override merges on top ----------

(define (find-existing lst)
  (cond
    [(null? lst) #f]
    [(path-exists? (car lst)) (car lst)]
    [else (find-existing (cdr lst))]))

(define (user-lazygit-config)
  (define home (getenv "HOME"))
  (define xdg (getenv "XDG_CONFIG_HOME"))
  (find-existing
   (append
    (if (string? xdg) (list (string-append xdg "/lazygit/config.yml")) '())
    (if (string? home)
        (list (string-append home "/Library/Application Support/lazygit/config.yml")
              (string-append home "/.config/lazygit/config.yml"))
        '()))))

(define (config-file-arg)
  (define user (user-lazygit-config))
  (if (string? user)
      (string-append user "," *override-config*)   ;; merged left→right, ours wins
      *override-config*))

;;; --- generated override config + edit-list handling ------------------------

(define (write-edit-script!)
  (with-handler (lambda (_) void) (create-directory! *state-dir*))
  (define el *editlist*)
  (define content
    (string-append
     "#!/bin/sh\n"
     "# 1. queue the file for the plugin's on-exit hook to open\n"
     "if [ -n \"$2\" ]; then\n"
     "  printf '%s:%s\\n' \"$1\" \"$2\" >> \"" el "\"\n"
     "else\n"
     "  printf '%s\\n' \"$1\" >> \"" el "\"\n"
     "fi\n"
     "# 2. terminate the lazygit that launched us so the file opens right away.\n"
     "#    the PTY then closes, firing the plugin's reload+open drain.\n"
     "pid=$PPID\n"
     "while [ \"${pid:-0}\" -gt 1 ]; do\n"
     "  set -- $(ps -o ppid=,comm= -p \"$pid\" 2>/dev/null)\n"
     "  [ $# -ge 2 ] || break\n"
     "  parent=$1; shift; name=$*\n"
     "  case \"$name\" in\n"
     "    *lazygit*) kill \"$pid\" 2>/dev/null; break ;;\n"
     "  esac\n"
     "  pid=$parent\n"
     "done\n"))
  (define p (open-output-file *edit-script* #:exists 'truncate))
  (write-string content p)
  (close-output-port p))

(define (write-override-config!)
  (with-handler (lambda (_) void) (create-directory! *state-dir*))
  (define s *edit-script*)
  (define content
    (string-append
     "os:\n"
     "  editInTerminal: false\n"
     "  edit: 'sh " s " {{filename}}'\n"
     "  editAtLine: 'sh " s " {{filename}} {{line}}'\n"
     "  editAtLineAndWait: 'sh " s " {{filename}} {{line}}'\n"))
  (define p (open-output-file *override-config* #:exists 'truncate))
  (write-string content p)
  (close-output-port p))

;; Fresh, empty edit list per session so stale entries never leak in.
(define (reset-editlist!)
  (with-handler (lambda (_) void) (create-directory! *state-dir*))
  (let ([p (open-output-file *editlist* #:exists 'truncate)])
    (close-output-port p)))

;; After lazygit exits: open every queued path, cursor on the recorded line.
(define (drain-editlist!)
  (when (path-exists? *editlist*)
    (define contents
      (with-handler (lambda (_) "")
        (let* ([p (open-input-file *editlist*)]
               [s (read-port-to-string p)])
          (close-input-port p)
          s)))
    (for-each
     (lambda (entry)
       (unless (equal? entry "")
         (with-handler (lambda (_) void) (helix.open entry))))
     (split-many contents "\n"))
    (with-handler (lambda (_) void) (delete-file! *editlist*))))

;;; --- existing behavior + the new exit hook ---------------------------------

(define (parent-dir path)
  (trim-end-matches path (string-append (path-separator) (file-name path))))

(define (lazygit-reload!)
  (with-handler (lambda (_) void) (helix.reload-all))
  (with-handler (lambda (_) void) (helix.lsp-restart)))

;; Reload first (git-touched buffers refresh), then open what you pressed `e` on.
(define (lazygit-after!)
  (lazygit-reload!)
  (drain-editlist!))

(define (lazygit-in dir)
  (if (which "lazygit")
      (begin
        (reset-editlist!)
        (write-edit-script!)
        (write-override-config!)
        (open-program-in-terminal/args
         "lazygit" "lazygit"
         (list "--use-config-file" (config-file-arg))
         dir
         lazygit-after!))
      (set-status! "lazygit: binary not found on PATH")))

;;@doc
;; Open lazygit at project root.
(define (lazygit-open)
  (lazygit-in (helix-find-workspace)))

;;@doc
;; Open lazygit at the current file
(define (lazygit-open-here)
  (define path (editor-document->path (editor->doc-id (editor-focus))))
  (lazygit-in (if (string? path) (parent-dir path) (helix-find-workspace))))
