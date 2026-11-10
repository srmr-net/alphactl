package hardware

import (
	"os"
	"path/filepath"
	"sync"
	"testing"
)

func fixture(t *testing.T) *Device {
	t.Helper()
	d := &Device{Root: t.TempDir()}
	files := map[string]string{
		"rgb_zones/zone00":                 "red: 0, green: 0, blue: 0\n",
		"rgb_zones/zone01":                 "red: 0, green: 0, blue: 0\n",
		"rgb_zones/lighting_control_state": "booting [running] suspend\n",
		"hdmi/source":                      "input [gpu] unknown\n",
		"hdmi/cable":                       "[unconnected] connected unknown\n",
		brightnessPath + "brightness":      "15\n",
		brightnessPath + "max_brightness":  "15\n",
	}
	for name, data := range files {
		p := filepath.Join(d.Root, name)
		if err := os.MkdirAll(filepath.Dir(p), 0755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(data), 0600); err != nil {
			t.Fatal(err)
		}
	}
	return d
}

func TestEncodeColor(t *testing.T) {
	for input, want := range map[string]string{"#FF8000": "0f0800", "ffffff": "0f0f0f", "123456": "010305", "000000": "000000"} {
		got, err := EncodeColor(input)
		if err != nil || got != want {
			t.Errorf("%s: got %s, %v; want %s", input, got, err, want)
		}
	}
	for _, bad := range []string{"", "fff", "#ffffffff", "../../hdmi/source", "FF0000\n", "GG0000"} {
		if _, err := EncodeColor(bad); err == nil {
			t.Errorf("accepted %q", bad)
		}
	}
}

func TestStatusAndWrites(t *testing.T) {
	d := fixture(t)
	s, err := d.Status()
	if err != nil || s.Source != "gpu" || s.Cable != "unconnected" || s.Brightness != 15 {
		t.Fatalf("%+v, %v", s, err)
	}
	if err := d.LED("all", "FF8000"); err != nil {
		t.Fatal(err)
	}
	for _, z := range []string{"zone00", "zone01"} {
		got, _ := d.read("rgb_zones/" + z)
		if got != "0f0800" {
			t.Errorf("%s = %s", z, got)
		}
	}
	if err := d.Brightness(0); err != nil {
		t.Fatal(err)
	}
	if got, _ := d.number(brightnessPath + "brightness"); got != 0 {
		t.Fatal(got)
	}
	if err := d.HDMI("toggle"); err != nil {
		t.Fatal(err)
	}
	if got, _ := d.read("hdmi/source"); got != "input" {
		t.Fatal(got)
	}
}

func TestRejectUnsafeCommandsWithoutWrites(t *testing.T) {
	d := fixture(t)
	for _, err := range []error{d.LED("../../hdmi/source", "ff0000"), d.LED("all", "oops"), d.Brightness(-1), d.Brightness(16), d.HDMI("anything")} {
		if err == nil {
			t.Error("accepted invalid command")
		}
	}
	s, err := d.Status()
	if err != nil || s.Brightness != 15 || s.Source != "gpu" || s.Zones["zone00"] != "red: 0, green: 0, blue: 0" {
		t.Fatalf("modified hardware: %+v %v", s, err)
	}
}

func TestUnknownSourceAndMissingAttribute(t *testing.T) {
	d := fixture(t)
	if err := d.write("hdmi/source", "input gpu [unknown]"); err != nil {
		t.Fatal(err)
	}
	if err := d.HDMI("toggle"); err == nil {
		t.Fatal("toggled unknown source")
	}
	if err := os.Remove(filepath.Join(d.Root, "rgb_zones/zone01")); err != nil {
		t.Fatal(err)
	}
	if err := d.LED("zone01", "ffffff"); err == nil {
		t.Fatal("created missing attribute")
	}
	if _, err := d.Status(); err == nil {
		t.Fatal("missing attribute silently ignored")
	}
}

func TestConcurrentOperations(t *testing.T) {
	d := fixture(t)
	var wg sync.WaitGroup
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			if i%2 == 0 {
				if err := d.Brightness(i % 16); err != nil {
					t.Error(err)
				}
			} else {
				if _, err := d.Status(); err != nil {
					t.Error(err)
				}
			}
		}(i)
	}
	wg.Wait()
}
