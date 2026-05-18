package lobby_test

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/yourusername/prompt-gladiators/relay/internal/lobby"
)

func TestParseEnvelope_ValidMessage(t *testing.T) {
	data := []byte(`{
		"type": "createLobby",
		"lobbyId": "lobby-abc",
		"senderId": "user-123",
		"timestamp": "2026-01-01T00:00:00Z",
		"payload": {"displayName": "TestHost", "visibility": "public"}
	}`)

	env, err := lobby.ParseEnvelope(data)
	if err != nil {
		t.Fatalf("ParseEnvelope error: %v", err)
	}
	if env.Type != lobby.MsgCreateLobby {
		t.Errorf("Type = %q, want %q", env.Type, lobby.MsgCreateLobby)
	}
	if env.LobbyID != "lobby-abc" {
		t.Errorf("LobbyID = %q, want %q", env.LobbyID, "lobby-abc")
	}
	if env.SenderID != "user-123" {
		t.Errorf("SenderID = %q, want %q", env.SenderID, "user-123")
	}
}

func TestParseEnvelope_InvalidJSON(t *testing.T) {
	_, err := lobby.ParseEnvelope([]byte(`{not valid`))
	if err == nil {
		t.Error("Expected error for invalid JSON, got nil")
	}
}

func TestParseEnvelope_EmptyPayload(t *testing.T) {
	data := []byte(`{"type": "ping", "senderId": "u1"}`)
	env, err := lobby.ParseEnvelope(data)
	if err != nil {
		t.Fatalf("ParseEnvelope error: %v", err)
	}
	if env.Type != lobby.MsgPing {
		t.Errorf("Type = %q, want ping", env.Type)
	}
}

func TestEnvelope_MarshalJSON(t *testing.T) {
	// Build an envelope via ParseEnvelope then re-marshal it
	data := []byte(`{
		"type": "chat",
		"lobbyId": "lobby-1",
		"senderId": "user-1",
		"timestamp": "2026-01-01T00:00:00Z",
		"payload": {"message": "hello"}
	}`)

	env, err := lobby.ParseEnvelope(data)
	if err != nil {
		t.Fatalf("ParseEnvelope error: %v", err)
	}

	remarshalled, err := json.Marshal(env)
	if err != nil {
		t.Fatalf("Marshal error: %v", err)
	}

	var result map[string]json.RawMessage
	if err := json.Unmarshal(remarshalled, &result); err != nil {
		t.Fatalf("Unmarshal of remarshalled data error: %v", err)
	}

	var msgType string
	if err := json.Unmarshal(result["type"], &msgType); err != nil {
		t.Fatalf("type field error: %v", err)
	}
	if msgType != "chat" {
		t.Errorf("remarshalled type = %q, want %q", msgType, "chat")
	}
}

func TestAllMessageTypes_HaveStringValues(t *testing.T) {
	types := []lobby.MessageType{
		lobby.MsgCreateLobby, lobby.MsgJoinLobby, lobby.MsgLeaveLobby,
		lobby.MsgLobbyState, lobby.MsgLobbyError, lobby.MsgAssignRole,
		lobby.MsgKickMember, lobby.MsgMuteMember, lobby.MsgUpdateSettings,
		lobby.MsgStartBattle, lobby.MsgPauseBattle, lobby.MsgResumeBattle,
		lobby.MsgBattleStateSync, lobby.MsgUpdateSystemPrompt, lobby.MsgInjectPrompt,
		lobby.MsgCastVote, lobby.MsgVoteResult, lobby.MsgPowerUp, lobby.MsgCrowdChant,
		lobby.MsgChat, lobby.MsgPing, lobby.MsgPong, lobby.MsgError,
	}

	seen := make(map[lobby.MessageType]bool)
	for _, mt := range types {
		if string(mt) == "" {
			t.Errorf("MessageType has empty string value")
		}
		if seen[mt] {
			t.Errorf("Duplicate MessageType: %q", mt)
		}
		seen[mt] = true
	}
}

func TestNewClient_HasUniqueID(t *testing.T) {
	hub := lobby.NewHub()
	go hub.Run()
	time.Sleep(5 * time.Millisecond)

	c1 := lobby.NewClient(hub, "id-001")
	c2 := lobby.NewClient(hub, "id-002")

	if c1.ID == c2.ID {
		t.Error("NewClient should produce clients with unique IDs")
	}
	if c1.ID != "id-001" {
		t.Errorf("c1.ID = %q, want %q", c1.ID, "id-001")
	}
}

func TestAllRoles_HaveStringValues(t *testing.T) {
	roles := []lobby.Role{
		lobby.RoleOwner, lobby.RoleModerator, lobby.RoleCommander,
		lobby.RoleSpectator, lobby.RoleAudience,
	}
	seen := make(map[lobby.Role]bool)
	for _, r := range roles {
		if string(r) == "" {
			t.Errorf("Role has empty string value")
		}
		if seen[r] {
			t.Errorf("Duplicate Role: %q", r)
		}
		seen[r] = true
	}
}
