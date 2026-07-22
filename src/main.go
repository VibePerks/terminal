// Command vibeperks-terminal is the bare-shell adapter for VibePerks: a thin wrapper that
// reuses the shared package core for all network, auth, cache, and privacy concerns. There
// is no host CLI here - the shell itself is the surface. The shell integration prints the
// cached sponsor line above the prompt (the `render` command, network-free) and triggers a
// background `refresh` when a human presses Enter on a real command. Every command runs
// inside core.Guard, the single boundary where errors are swallowed so the user's shell is
// never broken.
package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"strings"
	"time"

	"vibeperks/core"
)

// version is stamped at build time via -ldflags "-X main.version=...".
var version = "dev"

const cli = "terminal"

func main() {
	if len(os.Args) < 2 {
		return
	}
	switch os.Args[1] {
	case "version", "-v", "--version":
		fmt.Println(version)
		return
	}
	core.Guard(func() error { return dispatch(os.Args[1]) })
}

func dispatch(cmd string) error {
	dir := core.ConfigDir()
	switch cmd {
	case "render":
		return cmdRender(dir)
	case "refresh":
		return cmdRefresh(dir)
	case "end":
		return cmdEnd(dir)
	case "login":
		return cmdLogin(dir)
	case "optout":
		return cmdOptOut(dir, true)
	case "optin":
		return cmdOptOut(dir, false)
	}
	return nil
}

func meta(sessionID string) core.Meta {
	return core.Meta{
		CLI:           cli,
		CLIVersion:    os.Getenv("VIBEPERKS_TERMINAL_VERSION"),
		PluginVersion: version,
		SessionID:     sessionID,
	}
}

// cmdRender prints the cached ad line for the prompt surface. It makes no network call and
// marks the ad as displayed, so the line is always instant and works offline. The ad is
// shown with a bold sentence and an underlined, clickable domain link; when the device
// token was rejected it prints a sign-in notice in non-bold white instead.
func cmdRender(dir string) error {
	adLine, domain, websiteURL, notice, err := core.Render(dir, time.Now().Unix(), "vibeperks-terminal login")
	if err != nil {
		return err
	}
	if adLine != "" {
		adLine = stripAccents(adLine)
		domain = stripAccents(domain)
		if notice {
			adLine = core.White(adLine)
		} else {
			adLine = core.StyleAdLine(adLine, domain, websiteURL)
		}
		fmt.Println(adLine)
	}
	return nil
}

// accentReplacer maps Spanish accented letters to their plain ASCII equivalents so the
// terminal renders clean syllables (e.g. "ú" -> "u") on shells or fonts that mishandle
// combining marks.
var accentReplacer = strings.NewReplacer(
	"á", "a", "é", "e", "í", "i", "ó", "o", "ú", "u", "ü", "u", "ñ", "n",
	"Á", "A", "É", "E", "Í", "I", "Ó", "O", "Ú", "U", "Ü", "U", "Ñ", "N",
)

// stripAccents removes Spanish diacritics from s, leaving the base letters intact.
func stripAccents(s string) string {
	return accentReplacer.Replace(s)
}

// cmdRefresh is the background worker the shell launches when a human presses Enter on a
// real command: it records the previously displayed ad's impression, serves + caches the
// next ad, and flushes the impression buffer. The shell runs this detached, so the prompt
// path never waits on the network.
func cmdRefresh(dir string) error {
	cfg, err := core.LoadConfig(dir)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	return core.Refresh(ctx, dir, core.NewClient(cfg), meta(sessionArg()), time.Now().Unix(), true)
}

// cmdEnd records the currently displayed ad's impression and flushes. The shell can wire it
// to its exit hook; otherwise the next command's refresh records the prior impression.
func cmdEnd(dir string) error {
	cfg, err := core.LoadConfig(dir)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	return core.EndSession(ctx, dir, core.NewClient(cfg), meta(sessionArg()), time.Now().Unix())
}

// cmdLogin stores the device token (from arg or stdin) in the shared local config.
func cmdLogin(dir string) error {
	token := ""
	if len(os.Args) > 2 {
		token = strings.TrimSpace(os.Args[2])
	}
	if token == "" {
		b, _ := io.ReadAll(os.Stdin)
		token = strings.TrimSpace(string(b))
	}
	if token == "" {
		return fmt.Errorf("login: no device token provided")
	}
	cfg, err := core.LoadConfig(dir)
	if err != nil {
		return err
	}
	cfg.DeviceToken = token
	if err := core.SaveConfig(dir, cfg); err != nil {
		return err
	}
	fmt.Println("vibeperks: device token saved.")
	fmt.Println("vibeperks: restart your terminal (or open a new one) for the change to take effect.")
	return nil
}

// cmdOptOut toggles the opt-out flag; when opted out the plugin fetches and reports nothing.
func cmdOptOut(dir string, out bool) error {
	cfg, err := core.LoadConfig(dir)
	if err != nil {
		return err
	}
	cfg.OptOut = out
	if err := core.SaveConfig(dir, cfg); err != nil {
		return err
	}
	if out {
		fmt.Println("vibeperks: opted out. No ads will be fetched or reported.")
	} else {
		fmt.Println("vibeperks: opted back in.")
	}
	return nil
}

// sessionArg returns the optional session id passed as the second CLI argument (the shell
// passes its PID so impressions group per shell session).
func sessionArg() string {
	if len(os.Args) > 2 {
		return os.Args[2]
	}
	return ""
}
