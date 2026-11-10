package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"alphactl/internal/hardware"
	"alphactl/internal/ipc"
)

func listener(path string) (net.Listener, error) {
	if os.Getenv("LISTEN_PID") == strconv.Itoa(os.Getpid()) {
		if os.Getenv("LISTEN_FDS") != "1" {
			return nil, fmt.Errorf("expected exactly one systemd socket")
		}
		f := os.NewFile(3, "systemd-socket")
		l, err := net.FileListener(f)
		f.Close()
		if err != nil {
			return nil, err
		}
		if l.Addr().Network() != "unix" {
			l.Close()
			return nil, fmt.Errorf("expected Unix stream socket")
		}
		return l, nil
	}
	// Never unlink an existing socket; it may belong to a running daemon.
	l, err := net.Listen("unix", path)
	if err != nil {
		return nil, err
	}
	if err := os.Chmod(path, 0600); err != nil {
		l.Close()
		return nil, err
	}
	return l, nil
}

func run() error {
	socket := flag.String("socket", ipc.DefaultSocket, "standalone Unix socket (0600); systemd socket takes precedence")
	root := flag.String("sysfs-root", hardware.DefaultRoot, "alienware-wmi device directory")
	check := flag.Bool("check", false, "print hardware status as JSON without starting a socket or changing hardware")
	flag.Parse()
	if flag.NArg() != 0 {
		return fmt.Errorf("unexpected positional arguments")
	}
	d := &hardware.Device{Root: *root}
	status, err := d.Status()
	if err != nil {
		return fmt.Errorf("Alpha hardware unavailable: %w", err)
	}
	if *check {
		return json.NewEncoder(os.Stdout).Encode(status)
	}
	l, err := listener(*socket)
	if err != nil {
		return err
	}
	defer l.Close()
	srv := &http.Server{Handler: ipc.Handler(d), ReadTimeout: 5 * time.Second, WriteTimeout: 5 * time.Second, IdleTimeout: 10 * time.Second, MaxHeaderBytes: 4096}
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
	defer stop()
	go func() {
		<-ctx.Done()
		shutdown, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		srv.Shutdown(shutdown)
	}()
	log.Printf("serving %s using %s", l.Addr(), *root)
	err = srv.Serve(l)
	if errors.Is(err, http.ErrServerClosed) {
		return nil
	}
	return err
}

func main() {
	if err := run(); err != nil {
		log.Print(err)
		os.Exit(1)
	}
}
