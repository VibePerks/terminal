# VibePerks Terminal - shell integration (zsh).
#
# Source this from your ~/.zshrc. It renders the cached VibePerks sponsor line above each
# prompt and, when you press Enter on a real command, launches a background refresh that
# serves the next sponsor and reports the one you just saw. Rendering makes ZERO network
# calls - it only reads the local ad cache via `vibeperks-terminal render`. All network
# runs detached, so your prompt is never blocked.
#
# Set VIBEPERKS_TERMINAL_BIN to the binary path if it is not on PATH.
# Set VIBEPERKS_TERMINAL_PROMPT_LINE=0 to hide the line. VIBEPERKS_TERMINAL_ENTER=0 disables
# the Enter-triggered refresh (rendering still works).

__vibeperks_terminal_bin() {
  print -r -- "${VIBEPERKS_TERMINAL_BIN:-vibeperks-terminal}"
}

# __vibeperks_terminal_render prints the cached sponsor line (or nothing). Quiet and instant.
__vibeperks_terminal_render() {
  [[ "${VIBEPERKS_TERMINAL_PROMPT_LINE:-1}" != "0" ]] || return 0
  local bin line
  bin="$(__vibeperks_terminal_bin)"
  command -v "$bin" >/dev/null 2>&1 || return 0
  line="$("$bin" render 2>/dev/null)" || return 0
  [[ -n "$line" ]] || return 0
  print -r -- "$line"
}

# __vibeperks_terminal_should_refresh skips empty lines, comments, and our own commands so a
# human running real work is what rotates the sponsor.
__vibeperks_terminal_should_refresh() {
  local cmd="${1#"${1%%[![:space:]]*}"}" # left-trim
  [[ -n "$cmd" ]] || return 1
  [[ "$cmd" != \#* ]] || return 1
  case "${cmd%%[[:space:]]*}" in
    vibeperks-terminal | vibeperks-terminal.exe) return 1 ;;
  esac
  return 0
}

__vibeperks_terminal_refresh() {
  [[ "${VIBEPERKS_TERMINAL_ENTER:-1}" != "0" ]] || return 0
  __vibeperks_terminal_should_refresh "$1" || return 0
  local bin
  bin="$(__vibeperks_terminal_bin)"
  command -v "$bin" >/dev/null 2>&1 || return 0
  { "$bin" refresh "$$" >/dev/null 2>&1 } &!
}

__vibeperks_terminal_accept_line() {
  __vibeperks_terminal_refresh "$BUFFER"
  zle .accept-line
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd __vibeperks_terminal_render
zle -N accept-line __vibeperks_terminal_accept_line 2>/dev/null || true
