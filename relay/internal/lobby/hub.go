package lobby

import (
	"encoding/json"
	"log"
	"sync"
	"time"

	"github.com/google/uuid"
)

// Hub manages all active lobbies and routes messages between clients.
type Hub struct {
	mu      sync.RWMutex
	lobbies map[string]*Lobby
	clients map[string]*Client // clientId -> Client

	register   chan *Client
	unregister chan *Client
	broadcast  chan *Envelope
}

func NewHub() *Hub {
	return &Hub{
		lobbies:    make(map[string]*Lobby),
		clients:    make(map[string]*Client),
		register:   make(chan *Client, 64),
		unregister: make(chan *Client, 64),
		broadcast:  make(chan *Envelope, 512),
	}
}

// Run is the central event loop. Call in a goroutine.
func (h *Hub) Run() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client.ID] = client
			h.mu.Unlock()
			log.Printf("Client connected: %s", client.ID)

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client.ID]; ok {
				delete(h.clients, client.ID)
				close(client.Send)
			}
			h.mu.Unlock()
			h.removeClientFromLobby(client)
			log.Printf("Client disconnected: %s", client.ID)

		case env := <-h.broadcast:
			h.route(env)

		case <-ticker.C:
			h.cleanEmptyLobbies()
		}
	}
}

// Dispatch is called by client goroutines to send an envelope for routing.
func (h *Hub) Dispatch(env *Envelope) {
	h.broadcast <- env
}

func (h *Hub) Register(c *Client) { h.register <- c }
func (h *Hub) Unregister(c *Client) { h.unregister <- c }

func (h *Hub) LobbyCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.lobbies)
}

func (h *Hub) ClientCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}

func (h *Hub) PublicLobbiesJSON() string {
	h.mu.RLock()
	defer h.mu.RUnlock()

	type publicLobby struct {
		ID         string    `json:"id"`
		MemberCount int      `json:"memberCount"`
		Status     string    `json:"status"`
		CreatedAt  time.Time `json:"createdAt"`
	}

	var list []publicLobby
	for _, l := range h.lobbies {
		l.mu.RLock()
		if l.Visibility == "public" {
			list = append(list, publicLobby{
				ID:          l.ID,
				MemberCount: len(l.Members),
				Status:      string(l.Status),
				CreatedAt:   l.CreatedAt,
			})
		}
		l.mu.RUnlock()
	}

	b, _ := json.Marshal(list)
	return string(b)
}

// ─── Routing ──────────────────────────────────────────────────────────────────

func (h *Hub) route(env *Envelope) {
	switch env.Type {
	case MsgCreateLobby:
		h.handleCreateLobby(env)
	case MsgJoinLobby:
		h.handleJoinLobby(env)
	case MsgLeaveLobby:
		h.handleLeaveLobby(env)
	case MsgAssignRole:
		h.handleAssignRole(env)
	case MsgKickMember:
		h.handleKickMember(env)
	case MsgMuteMember:
		h.handleMuteMember(env)
	case MsgUpdateSettings:
		h.handleUpdateSettings(env)
	case MsgStartBattle:
		h.broadcastToLobby(env.LobbyID, env)
	case MsgPauseBattle:
		h.broadcastToLobby(env.LobbyID, env)
	case MsgResumeBattle:
		h.broadcastToLobby(env.LobbyID, env)
	case MsgBattleStateSync:
		h.broadcastToLobby(env.LobbyID, env)
	case MsgUpdateSystemPrompt:
		h.broadcastToLobby(env.LobbyID, env)
	case MsgInjectPrompt:
		h.broadcastToLobby(env.LobbyID, env)
	case MsgCastVote:
		h.broadcastToLobby(env.LobbyID, env)
	case MsgPowerUp:
		h.broadcastToLobby(env.LobbyID, env)
	case MsgCrowdChant:
		h.broadcastToLobby(env.LobbyID, env)
	case MsgChat:
		h.broadcastToLobby(env.LobbyID, env)
	case MsgPing:
		h.handlePing(env)
	default:
		log.Printf("Unknown message type: %s", env.Type)
	}
}

// ─── Handlers ────────────────────────────────────────────────────────────────

