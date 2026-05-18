package battle_test

import (
	"testing"

	"github.com/yourusername/prompt-gladiators/relay/internal/battle"
)

func TestVoteResult(t *testing.T) {
	tests := []struct {
		name  string
		votes map[string]int
		want  string
	}{
		{
			name:  "A wins clearly",
			votes: map[string]int{"a": 10, "b": 3, "draw": 1},
			want:  "a",
		},
		{
			name:  "B wins clearly",
			votes: map[string]int{"a": 2, "b": 8, "draw": 0},
			want:  "b",
		},
		{
			name:  "Draw on tie",
			votes: map[string]int{"a": 5, "b": 5, "draw": 2},
			want:  "draw",
		},
		{
			name:  "All zero votes",
			votes: map[string]int{"a": 0, "b": 0, "draw": 0},
			want:  "draw",
		},
		{
			name:  "Only A votes",
			votes: map[string]int{"a": 7},
			want:  "a",
		},
		{
			name:  "Empty votes",
			votes: map[string]int{},
			want:  "draw",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := battle.VoteResult(tt.votes)
			if got != tt.want {
				t.Errorf("VoteResult(%v) = %q, want %q", tt.votes, got, tt.want)
			}
		})
	}
}

func TestELOUpdate(t *testing.T) {
	tests := []struct {
		name   string
		rating int
		won    bool
		isDraw bool
		wantGT int // result should be greater than
		wantLT int // result should be less than
	}{
		{
			name:   "Win from average rating",
			rating: 1000,
			won:    true,
			isDraw: false,
			wantGT: 1000,
			wantLT: 1040,
		},
		{
			name:   "Loss from average rating",
			rating: 1000,
			won:    false,
			isDraw: false,
			wantGT: 960,
			wantLT: 1000,
		},
		{
			name:   "Draw from average rating stays near 1000",
			rating: 1000,
			won:    false,
			isDraw: true,
			wantGT: 990,
			wantLT: 1010,
		},
		{
			name:   "High-rated player winning gets smaller bonus",
			rating: 1500,
			won:    true,
			isDraw: false,
			wantGT: 1500,
			wantLT: 1535, // smaller gain because they're favoured
		},
		{
			name:   "Low-rated player winning gets larger bonus",
			rating: 500,
			won:    true,
			isDraw: false,
			wantGT: 530, // larger gain because upset
			wantLT: 600,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := battle.ELOUpdate(tt.rating, tt.won, tt.isDraw)
			if got <= tt.wantGT {
				t.Errorf("ELOUpdate(%d, won=%v, draw=%v) = %d, want > %d",
					tt.rating, tt.won, tt.isDraw, got, tt.wantGT)
			}
			if got >= tt.wantLT {
				t.Errorf("ELOUpdate(%d, won=%v, draw=%v) = %d, want < %d",
					tt.rating, tt.won, tt.isDraw, got, tt.wantLT)
			}
		})
	}
}

func TestParseSnapshot(t *testing.T) {
	tests := []struct {
		name    string
		json    string
		wantErr bool
		check   func(t *testing.T, s *battle.StateSnapshot)
	}{
		{
			name: "Valid snapshot",
			json: `{
				"id": "abc-123",
				"status": "inProgress",
				"currentRound": 2,
				"totalRounds": 5,
				"scoreA": 14.5,
				"scoreB": 12.0
			}`,
			wantErr: false,
			check: func(t *testing.T, s *battle.StateSnapshot) {
				if s.ID != "abc-123" {
					t.Errorf("ID = %q, want %q", s.ID, "abc-123")
				}
				if s.Status != battle.StatusInProgress {
					t.Errorf("Status = %q, want inProgress", s.Status)
				}
				if s.CurrentRound != 2 {
					t.Errorf("CurrentRound = %d, want 2", s.CurrentRound)
				}
				if s.ScoreA != 14.5 {
					t.Errorf("ScoreA = %f, want 14.5", s.ScoreA)
				}
			},
		},
		{
			name:    "Invalid JSON",
			json:    `{not valid json`,
			wantErr: true,
		},
		{
			name: "Empty JSON fills UpdatedAt",
			json: `{}`,
			wantErr: false,
			check: func(t *testing.T, s *battle.StateSnapshot) {
				if s.UpdatedAt.IsZero() {
					t.Error("UpdatedAt should not be zero for empty snapshot")
				}
			},
		},
		{
			name: "Extra fields are ignored",
			json: `{
				"id": "test",
				"unknownField": "ignored",
				"status": "complete"
			}`,
			wantErr: false,
			check: func(t *testing.T, s *battle.StateSnapshot) {
				if s.Status != battle.StatusComplete {
					t.Errorf("Status = %q, want complete", s.Status)
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			s, err := battle.ParseSnapshot([]byte(tt.json))
			if tt.wantErr {
				if err == nil {
					t.Error("Expected error, got nil")
				}
				return
			}
			if err != nil {
				t.Errorf("Unexpected error: %v", err)
				return
			}
			if tt.check != nil {
				tt.check(t, s)
			}
		})
	}
}
