# VibePerks for the Terminal

A bare-shell adapter for [VibePerks](https://vibeperks.ai). It shows a single sponsor
sentence above your shell prompt and rewards you for the developer work you already do.
There is no host CLI to integrate with - the shell itself is the surface.

```text
Make your AI pay for itself - VibePerks.ai
you@machine ~/project %
```

The sponsor line is rendered from a local cache and makes **zero** network calls, so your
prompt stays instant and works offline. When you press Enter on a real command, a detached
background process records the sponsor you just saw and serves the next one - your shell is
never blocked or broken.

## How it works

This adapter is a thin Go wrapper around the shared VibePerks `core` package (the same one
that powers the Claude Code and Codex adapters). It reuses that core verbatim via a Go
`replace` directive - no fork - so it inherits the exact backend contract, device-token
auth, atomic local cache, opt-out handling, and the `Guard` safety boundary that swallows
any error before it can reach your shell.

| Piece | Role |
|-------|------|
| `vibeperks-terminal render` | Print the cached sponsor line. Network-free; marks the ad displayed. Run by the prompt hook. |
| `vibeperks-terminal refresh` | Detached background worker: report the prior impression, serve + cache the next ad, flush the buffer. Run when you press Enter on a real command. |
| `vibeperks-terminal end` | Report the currently displayed impression (optional; wire to your shell exit hook). |
| `vibeperks-terminal login <token>` | Save the device token into the shared `~/.vibeperks/config.json`. |
| `vibeperks-terminal optout` / `optin` | Toggle ad serving on or off. |

The shell integration scripts wire two things: a **prompt hook** that runs `render` before
each prompt, and an **Enter hook** that launches `refresh` in the background for any real
command (empty lines, comments, and `vibeperks-terminal ...` itself are skipped).

```text
press Enter -> refresh (detached): report prior impression + serve next ad + cache it
next prompt -> render: print the freshly cached sponsor line (instant, offline)
```

### Why Go (and not the reference language)?

The reference implementation was a standalone Rust binary that reimplemented the whole ad
pipeline. This adapter is Go instead so it can **reuse the shared `core` package** that all
the other VibePerks adapters already use. That means one battle-tested implementation of the
serve/impression contract, auth, caching, and privacy rules - rather than a second copy in a
new toolchain to keep in sync. The reference's value was its shell-integration UX (the
Enter-wrapper), which is preserved here as the shell scripts.

## Supported shells

| Shell | Prompt line | Enter-triggered refresh |
|-------|-------------|--------------------------|
| zsh | yes | yes (`accept-line` widget) |
| fish | yes | yes (`bind \r`) |
| PowerShell | yes | yes (PSReadLine `Enter` handler) |
| bash | yes | experimental - set `VIBEPERKS_TERMINAL_BASH_ENTER_EXPERIMENTAL=1` |

Bash Readline has no clean "run this, then accept the line" hook, so its Enter-wrapping is
opt-in. The prompt line renders on every shell.

## Install

macOS / Linux:

```sh
git clone https://github.com/VibePerks/terminal && cd terminal && ./install.sh
```

Windows (PowerShell):

```powershell
git clone https://github.com/VibePerks/terminal; cd terminal; ./install.ps1
```

The installer writes a managed block to your shell rc (re-running replaces the block,
never duplicates it) and prepares the binary. **Go is not required**: the prebuilt binary
for your platform is downloaded from the GitHub Release and cached the first time it runs
(the Windows installer downloads it directly). Then open a new shell and authenticate:

```sh
vibeperks-terminal login <device-token>
```

Mint a device token from the VibePerks dashboard (`POST /v1/devices`). The token is shared
with the Claude Code and Codex adapters via `~/.vibeperks/config.json`, so one login
configures all of them.

## Uninstall

macOS / Linux:

```sh
./uninstall.sh
```

Windows (PowerShell):

```powershell
./uninstall.ps1
```

This removes the VibePerks block from your shell rc, so the sponsor line and Enter hook
stop loading in new shells. Your token and cached ad live in `~/.vibeperks/` - delete that
folder if you want to remove them too. To just pause it without uninstalling, run
`vibeperks-terminal optout`.

## Configuration

| Variable | Purpose |
|----------|---------|
| `VIBEPERKS_TERMINAL_BIN` | Path to the binary if it is not on `PATH`. |
| `VIBEPERKS_HOME` | Override the config/cache dir (default `~/.vibeperks`). |
| `VIBEPERKS_API` | Override the API base URL. |
| `VIBEPERKS_RELEASE_CHANNEL` | Binary release channel to download (`latest` default, or `dev-latest`). |
| `VIBEPERKS_TERMINAL_PROMPT_LINE=0` | Hide the sponsor line (rendering off). |
| `VIBEPERKS_TERMINAL_ENTER=0` | Disable the Enter-triggered refresh. |
| `VIBEPERKS_TERMINAL_BASH_ENTER_EXPERIMENTAL=1` | Enable bash Enter-wrapping. |

## Build & test

```sh
./build.sh          # build bin/vibeperks-terminal.real for the host
DIST=1 ./build.sh   # cross-compile release binaries
( cd src && go test ./... )
```

## License

PolyForm Shield 1.0.0 - see [LICENSE](LICENSE).