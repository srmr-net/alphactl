// Package hardware implements the Alienware Alpha R1 alienware-wmi sysfs ABI.
package hardware

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
)

const DefaultRoot = "/sys/devices/platform/alienware-wmi"

var colorPattern = regexp.MustCompile(`^#?[0-9a-fA-F]{6}$`)

type Status struct {
	Zones         map[string]string `json:"zones"`
	Brightness    int               `json:"brightness"`
	MaxBrightness int               `json:"max_brightness"`
	Source        string            `json:"source"`
	Cable         string            `json:"cable"`
}

type Device struct {
	Root string
	mu   sync.Mutex
}

func (d *Device) read(name string) (string, error) {
	b, err := os.ReadFile(filepath.Join(d.Root, name))
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(b)), nil
}

// Never create files: a missing sysfs attribute must be an error.
func (d *Device) write(name, value string) error {
	f, err := os.OpenFile(filepath.Join(d.Root, name), os.O_WRONLY|os.O_TRUNC, 0)
	if err != nil {
		return err
	}
	_, err = f.WriteString(value + "\n")
	closeErr := f.Close()
	if err != nil {
		return err
	}
	return closeErr
}

func selected(text string) (string, error) {
	for _, word := range strings.Fields(text) {
		if strings.HasPrefix(word, "[") && strings.HasSuffix(word, "]") {
			return strings.Trim(word, "[]"), nil
		}
	}
	return "", fmt.Errorf("no selected value in %q", text)
}

func (d *Device) selection(name string) (string, error) {
	s, err := d.read(name)
	if err != nil {
		return "", err
	}
	return selected(s)
}

const brightnessPath = "leds/alienware::global_brightness/"

func (d *Device) number(name string) (int, error) {
	s, err := d.read(name)
	if err != nil {
		return 0, err
	}
	n, err := strconv.Atoi(s)
	if err != nil {
		return 0, fmt.Errorf("invalid integer in %s: %w", name, err)
	}
	return n, nil
}

func (d *Device) Status() (Status, error) {
	d.mu.Lock()
	defer d.mu.Unlock()
	s := Status{Zones: make(map[string]string)}
	for _, zone := range []string{"zone00", "zone01"} {
		raw, err := d.read("rgb_zones/" + zone)
		if err != nil {
			return s, err
		}
		s.Zones[zone] = raw // Kernel caches these values; they are not optical readback.
	}
	var err error
	if s.Brightness, err = d.number(brightnessPath + "brightness"); err != nil {
		return s, err
	}
	if s.MaxBrightness, err = d.number(brightnessPath + "max_brightness"); err != nil {
		return s, err
	}
	if s.Source, err = d.selection("hdmi/source"); err != nil {
		return s, err
	}
	if s.Cable, err = d.selection("hdmi/cable"); err != nil {
		return s, err
	}
	return s, nil
}

// EncodeColor maps eight-bit channels to the driver's four-bit channels.
func EncodeColor(color string) (string, error) {
	if !colorPattern.MatchString(color) {
		return "", fmt.Errorf("colour must be RRGGBB or #RRGGBB")
	}
	n, _ := strconv.ParseUint(strings.TrimPrefix(color, "#"), 16, 24)
	return fmt.Sprintf("%06x", (n>>4)&0x0f0f0f), nil
}

func (d *Device) LED(zone, color string) error {
	d.mu.Lock()
	defer d.mu.Unlock()
	if zone != "all" && zone != "zone00" && zone != "zone01" {
		return fmt.Errorf("zone must be all, zone00, or zone01")
	}
	value, err := EncodeColor(color)
	if err != nil {
		return err
	}
	if err := d.write("rgb_zones/lighting_control_state", "running"); err != nil {
		return err
	}
	zones := []string{zone}
	if zone == "all" {
		zones = []string{"zone00", "zone01"}
	}
	for _, z := range zones {
		if err := d.write("rgb_zones/"+z, value); err != nil {
			return fmt.Errorf("write %s (earlier writes may have succeeded): %w", z, err)
		}
	}
	return nil
}

func (d *Device) Brightness(value int) error {
	d.mu.Lock()
	defer d.mu.Unlock()
	max, err := d.number(brightnessPath + "max_brightness")
	if err != nil {
		return err
	}
	if value < 0 || value > max {
		return fmt.Errorf("brightness must be between 0 and %d", max)
	}
	return d.write(brightnessPath+"brightness", strconv.Itoa(value))
}

func (d *Device) HDMI(source string) error {
	d.mu.Lock()
	defer d.mu.Unlock()
	if source == "toggle" {
		current, err := d.selection("hdmi/source")
		if err != nil {
			return err
		}
		switch current {
		case "gpu":
			source = "input"
		case "input":
			source = "gpu"
		default:
			return fmt.Errorf("cannot toggle unknown HDMI source %q", current)
		}
	}
	if source != "gpu" && source != "input" {
		return fmt.Errorf("HDMI source must be gpu, input, or toggle")
	}
	return d.write("hdmi/source", source)
}
