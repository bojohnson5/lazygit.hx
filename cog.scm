(define package-name 'lazygit)
(define version "0.1.0")

;; Depends on steel-pty for the embedded-terminal dylib + renderer.
;; This must be a build of steel-pty that provides `open-shell-command-in-terminal`
;; and `close-command-terminal` (see the small addition in the README). Point this
;; at your fork until/unless it lands upstream in mattwparas/steel-pty.
(define dependencies
  '((#:name steel-pty #:git-url "https://github.com/bojohnson5/steel-pty.git")))
