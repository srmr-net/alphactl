package ipc

import (
	"encoding/json"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"alphactl/internal/hardware"
)

func TestCommandsAndStatus(t *testing.T) {
	root := t.TempDir()
	for name, value := range map[string]string{
		"rgb_zones/zone00":                                 "red: 0, green: 0, blue: 0\n",
		"rgb_zones/zone01":                                 "red: 0, green: 0, blue: 0\n",
		"rgb_zones/lighting_control_state":                 "booting [running] suspend\n",
		"leds/alienware::global_brightness/brightness":     "15\n",
		"leds/alienware::global_brightness/max_brightness": "15\n",
		"hdmi/source":                                      "input [gpu] unknown\n",
		"hdmi/cable":                                       "unconnected [connected] unknown\n",
	} {
		path := filepath.Join(root, name)
		if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(value), 0600); err != nil {
			t.Fatal(err)
		}
	}
	h := Handler(&hardware.Device{Root: root})
	for _, tc := range []struct{ path, body, file, want string }{
		{"led", `{"zone":"all","color":"FF8000"}`, "rgb_zones/zone01", "0f0800\n"},
		{"brightness", `{"value":0}`, "leds/alienware::global_brightness/brightness", "0\n"},
		{"hdmi", `{"source":"toggle"}`, "hdmi/source", "input\n"},
	} {
		rr := httptest.NewRecorder()
		h.ServeHTTP(rr, httptest.NewRequest("POST", "/v1/"+tc.path, strings.NewReader(tc.body)))
		if rr.Code != 200 || strings.TrimSpace(rr.Body.String()) != `{"ok":true}` {
			t.Fatalf("%s: %d %s", tc.path, rr.Code, rr.Body)
		}
		data, err := os.ReadFile(filepath.Join(root, tc.file))
		if err != nil || string(data) != tc.want {
			t.Fatalf("%s: %q %v", tc.file, data, err)
		}
	}
	// A regular file does not emulate the kernel's bracketed readback after a write.
	if err := os.WriteFile(filepath.Join(root, "hdmi/source"), []byte("[input] gpu unknown\n"), 0600); err != nil {
		t.Fatal(err)
	}
	rr := httptest.NewRecorder()
	h.ServeHTTP(rr, httptest.NewRequest("GET", "/v1/status", nil))
	var status hardware.Status
	if err := json.Unmarshal(rr.Body.Bytes(), &status); err != nil {
		t.Fatal(err)
	}
	if rr.Code != 200 || status.Source != "input" || status.Brightness != 0 {
		t.Fatalf("%d %+v", rr.Code, status)
	}
}

func TestRejectInvalidRequestsBeforeHardwareAccess(t *testing.T) {
	h := Handler(&hardware.Device{Root: t.TempDir()})
	for _, tc := range []struct {
		method, path, body string
		code               int
	}{
		{"POST", "/v1/brightness", `{}`, 400},
		{"POST", "/v1/hdmi", `{"source":"gpu","path":"/etc/passwd"}`, 400},
		{"POST", "/v1/hdmi", `{"source":"gpu"} {}`, 400},
		{"POST", "/v1/led", `{"zone":"all","color":"` + strings.Repeat("a", 2000) + `"}`, 400},
		{"POST", "/v1/hdmi", `null`, 400},
		{"POST", "/v1/led", `{"zone":"../../etc/passwd","color":"ffffff"}`, 400},
		{"GET", "/v1/status", ``, 503},
		{"GET", "/v1/led", ``, 405},
		{"POST", "/v2/hdmi", `{}`, 404},
	} {
		rr := httptest.NewRecorder()
		h.ServeHTTP(rr, httptest.NewRequest(tc.method, tc.path, strings.NewReader(tc.body)))
		if rr.Code != tc.code {
			t.Errorf("%s %s: %d %s", tc.method, tc.path, rr.Code, rr.Body)
		}
	}
}
