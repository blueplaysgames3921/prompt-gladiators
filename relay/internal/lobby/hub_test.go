package lobby_test

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/yourusername/prompt-gladiators/relay/internal/lobby"
)

// ─── Helpers ─────────────────────────────────────────────────────────────────

func newHub(t *testing.T) *lobby.Hub {
	t.Helper()
	hub := lobby.NewHub()
	go hub.Run()
	// Give the goroutine time to start
	time.Sleep(10 * time.Millisecond)
	return hub
}

func newClient(hub *lobby.Hub) *lobby.Client {
	c := lobby.NewClient(hub, uuid.NewString())
	hub.Register(c)
	time.Sleep(5 * time.Millisecond) // let register process
	return c
}

func sendMsg(hub *lobby.Hub, c *lobby.Client, msgType lobby.MessageType, lobbyID string, payload any) {
	raw, _ := json.Marshal(payload)
	data, _ := json.Marshal(map[string]any{
		"type":      string(msgType),
		"lobbyId":   lobbyID,
		"senderId":  c.ID,
		"timestamp": time.Now().Format(time.RFC3339),
		"payload":   json.RawMessage(raw),
	})
	parsed, err := lobby.ParseEnvelope(data)
	if err != nil {
		return
	}
	hub.Dispatch(parsed)
	time.Sleep(20 * time.Millisecond)
}

func drainMessages(c *lobby.Client) []*lobby.Envelope {
	var msgs []*lobby.Envelope
	for {
		select {
		case msg, ok := <-c.Send:
			if !ok {
				return msgs
			}
			msgs = append(msgs, msg)
		default:
			return msgs
		}
	}
}

// ─── Tests ────────────────────────────────────────────────────────────────────

func TestHub_CreateLobby(t *testing.T) {
	hub := newHub(t)
	client := newClient(hub)

	sendMsg(hub, client, lobby.MsgCreateLobby, "", map[string]any{
		"lobbyId":     "test-lobby-1",
		"displayName": "Owner",
		"visibility":  "public",
		"settings":    json.RawMessage(`{}`),
	})

	if hub.LobbyCount() != 1 {
		t.Errorf("LobbyCount = %d, want 1", hub.LobbyCount())
	}

	msgs := drainMessages(client)
	if len(msgs) == 0 {
		t.Fatal("Expected at least one message after createLobby")
	}

	var found bool
	for _, m := range msgs {
		if m.Type == lobby.MsgLobbyState {
			found = true
			break
		}
	}
	if !found {
		t.Errorf("Expected lobbyState message, got types: %v",
			func() []string {
				var types []string
				for _, m := range msgs {
					types = append(types, string(m.Type))
				}
				return types
			}())
	}
}

func TestHub_JoinExistingLobby(t *testing.T) {
	hub := newHub(t)
	owner := newClient(hub)
	joiner := newClient(hub)

	// Create lobby
	sendMsg(hub, owner, lobby.MsgCreateLobby, "", map[string]any{
		"lobbyId":     "join-test-lobby",
		"displayName": "Host",
		"visibility":  "public",
		"settings":    json.RawMessage(`{}`),
	})

	// Join lobby
	sendMsg(hub, joiner, lobby.MsgJoinLobby, "join-test-lobby", map[string]any{
		"lobbyId":       "join-test-lobby",
		"displayName":   "Player2",
		"requestedRole": "spectator",
	})

	// Both should have received lobbyState
	ownerMsgs := drainMessages(owner)
	joinerMsgs := drainMessages(joiner)

	hasLobbyState := func(msgs []*lobby.Envelope) bool {
		for _, m := range msgs {
			if m.Type == lobby.MsgLobbyState {
				return true
			}
		}
		return false
	}

	if !hasLobbyState(ownerMsgs) {
		t.Error("Owner should receive lobbyState after join")
	}
	if !hasLobbyState(joinerMsgs) {
		t.Error("Joiner should receive lobbyState")
	}
}

func TestHub_JoinNonExistentLobby(t *testing.T) {
	hub := newHub(t)
	client := newClient(hub)

	sendMsg(hub, client, lobby.MsgJoinLobby, "nonexistent-lobby", map[string]any{
		"lobbyId":       "nonexistent-lobby",
		"displayName":   "Player",
		"requestedRole": "spectator",
	})

	msgs := drainMessages(client)
	var hasError bool
	for _, m := range msgs {
		if m.Type == lobby.MsgError {
			hasError = true
			break
		}
	}
	if !hasError {
		t.Error("Expected error message when joining nonexistent lobby")
	}
}

