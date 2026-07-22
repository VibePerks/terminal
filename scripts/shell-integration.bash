# VibePerks Terminal - shell integration (bash).
#
# Source this from your ~/.bashrc. It renders the cached VibePerks sponsor line above each
# prompt (via PROMPT_COMMAND). Rendering makes ZERO network calls - it only reads the local
# cache via `vibeperks-terminal render`.
#
# Bash Enter-wrapping is EXPERIMENTAL: Readline has no clean "run this, then accept" hook, so
# the refresh trigger is opt-in via VIBEPERKS_TERMINAL_BASH_ENTER_EXPERIMENTAL=1. The prompt
# line renders regardless.
#
# Set VIBEPERKS_TERMINAL_BIN to the binary path if it is not on PATH.

__vibeperks_terminal_bin() {
  printf '%s\n' "${VIBEPERKS_TERMINAL_BIN:-vibeperks-terminal}"
}

__vibeperks_terminal_render() {
  [[ "${VIBEPERKS_TERMINAL_PROMPT_LINE:-1}" != "0" ]] || return 0
  local bin line
  bin="$(__vibeperks_terminal_bin)"
  command -v "$bin" >/dev/null 2>&1 || return 0
  line="$("$bin" render 2>/dev/null)" || return 0
  [[ -n "$line" ]] || return 0
  printf '%s\n' "$line"
}

__vibeperks_terminal_install_prompt() {
  [[ $- == *i* ]] || return 0
  case ";${PROMPT_COMMAND:-};" in
    *";__vibeperks_terminal_render;"*) ;;
    *) PROMPT_COMMAND="__vibeperks_terminal_render${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
  esac
}

__vibeperks_terminal_should_refresh() {
  local cmd="${1#"${1%%[![:space:]]*}"}"
  [[ -n "$cmd" ]] || return 1
  [[ "$cmd" != \#* ]] || return 1
  case "${cmd%%[[:space:]]*}" in
    vibeperks-terminal | vibeperks-terminal.exe) return 1 ;;
  esac
  return 0
}

__vibeperks_terminal_enter_hook() {
  __vibeperks_terminal_should_refresh "${READLINE_LINE-}" || return 0
  local bin
  bin="$(__vibeperks_terminal_bin)"
  command -v "$bin" >/dev/null 2>&1 || return 0
  ( "$bin" refresh "$$" >/dev/null 2>&1 ) &
  return 0
}

__vibeperks_terminal_install_enter() {
  [[ $- == *i* ]] || return 0
  [[ "${VIBEPERKS_TERMINAL_BASH_ENTER_EXPERIMENTAL:-0}" == "1" ]] || return 0
  bind -x '"\C-x\C-v": __vibeperks_terminal_enter_hook' 2>/dev/null || return 0
  bind '"\C-m": "\C-x\C-v\C-j"' 2>/dev/null || return 0
}

__vibeperks_terminal_install_prompt
__vibeperks_terminal_install_enter
