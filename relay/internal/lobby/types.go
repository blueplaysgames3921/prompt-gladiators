package lobby

import (
	"encoding/json"
	"sync"
	"time"
)

// ─── Message Types ────────────────────────────────────────────────────────────

type MessageType string

const (
	// Lobby lifecycle
	MsgCreateLobby    MessageType = "createLobby"
	MsgJoinLobby      MessageType = "joinLobby"
	MsgLeaveLobby     MessageType = "leaveLobby"
	MsgLobbyState     MessageType = "lobbyState"
	MsgLobbyError     MessageType = "lobbyError"
	MsgAssignRole     MessageType = "assignRole"
	MsgKickMember     MessageType = "kickMember"
	MsgMuteMember     MessageType = "muteMember"
	MsgUpdateSettings MessageType = "updateSettings"

	// Battle control
	MsgStartBattle       MessageType = "startBattle"
	MsgPauseBattle       MessageType = "pauseBattle"
	MsgResumeBattle      MessageType = "resumeBattle"
	MsgBattleStateSync   MessageType = "battleStateSync"
	MsgUpdateSystemPrompt MessageType = "updateSystemPrompt"
	MsgInjectPrompt      MessageType = "injectPrompt"

	// Audience
	MsgCastVote   MessageType = "castVote"
	MsgVoteResult MessageType = "voteResult"
	MsgPowerUp    MessageType = "powerUp"
	MsgCrowdChant MessageType = "crowdChant"

	// Chat
	MsgChat MessageType = "chat"

	// Infra
	MsgPing  MessageType = "ping"
	MsgPong  MessageType = "pong"
	MsgError MessageType = "error"
)

// ─── Envelope ─────────────────────────────────────────────────────────────────

// Envelope is the wire format for all messages.
type Envelope struct {
	Type       MessageType     `json:"type"`
	LobbyID    string          `json:"lobbyId,omitempty"`
	SenderID   string          `json:"senderId,omitempty"`
	Timestamp  string          `json:"timestamp,omitempty"`
	rawPayload json.RawMessage // set from Payload during decode
}

// EnvelopeJSON is used for JSON marshal/unmarshal.
type EnvelopeJSON struct {
	Type      MessageType     `json:"type"`
	LobbyID   string          `json:"lobbyId,omitempty"`
	SenderID  string          `json:"senderId,omitempty"`
	Timestamp string          `json:"timestamp,omitempty"`
	Payload   json.RawMessage `json:"payload,omitempty"`
}

func (e *Envelope) MarshalJSON() ([]byte, error) {
	return json.Marshal(&EnvelopeJSON{
		Type:      e.Type,
		LobbyID:   e.LobbyID,
		SenderID:  e.SenderID,
		Timestamp: e.Timestamp,
		Payload:   e.rawPayload,
	})
}

func ParseEnvelope(data []byte) (*Envelope, error) {
	var ej EnvelopeJSON
	if err := json.Unmarshal(data, &ej); err != nil {
		return nil, err
	}
	return &Envelope{
		Type:       ej.Type,
		LobbyID:    ej.LobbyID,
		SenderID:   ej.SenderID,
		Timestamp:  ej.Timestamp,
		rawPayload: ej.Payload,
	}, nil
}

// ─── Payload types ────────────────────────────────────────────────────────────

type CreateLobbyPayload struct {
	LobbyID     string          `json:"lobbyId"`
	DisplayName string          `json:"displayName"`
	Visibility  string          `json:"visibility"` // "public" | "private" | "inviteOnly"
	Settings    json.RawMessage `json:"settings"`
}

type JoinLobbyPayload struct {
	LobbyID       string `json:"lobbyId"`
	DisplayName   string `json:"displayName"`
	RequestedRole string `json:"requestedRole"`
}

type AssignRolePayload struct {
	TargetMemberID string `json:"targetMemberId"`
	Role           string `json:"role"`
}

// ─── Roles ────────────────────────────────────────────────────────────────────

type Role string

const (
	RoleOwner     Role = "owner"
	RoleModerator Role = "moderator"
	RoleCommander Role = "commander"
	RoleSpectator Role = "spectator"
	RoleAudience  Role = "audience"
)

// ─── Lobby Status ─────────────────────────────────────────────────────────────

type LobbyStatus string

const (
	LobbyStatusWaiting    LobbyStatus = "waiting"
	LobbyStatusInProgress LobbyStatus = "inProgress"
	LobbyStatusComplete   LobbyStatus = "complete"
)

// ─── Lobby ────────────────────────────────────────────────────────────────────

// Lobby holds all state for one battle session.
type Lobby struct {
	mu sync.RWMutex

	ID         string
	OwnerID    string
	Status     LobbyStatus
	Visibility string
	CreatedAt  time.Time
	Settings   json.RawMessage

	Members map[string]*Member // clientID -> Member
}

// ─── Member ───────────────────────────────────────────────────────────────────

type Member struct {
	ID          string
	DisplayName string
	Role        Role
	IsConnected bool
	IsMuted     bool
	Client      *Client
}

// ─── Client ───────────────────────────────────────────────────────────────────

// Client represents one connected WebSocket session.
type Client struct {
	ID      string
	LobbyID string
	Send    chan *Envelope // outbound message queue

	hub *Hub
}

func (c *Client) send(env *Envelope) {
	select {
	case c.Send <- env:
	default:
		// Drop message if send buffer is full — client is too slow
	}
}

// WriteLoop drains the Send channel and writes to the WebSocket.
// Called from the ws package.
func (c *Client) WritePump(writeMsg func(*Envelope) error) {
	defer func() {
		c.hub.Unregister(c)
	}()

	for env := range c.Send {
		if err := writeMsg(env); err != nil {
			return
		}
	}
}

// ReadLoop reads from the WebSocket and dispatches to hub.
// Called from the ws package.
func (c *Client) ReadPump(readMsg func() ([]byte, error)) {
	defer func() {
		c.hub.Unregister(c)
	}()

	for {
		data, err := readMsg()
		if err != nil {
			return
		}

		env, err := ParseEnvelope(data)
		if err != nil {
			continue
		}

		env.SenderID = c.ID
		if env.LobbyID == "" {
			env.LobbyID = c.LobbyID
		}
		if env.Timestamp == "" {
			env.Timestamp = time.Now().Format(time.RFC3339)
		}

		c.hub.Dispatch(env)
	}
}

// NewClient creates a new client registered with the hub.
func NewClient(hub *Hub, id string) *Client {
	return &Client{
		ID:   id,
		Send: make(chan *Envelope, 256),
		hub:  hub,
	}
}
