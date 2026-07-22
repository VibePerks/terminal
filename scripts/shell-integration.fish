# VibePerks Terminal - shell integration (fish).
#
# Source this from your ~/.config/fish/config.fish. It renders the cached VibePerks sponsor
# line above each prompt and rebinds Enter so pressing it on a real command launches a
# background refresh. Rendering makes ZERO network calls - it only reads the local cache via
# `vibeperks-terminal render`.
#
# Set VIBEPERKS_TERMINAL_BIN to the binary path if it is not on PATH.

function __vibeperks_terminal_bin
    if test -n "$VIBEPERKS_TERMINAL_BIN"
        printf '%s\n' "$VIBEPERKS_TERMINAL_BIN"
    else
        printf '%s\n' "vibeperks-terminal"
    end
end

function __vibeperks_terminal_render --on-event fish_prompt
    test "$VIBEPERKS_TERMINAL_PROMPT_LINE" = "0"; and return 0
    set -l bin (__vibeperks_terminal_bin)
    command -v "$bin" >/dev/null 2>&1; or return 0
    set -l line ("$bin" render 2>/dev/null)
    test -n "$line"; or return 0
    printf '%s\n' "$line"
end

function __vibeperks_terminal_should_refresh --argument-names cmd
    set -l trimmed (string trim -- "$cmd")
    test -n "$trimmed"; or return 1
    string match -q '#*' -- "$trimmed"; and return 1
    string match -qr '^vibeperks-terminal([[:space:]]|$)' -- "$trimmed"; and return 1
    return 0
end

function __vibeperks_terminal_accept_line
    if test "$VIBEPERKS_TERMINAL_ENTER" != "0"
        set -l cmd (commandline -b)
        if __vibeperks_terminal_should_refresh "$cmd"
            set -l bin (__vibeperks_terminal_bin)
            if command -v "$bin" >/dev/null 2>&1
                begin
                    "$bin" refresh $fish_pid >/dev/null 2>&1
                end &
            end
        end
    end
    commandline -f execute
end

if status is-interactive
    bind \r __vibeperks_terminal_accept_line
end