func (h *Hub) handleCreateLobby(env *Envelope) {
	client := h.clientByID(env.SenderID)
	if client == nil {
		return
	}

	var payload CreateLobbyPayload
	if err := json.Unmarshal(env.rawPayload, &payload); err != nil {
		h.sendError(client, "Invalid createLobby payload")
		return
	}

	lobbyID := payload.LobbyID
	if lobbyID == "" {
		lobbyID = uuid.NewString()
	}

	h.mu.Lock()
	if _, exists := h.lobbies[lobbyID]; exists {
		h.mu.Unlock()
		h.sendError(client, "Lobby ID already exists")
		return
	}

	lobby := &Lobby{
		ID:          lobbyID,
		Status:      LobbyStatusWaiting,
		Visibility:  payload.Visibility,
		CreatedAt:   time.Now(),
		Members:     make(map[string]*Member),
		Settings:    payload.Settings,
	}
	h.lobbies[lobbyID] = lobby
	h.mu.Unlock()

	// Add creator as owner
	member := &Member{
		ID:          client.ID,
		DisplayName: payload.DisplayName,
		Role:        RoleOwner,
		IsConnected: true,
		Client:      client,
	}
	lobby.mu.Lock()
	lobby.Members[client.ID] = member
	lobby.OwnerID = client.ID
	lobby.mu.Unlock()

	client.LobbyID = lobbyID

	log.Printf("Lobby created: %s by %s", lobbyID, client.ID)
	h.sendLobbyState(lobbyID)
}

func (h *Hub) handleJoinLobby(env *Envelope) {
	client := h.clientByID(env.SenderID)
	if client == nil {
		return
	}

	var payload JoinLobbyPayload
	if err := json.Unmarshal(env.rawPayload, &payload); err != nil {
		h.sendError(client, "Invalid joinLobby payload")
		return
	}

	h.mu.RLock()
	lobby, exists := h.lobbies[payload.LobbyID]
	h.mu.RUnlock()

	if !exists {
		h.sendError(client, "Lobby not found: "+payload.LobbyID)
		return
	}

	lobby.mu.Lock()
	if _, already := lobby.Members[client.ID]; already {
		lobby.Members[client.ID].IsConnected = true
		lobby.Members[client.ID].Client = client
		lobby.mu.Unlock()
		client.LobbyID = payload.LobbyID
		h.sendLobbyState(payload.LobbyID)
		return
	}

	role := Role(payload.RequestedRole)
	// Only owner can grant commander — default to spectator
	if role == RoleCommander || role == RoleModerator {
		role = RoleSpectator
	}

	member := &Member{
		ID:          client.ID,
		DisplayName: payload.DisplayName,
		Role:        role,
		IsConnected: true,
		Client:      client,
	}
	lobby.Members[client.ID] = member
	lobby.mu.Unlock()

	client.LobbyID = payload.LobbyID
	log.Printf("Client %s joined lobby %s as %s", client.ID, payload.LobbyID, role)
	h.sendLobbyState(payload.LobbyID)
}

func (h *Hub) handleLeaveLobby(env *Envelope) {
	client := h.clientByID(env.SenderID)
	if client == nil || client.LobbyID == "" {
		return
	}
	h.removeClientFromLobby(client)
}

func (h *Hub) handleAssignRole(env *Envelope) {
	client := h.clientByID(env.SenderID)
	if client == nil {
		return
	}

	var payload AssignRolePayload
	if err := json.Unmarshal(env.rawPayload, &payload); err != nil {
		return
	}

	h.mu.RLock()
	lobby, exists := h.lobbies[env.LobbyID]
	h.mu.RUnlock()
	if !exists {
		return
	}

	lobby.mu.Lock()

	// Only owner can assign roles
	requester, ok := lobby.Members[env.SenderID]
	if !ok || requester.Role != RoleOwner {
		lobby.mu.Unlock()
		h.sendError(client, "Only owner can assign roles")
		return
	}

	target, ok := lobby.Members[payload.TargetMemberID]
	if !ok {
		lobby.mu.Unlock()
		return
	}
	target.Role = Role(payload.Role)
	log.Printf("Role assigned: %s -> %s in lobby %s", payload.TargetMemberID, payload.Role, env.LobbyID)
	lobby.mu.Unlock() // release before broadcasting

	h.sendLobbyState(env.LobbyID)
}

func (h *Hub) handleKickMember(env *Envelope) {
	h.mu.RLock()
	lobby, exists := h.lobbies[env.LobbyID]
	h.mu.RUnlock()
	if !exists {
		return
	}

	var payload map[string]string
	if err := json.Unmarshal(env.rawPayload, &payload); err != nil {
		return
	}
	targetID := payload["targetMemberId"]

	lobby.mu.Lock()
	requester, ok := lobby.Members[env.SenderID]
	if !ok || (requester.Role != RoleOwner && requester.Role != RoleModerator) {
		lobby.mu.Unlock()
		return
	}
	target, ok := lobby.Members[targetID]
	if ok && target.Client != nil {
		kicked := newEnvelope(env.LobbyID, "server", MsgError, map[string]string{"message": "You have been kicked"})
		target.Client.send(kicked)
	}
	delete(lobby.Members, targetID)
	lobby.mu.Unlock()

	h.sendLobbyState(env.LobbyID)
}

