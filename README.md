# lazygit.hx

Open [lazygit](https://github.com/jesseduffield/lazygit) in an embedded, floating
terminal inside [Helix](https://helix-editor.com/), and automatically reload your
open buffers when you quit. Built on top of
[steel-pty](https://github.com/mattwparas/steel-pty).

`:lazygit-open` drops you into lazygit for the current project; `:lazygit-open-here`
opens it for the repository containing the file you're editing. Quit lazygit with
`q` and the panel tears itself down and refreshes anything git changed on disk.

## Requirements

- A build of Helix with the **Steel plugin system** (the
  [`mattwparas/helix`](https://github.com/mattwparas/helix) `steel-event-system`
  branch), and the `forge` package manager that ships with it.
- [`lazygit`](https://github.com/jesseduffield/lazygit) installed and on your `PATH`.
- A patched **steel-pty**. lazygit.hx depends on
  [`bojohnson5/steel-pty`](https://github.com/bojohnson5/steel-pty) rather than
  upstream, because it adds the embedded-terminal launcher this plugin calls
  (`open-program-in-terminal` / `create-native-pty-system-with-cwd!`) plus a number
  of rendering fixes lazygit needs: truecolor handling, reverse-video selections,
  UTF-8 handling across reads, clean process exit, and cursor visibility. Upstream
  steel-pty does not currently expose these, so the plugin will not work against it.
  The dependency is declared in `cog.scm` and `forge` pulls it in for you.

Developed and tested on macOS (Apple Silicon).

## Installation

```sh
forge pkg install --git https://github.com/bojohnson5/lazygit.hx
```

This also resolves and installs the steel-pty dependency, including building its
native dylib. Then load the plugin from your `init.scm` (see below) and restart
Helix.

> **Note:** `forge` caches packages by name. If you update either repo and a
> reinstall reports "Already up to date," clear the cached copies first:
>
> ```sh
> rm -rf ~/.local/share/steel/cog-sources/{lazygit.hx,steel-pty} \
>        ~/.local/share/steel/cogs/{lazygit,steel-pty}
> forge pkg install --git https://github.com/bojohnson5/lazygit.hx
> ```

## Usage

Add the require and a keybinding to your `init.scm`. Requiring the plugin
registers `:lazygit-open` and `:lazygit-open-here` as typable commands.

```scheme
(require "lazygit/lazygit.scm")
(require "helix/keymaps.scm")

(keymap (global)
        (normal
          (space
            (g ":lazygit-open")
            (G ":lazygit-open-here"))))
```

- `space g` → open lazygit at the project root
- `space G` → open lazygit for the current file's repository

You can of course bind them however you like, or invoke `:lazygit-open` /
`:lazygit-open-here` directly from the command prompt.

Two things matter for the space (which-key) menu to show these with labels:

1. **`require` the plugin before the `(keymap …)` block.** The menu's descriptions
   are built when the keymap is merged, by looking up each command's docstring — if
   the plugin hasn't loaded yet, the entries come out blank.
2. **Fully restart Helix** after changing `init.scm` (not `:config-reload`), so the
   keymap and its menu are rebuilt.

Bind the commands to direct keys (leaves) rather than nesting them under a custom
prefix if you want them labeled in the menu — user-defined prefixes render without
a label.

## Configuration

**Window size.** The terminal floats centered over the editor. Adjust how much of
the screen it takes with steel-pty's `set-terminal-fraction`, e.g. in `init.scm`:

```scheme
(set-terminal-fraction 9/10)
```

**Selection appearance.** lazygit's default `selectedLineBgColor` is `blue`, which
renders as a solid bar. If you prefer, set it to something subtle in
`~/.config/lazygit/config.yml` to match your Helix theme:

```yaml
gui:
  theme:
    selectedLineBgColor:
      - "#45475a"
    selectedRangeBgColor:
      - "#45475a"
```

## How it works

lazygit is launched directly as the terminal's process (no intervening shell),
rooted at the target directory, and rendered into a floating terminal component
driven by steel-pty's PTY + terminal emulator. Because lazygit is the PTY process
itself, quitting it closes the PTY; the plugin detects that, removes the panel, and
runs `:reload-all` so buffers touched by git operations (checkouts, resets, stashes)
are re-read from disk.

## Limitations & notes

- **Verbose commits open `$EDITOR` inside the panel.** Pressing `C` / `e` for a full
  commit message makes lazygit spawn `$EDITOR` *inside the embedded terminal*. Set
  lazygit's `git.commit.verbose` off, point `core.editor` at something lightweight,
  or use lazygit's inline commit input, which doesn't shell out.
- **Requires the steel-pty fork** described under Requirements; it will not work with
  upstream steel-pty.
- Text attributes beyond color (bold, italic, underline) are not currently rendered,
  so some elements may look flatter than in a standalone terminal. Colors, selections,
  and unicode render correctly.

## Credits

Built on [steel-pty](https://github.com/mattwparas/steel-pty) by
[@mattwparas](https://github.com/mattwparas), which provides the PTY and terminal
emulation this plugin renders into.
