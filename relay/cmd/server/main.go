package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/yourusername/prompt-gladiators/relay/internal/lobby"
	"github.com/yourusername/prompt-gladiators/relay/internal/ws"
	"github.com/yourusername/prompt-gladiators/relay/pkg/metrics"
)

func main() {
	port := flag.Int("port", getEnvInt("PORT", 8080), "Port to listen on")
	authToken := flag.String("token", os.Getenv("AUTH_TOKEN"), "Bearer token for auth (empty = no auth)")
	flag.Parse()

	// Hub — manages all lobbies and client connections
	hub := lobby.NewHub()
	go hub.Run()

	// HTTP mux
	mux := http.NewServeMux()

	// WebSocket — main client endpoint
	mux.HandleFunc("/ws", ws.Handler(hub, *authToken))

	// Health — simple liveness check
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprintf(w, `{"status":"ok","lobbies":%d,"clients":%d}`,
			hub.LobbyCount(), hub.ClientCount())
	})

	// Metrics — extended stats
	mux.HandleFunc("/metrics", func(w http.ResponseWriter, r *http.Request) {
		metrics.SetLobbies(hub.LobbyCount())
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, metrics.Summary())
	})

	// Public lobbies — list of open matches
	mux.HandleFunc("/lobbies", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Access-Control-Allow-Origin", "*")
		fmt.Fprint(w, hub.PublicLobbiesJSON())
	})

	// HTTP server with timeouts
	srv := &http.Server{
		Addr:         fmt.Sprintf(":%d", *port),
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	// Graceful shutdown on SIGINT / SIGTERM
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-quit
		log.Println("Shutting down relay server...")
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := srv.Shutdown(ctx); err != nil {
			log.Printf("Shutdown error: %v", err)
		}
	}()

	authStatus := "no auth"
	if *authToken != "" {
		authStatus = "auth enabled"
	}

	log.Printf("Prompt Gladiators relay server")
	log.Printf("  Listening on :%d (%s)", *port, authStatus)
	log.Printf("  ws://localhost:%d/ws", *port)
	log.Printf("  http://localhost:%d/health", *port)

	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Server failed: %v", err)
	}

	log.Println("Relay server stopped.")
}

func getEnvInt(key string, fallback int) int {
	if val := os.Getenv(key); val != "" {
		if n, err := strconv.Atoi(val); err == nil {
			return n
		}
	}
	return fallback
}