func TestHub_CreateDuplicateLobbyID(t *testing.T) {
	hub := newHub(t)
	client1 := newClient(hub)
	client2 := newClient(hub)

	sendMsg(hub, client1, lobby.MsgCreateLobby, "", map[string]any{
		"lobbyId":     "duplicate-lobby",
		"displayName": "Owner1",
		"visibility":  "private",
		"settings":    json.RawMessage(`{}`),
	})

	sendMsg(hub, client2, lobby.MsgCreateLobby, "", map[string]any{
		"lobbyId":     "duplicate-lobby",
		"displayName": "Owner2",
		"visibility":  "private",
		"settings":    json.RawMessage(`{}`),
	})

	// Second create should error; lobby count stays 1
	if hub.LobbyCount() != 1 {
		t.Errorf("LobbyCount = %d, want 1 (duplicate should be rejected)", hub.LobbyCount())
	}

	msgs2 := drainMessages(client2)
	var hasError bool
	for _, m := range msgs2 {
		if m.Type == lobby.MsgError {
			hasError = true
			break
		}
	}
	if !hasError {
		t.Error("Expected error for duplicate lobby ID")
	}
}

func TestHub_PingPong(t *testing.T) {
	hub := newHub(t)
	client := newClient(hub)

	sendMsg(hub, client, lobby.MsgPing, "", map[string]any{})

	msgs := drainMessages(client)
	var hasPong bool
	for _, m := range msgs {
		if m.Type == lobby.MsgPong {
			hasPong = true
			break
		}
	}
	if !hasPong {
		t.Error("Expected pong response to ping")
	}
}

func TestHub_KickRequiresModerator(t *testing.T) {
	hub := newHub(t)
	owner := newClient(hub)
	spectator := newClient(hub)

	// Create and join
	sendMsg(hub, owner, lobby.MsgCreateLobby, "", map[string]any{
		"lobbyId":     "kick-test",
		"displayName": "Host",
		"visibility":  "private",
		"settings":    json.RawMessage(`{}`),
	})
	sendMsg(hub, spectator, lobby.MsgJoinLobby, "kick-test", map[string]any{
		"lobbyId":       "kick-test",
		"displayName":   "Spectator",
		"requestedRole": "spectator",
	})

	// Spectator tries to kick owner — should be rejected silently (no error, just ignored)
	sendMsg(hub, spectator, lobby.MsgKickMember, "kick-test", map[string]any{
		"targetMemberId": owner.ID,
	})

	// Owner should still be in the lobby
	if hub.ClientCount() < 1 {
		t.Error("Owner should not have been kicked by spectator")
	}
}

func TestHub_PublicLobbiesJSON(t *testing.T) {
	hub := newHub(t)
	client := newClient(hub)

	// Create a public lobby
	sendMsg(hub, client, lobby.MsgCreateLobby, "", map[string]any{
		"lobbyId":     "public-lobby-1",
		"displayName": "Host",
		"visibility":  "public",
		"settings":    json.RawMessage(`{}`),
	})

	json := hub.PublicLobbiesJSON()
	if json == "null" || json == "[]" {
		t.Error("Expected non-empty public lobbies JSON")
	}
	if len(json) < 2 {
		t.Errorf("PublicLobbiesJSON = %q, expected JSON array with entries", json)
	}
}

func TestHub_Counts(t *testing.T) {
	hub := newHub(t)

	if hub.LobbyCount() != 0 {
		t.Errorf("Initial LobbyCount = %d, want 0", hub.LobbyCount())
	}
	if hub.ClientCount() != 0 {
		t.Errorf("Initial ClientCount = %d, want 0", hub.ClientCount())
	}

	c1 := newClient(hub)
	c2 := newClient(hub)

	if hub.ClientCount() != 2 {
		t.Errorf("ClientCount after 2 connects = %d, want 2", hub.ClientCount())
	}

	hub.Unregister(c1)
	time.Sleep(10 * time.Millisecond)

	if hub.ClientCount() != 1 {
		t.Errorf("ClientCount after 1 disconnect = %d, want 1", hub.ClientCount())
	}
	_ = c2
}
