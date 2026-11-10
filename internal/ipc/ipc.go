// Package ipc provides versioned JSON HTTP over a local Unix socket only.
package ipc

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"time"

	"alphactl/internal/hardware"
)

const DefaultSocket = "/run/alphactl/control.sock"

type Command struct {
	Zone   string `json:"zone,omitempty"`
	Color  string `json:"color,omitempty"`
	Value  *int   `json:"value,omitempty"`
	Source string `json:"source,omitempty"`
}

func Handler(d *hardware.Device) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /v1/status", func(w http.ResponseWriter, r *http.Request) {
		s, err := d.Status()
		if err != nil {
			http.Error(w, err.Error(), http.StatusServiceUnavailable)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(s)
	})
	for _, action := range []string{"led", "brightness", "hdmi"} {
		mux.HandleFunc("POST /v1/"+action, func(w http.ResponseWriter, r *http.Request) {
			r.Body = http.MaxBytesReader(w, r.Body, 1024)
			dec := json.NewDecoder(r.Body)
			dec.DisallowUnknownFields()
			var c Command
			if err := dec.Decode(&c); err != nil {
				http.Error(w, "invalid command: "+err.Error(), 400)
				return
			}
			if err := dec.Decode(new(any)); err != io.EOF {
				http.Error(w, "expected one JSON command", 400)
				return
			}
			var err error
			switch action {
			case "led":
				err = d.LED(c.Zone, c.Color)
			case "brightness":
				if c.Value == nil {
					http.Error(w, "value is required", 400)
					return
				}
				err = d.Brightness(*c.Value)
			case "hdmi":
				err = d.HDMI(c.Source)
			}
			if err != nil {
				http.Error(w, err.Error(), 400)
				return
			}
			w.Header().Set("Content-Type", "application/json")
			io.WriteString(w, "{\"ok\":true}\n")
		})
	}
	return mux
}

func Client(socket string) *http.Client {
	return &http.Client{
		Timeout: 5 * time.Second,
		Transport: &http.Transport{
			DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
				return (&net.Dialer{}).DialContext(ctx, "unix", socket)
			},
		},
		CheckRedirect: func(_ *http.Request, _ []*http.Request) error { return fmt.Errorf("unexpected redirect") },
	}
}