func (h *Hub) handleMuteMember(env *Envelope) {
	// Mute is advisory — relay records it, client enforces
	h.broadcastToLobby(env.LobbyID, env)
}

func (h *Hub) handleUpdateSettings(env *Envelope) {
	h.mu.RLock()
	lobby, exists := h.lobbies[env.LobbyID]
	h.mu.RUnlock()
	if !exists {
		return
	}

	lobby.mu.Lock()
	requester, ok := lobby.Members[env.SenderID]
	if !ok || requester.Role != RoleOwner {
		lobby.mu.Unlock()
		return
	}

	var payload map[string]json.RawMessage
	if err := json.Unmarshal(env.rawPayload, &payload); err == nil {
		if s, ok := payload["settings"]; ok {
			lobby.Settings = s
		}
	}
	lobby.mu.Unlock()

	h.broadcastToLobby(env.LobbyID, env)
}

func (h *Hub) handlePing(env *Envelope) {
	client := h.clientByID(env.SenderID)
	if client == nil {
		return
	}
	pong := newEnvelope("", "server", MsgPong, nil)
	client.send(pong)
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

func (h *Hub) broadcastToLobby(lobbyID string, env *Envelope) {
	h.mu.RLock()
	lobby, exists := h.lobbies[lobbyID]
	h.mu.RUnlock()
	if !exists {
		return
	}

	lobby.mu.RLock()
	defer lobby.mu.RUnlock()

	for _, member := range lobby.Members {
		if member.Client != nil && member.IsConnected {
			member.Client.send(env)
		}
	}
}

func (h *Hub) sendLobbyState(lobbyID string) {
	h.mu.RLock()
	lobby, exists := h.lobbies[lobbyID]
	h.mu.RUnlock()
	if !exists {
		return
	}

	lobby.mu.RLock()
	defer lobby.mu.RUnlock()
	h.sendLobbyStateUnlocked(lobby)
}

func (h *Hub) sendLobbyStateUnlocked(lobby *Lobby) {
	type memberDTO struct {
		ID          string `json:"id"`
		DisplayName string `json:"displayName"`
		Role        string `json:"role"`
		IsConnected bool   `json:"isConnected"`
	}

	members := make([]memberDTO, 0, len(lobby.Members))
	for _, m := range lobby.Members {
		members = append(members, memberDTO{
			ID:          m.ID,
			DisplayName: m.DisplayName,
			Role:        string(m.Role),
			IsConnected: m.IsConnected,
		})
	}

	state := map[string]any{
		"lobbyId":    lobby.ID,
		"status":     string(lobby.Status),
		"ownerID":    lobby.OwnerID,
		"members":    members,
		"visibility": lobby.Visibility,
	}

	env := newEnvelope(lobby.ID, "server", MsgLobbyState, state)

	for _, m := range lobby.Members {
		if m.Client != nil && m.IsConnected {
			m.Client.send(env)
		}
	}
}

func (h *Hub) sendError(client *Client, msg string) {
	env := newEnvelope("", "server", MsgError, map[string]string{"message": msg})
	client.send(env)
}

func (h *Hub) clientByID(id string) *Client {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return h.clients[id]
}

func (h *Hub) removeClientFromLobby(client *Client) {
	if client.LobbyID == "" {
		return
	}

	h.mu.RLock()
	lobby, exists := h.lobbies[client.LobbyID]
	h.mu.RUnlock()
	if !exists {
		return
	}

	lobby.mu.Lock()
	if member, ok := lobby.Members[client.ID]; ok {
		member.IsConnected = false
		member.Client = nil
	}
	lobby.mu.Unlock()

	client.LobbyID = ""
	h.sendLobbyState(lobby.ID)
}

func (h *Hub) cleanEmptyLobbies() {
	h.mu.Lock()
	defer h.mu.Unlock()

	for id, lobby := range h.lobbies {
		lobby.mu.RLock()
		connected := 0
		for _, m := range lobby.Members {
			if m.IsConnected {
				connected++
			}
		}
		lobby.mu.RUnlock()

		// Remove lobby if empty for more than 5 minutes
		if connected == 0 && time.Since(lobby.CreatedAt) > 5*time.Minute {
			delete(h.lobbies, id)
			log.Printf("Cleaned empty lobby: %s", id)
		}
	}
}

// newEnvelope creates a server-sent envelope.
func newEnvelope(lobbyID, senderID string, msgType MessageType, payload any) *Envelope {
	raw, _ := json.Marshal(payload)
	return &Envelope{
		Type:       msgType,
		LobbyID:    lobbyID,
		SenderID:   senderID,
		Timestamp:  time.Now().Format(time.RFC3339),
		rawPayload: raw,
	}
}
