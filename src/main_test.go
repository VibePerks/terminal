package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"sync"
	"testing"

	"vibeperks/core"
)

// mockBackend is an in-memory VibePerks backend for the adapter flow tests. It serves one
// ad and records every impression it receives.
type mockBackend struct {
	mu          sync.Mutex
	server      *httptest.Server
	ad          *core.Ad
	impressions []core.Impression
}

func newMockBackend(ad *core.Ad) *mockBackend {
	m := &mockBackend{ad: ad}
	mux := http.NewServeMux()
	mux.HandleFunc("/v1/ads/serve", func(w http.ResponseWriter, r *http.Request) {
		m.mu.Lock()
		defer m.mu.Unlock()
		if m.ad == nil {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_ = json.NewEncoder(w).Encode(m.ad)
	})
	mux.HandleFunc("/v1/impressions", func(w http.ResponseWriter, r *http.Request) {
		var imp core.Impression
		_ = json.NewDecoder(r.Body).Decode(&imp)
		m.mu.Lock()
		m.impressions = append(m.impressions, imp)
		m.mu.Unlock()
		w.WriteHeader(http.StatusCreated)
	})
	m.server = httptest.NewServer(mux)
	return m
}

func (m *mockBackend) close() { m.server.Close() }

func (m *mockBackend) recorded() []core.Impression {
	m.mu.Lock()
	defer m.mu.Unlock()
	return append([]core.Impression(nil), m.impressions...)
}

// configure points a fresh temp $VIBEPERKS_HOME with a device token at the mock backend.
func configure(t *testing.T, base string) string {
	t.Helper()
	dir := t.TempDir()
	t.Setenv("VIBEPERKS_HOME", dir)
	t.Setenv("VIBEPERKS_API", base)
	if err := core.SaveConfig(dir, core.Config{APIBase: base, DeviceToken: "dev-token"}); err != nil {
		t.Fatal(err)
	}
	return dir
}

func setArgs(t *testing.T, args ...string) {
	t.Helper()
	old := os.Args
	os.Args = append([]string{"vibeperks-terminal"}, args...)
	t.Cleanup(func() { os.Args = old })
}

func TestMeta(t *testing.T) {
	t.Setenv("VIBEPERKS_TERMINAL_VERSION", "9.9.9")
	m := meta("sess-7")
	if m.CLI != "terminal" || m.SessionID != "sess-7" || m.PluginVersion != version || m.CLIVersion != "9.9.9" {
		t.Errorf("meta = %+v", m)
	}
}

func TestDispatchUnknownReturnsNil(t *testing.T) {
	if err := dispatch("totally-unknown"); err != nil {
		t.Errorf("unknown command should be a no-op, got %v", err)
	}
}

func TestDispatchLoginStoresToken(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("VIBEPERKS_HOME", dir)
	setArgs(t, "login", "my-device-token")
	if err := dispatch("login"); err != nil {
		t.Fatal(err)
	}
	cfg, err := core.LoadConfig(dir)
	if err != nil {
		t.Fatal(err)
	}
	if cfg.DeviceToken != "my-device-token" {
		t.Errorf("token = %q", cfg.DeviceToken)
	}
}

func TestDispatchLoginNoTokenErrors(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("VIBEPERKS_HOME", dir)
	setArgs(t, "login")
	if err := cmdLogin(dir); err == nil {
		t.Error("login with no token should error")
	}
}

func TestDispatchOptOutAndIn(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("VIBEPERKS_HOME", dir)
	if err := dispatch("optout"); err != nil {
		t.Fatal(err)
	}
	if cfg, _ := core.LoadConfig(dir); !cfg.OptOut {
		t.Error("optout should set OptOut")
	}
	if err := dispatch("optin"); err != nil {
		t.Fatal(err)
	}
	if cfg, _ := core.LoadConfig(dir); cfg.OptOut {
		t.Error("optin should clear OptOut")
	}
}

func TestRenderNoAdPrintsNothing(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("VIBEPERKS_HOME", dir)
	if err := cmdRender(dir); err != nil {
		t.Fatalf("render with no cached ad should be a no-op, got %v", err)
	}
}

// The full Enter-driven flow: a refresh serves + caches an ad, render displays it, and end
// reports the impression with cli="terminal".
func TestEnterFlowRecordsTerminalImpression(t *testing.T) {
	mb := newMockBackend(&core.Ad{
		AdID:            "ad-1",
		Sentence:        "Get paid while vibe coding - VibePerks.ai",
		Domain:          "VibePerks.ai",
		ImpressionToken: "tok-1",
		RotateSeconds:   20,
	})
	defer mb.close()
	dir := configure(t, mb.server.URL)
	setArgs(t, "refresh", "sess-1")

	if err := cmdRefresh(dir); err != nil {
		t.Fatalf("refresh: %v", err)
	}
	if err := cmdRender(dir); err != nil {
		t.Fatalf("render: %v", err)
	}
	if err := cmdEnd(dir); err != nil {
		t.Fatalf("end: %v", err)
	}

	imps := mb.recorded()
	if len(imps) != 1 {
		t.Fatalf("want exactly 1 impression, got %d", len(imps))
	}
	got := imps[0]
	if got.ImpressionToken != "tok-1" {
		t.Errorf("impression token = %q", got.ImpressionToken)
	}
	if got.CLI != "terminal" {
		t.Errorf("cli = %q, want terminal", got.CLI)
	}
	if got.SessionID != "sess-1" {
		t.Errorf("session id = %q", got.SessionID)
	}
}

// Opting out must short-circuit: no ad is served and nothing is reported.
func TestRefreshOptedOutDoesNotServe(t *testing.T) {
	mb := newMockBackend(&core.Ad{AdID: "ad-1", ImpressionToken: "tok-1"})
	defer mb.close()
	dir := configure(t, mb.server.URL)
	if err := core.SaveConfig(dir, core.Config{APIBase: mb.server.URL, DeviceToken: "dev-token", OptOut: true}); err != nil {
		t.Fatal(err)
	}
	setArgs(t, "refresh")
	if err := cmdRefresh(dir); err != nil {
		t.Fatalf("refresh: %v", err)
	}
	if err := cmdRender(dir); err != nil {
		t.Fatalf("render: %v", err)
	}
	if len(mb.recorded()) != 0 {
		t.Errorf("opted out must report nothing, got %d", len(mb.recorded()))
	}
}

// A failing background command must never escape the Guard boundary into the user's shell.
func TestRefreshFailureContainedByGuard(t *testing.T) {
	t.Setenv("VIBEPERKS_HOME", t.TempDir())
	t.Setenv("VIBEPERKS_API", "http://127.0.0.1:1") // connection refused
	setArgs(t, "refresh")
	core.Guard(func() error { return dispatch("refresh") })
}
