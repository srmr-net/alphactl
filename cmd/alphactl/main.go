package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"

	"alphactl/internal/hardware"
	"alphactl/internal/ipc"
)

func run() error {
	socket := flag.String("socket", ipc.DefaultSocket, "daemon Unix socket")
	asJSON := flag.Bool("json", false, "output JSON")
	flag.Usage = func() {
		fmt.Fprintln(flag.CommandLine.Output(), "Usage: alphactl [--socket PATH] [--json] status | led <all|zone00|zone01> <RRGGBB> | brightness <0-15> | hdmi <gpu|input|toggle>")
		flag.PrintDefaults()
	}
	flag.Parse()
	a := flag.Args()
	if len(a) == 0 {
		flag.Usage()
		return fmt.Errorf("command required")
	}
	method, path := http.MethodPost, ""
	var c ipc.Command
	switch {
	case a[0] == "status" && len(a) == 1:
		method, path = http.MethodGet, "status"
	case a[0] == "led" && len(a) == 3:
		if a[1] != "all" && a[1] != "zone00" && a[1] != "zone01" {
			return fmt.Errorf("invalid zone")
		}
		if _, err := hardware.EncodeColor(a[2]); err != nil {
			return err
		}
		path, c.Zone, c.Color = "led", a[1], a[2]
	case a[0] == "brightness" && len(a) == 2:
		n, err := strconv.Atoi(a[1])
		if err != nil || n < 0 || n > 15 {
			return fmt.Errorf("brightness must be 0-15")
		}
		path, c.Value = "brightness", &n
	case a[0] == "hdmi" && len(a) == 2:
		if a[1] != "gpu" && a[1] != "input" && a[1] != "toggle" {
			return fmt.Errorf("HDMI source must be gpu, input, or toggle")
		}
		path, c.Source = "hdmi", a[1]
	default:
		flag.Usage()
		return fmt.Errorf("invalid command or arguments")
	}
	b, err := json.Marshal(c)
	if err != nil {
		return err
	}
	req, err := http.NewRequest(method, "http://localhost/v1/"+path, bytes.NewReader(b))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	client := ipc.Client(*socket)
	defer client.CloseIdleConnections()
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("connect to alphactld at %s (check alphactld.socket and group membership): %w", *socket, err)
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(io.LimitReader(resp.Body, 65536))
	if err != nil {
		return err
	}
	if resp.StatusCode != 200 {
		return fmt.Errorf("daemon: %s", bytes.TrimSpace(data))
	}
	if *asJSON {
		_, err = os.Stdout.Write(data)
		return err
	}
	if path == "status" {
		var s hardware.Status
		if err := json.Unmarshal(data, &s); err != nil {
			return err
		}
		fmt.Printf("HDMI: %s (cable: %s)\nBrightness: %d/%d\nzone00: %s\nzone01: %s\n", s.Source, s.Cable, s.Brightness, s.MaxBrightness, s.Zones["zone00"], s.Zones["zone01"])
	} else {
		fmt.Println("OK")
	}
	return nil
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "alphactl:", err)
		os.Exit(1)
	}
}
