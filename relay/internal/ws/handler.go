package ws

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"github.com/yourusername/prompt-gladiators/relay/internal/lobby"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = (pongWait * 9) / 10
	maxMessageSize = 512 * 1024 // 512 KB
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  4096,
	WriteBufferSize: 4096,
	CheckOrigin: func(r *http.Request) bool {
		// Allow all origins for self-hosted relay.
		// Restrict this if you want to lock down to specific clients.
		return true
	},
}

// Handler returns an HTTP handler for the WebSocket endpoint.
func Handler(hub *lobby.Hub, authToken string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Optional bearer token auth
		if authToken != "" {
			token := r.Header.Get("Authorization")
			if token == "" {
				token = r.URL.Query().Get("token")
			} else if len(token) > 7 && token[:7] == "Bearer " {
				token = token[7:]
			}
			if token != authToken {
				http.Error(w, "Unauthorized", http.StatusUnauthorized)
				return
			}
		}

		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			log.Printf("WebSocket upgrade error: %v", err)
			return
		}

		clientID := uuid.NewString()
		client := lobby.NewClient(hub, clientID)
		hub.Register(client)

		log.Printf("WebSocket connected: %s from %s", clientID, r.RemoteAddr)

		// Start read and write pumps
		go client.WritePump(func(env *lobby.Envelope) error {
			conn.SetWriteDeadline(time.Now().Add(writeWait))
			data, err := json.Marshal(env)
			if err != nil {
				return err
			}
			return conn.WriteMessage(websocket.TextMessage, data)
		})

		// Send client their own ID on connect
		welcomeData, _ := json.Marshal(map[string]string{
			"type":     "welcome",
			"clientId": clientID,
		})
		conn.WriteMessage(websocket.TextMessage, welcomeData)

		// Set up ping/pong for keepalive
		conn.SetReadLimit(maxMessageSize)
		conn.SetReadDeadline(time.Now().Add(pongWait))
		conn.SetPongHandler(func(string) error {
			conn.SetReadDeadline(time.Now().Add(pongWait))
			return nil
		})

		// Ping ticker
		go func() {
			ticker := time.NewTicker(pingPeriod)
			defer ticker.Stop()
			for range ticker.C {
				conn.SetWriteDeadline(time.Now().Add(writeWait))
				if err := conn.WriteMessage(websocket.PingMessage, nil); err != nil {
					return
				}
			}
		}()

		client.ReadPump(func() ([]byte, error) {
			_, data, err := conn.ReadMessage()
			return data, err
		})

		conn.Close()
	}
}
