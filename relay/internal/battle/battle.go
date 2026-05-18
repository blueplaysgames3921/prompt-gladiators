// Package battle provides helpers for syncing and validating battle state
// through the relay server.
package battle

import (
	"encoding/json"
	"time"
)

// Status mirrors the Flutter BattleStatus enum.
type Status string

const (
	StatusLobby      Status = "lobby"
	StatusCountdown  Status = "countdown"
	StatusInProgress Status = "inProgress"
	StatusPaused     Status = "paused"
	StatusJudging    Status = "judging"
	StatusVoting     Status = "voting"
	StatusComplete   Status = "complete"
)

// StateSnapshot is a lightweight summary of battle state
// used by the relay for health checks and lobby listings.
type StateSnapshot struct {
	ID           string    `json:"id"`
	Status       Status    `json:"status"`
	CurrentRound int       `json:"currentRound"`
	TotalRounds  int       `json:"totalRounds"`
	ScoreA       float64   `json:"scoreA"`
	ScoreB       float64   `json:"scoreB"`
	UpdatedAt    time.Time `json:"updatedAt"`
}

// ParseSnapshot extracts a StateSnapshot from a raw battle state JSON payload.
// It is tolerant of unknown fields (forward-compatible with Flutter model changes).
func ParseSnapshot(raw json.RawMessage) (*StateSnapshot, error) {
	var s StateSnapshot
	if err := json.Unmarshal(raw, &s); err != nil {
		return nil, err
	}
	if s.UpdatedAt.IsZero() {
		s.UpdatedAt = time.Now()
	}
	return &s, nil
}

// VoteResult computes the winning side from a vote map.
// Returns "a", "b", or "draw".
func VoteResult(votes map[string]int) string {
	aVotes := votes["a"]
	bVotes := votes["b"]
	switch {
	case aVotes > bVotes:
		return "a"
	case bVotes > aVotes:
		return "b"
	default:
		return "draw"
	}
}

// ELOUpdate computes the new ELO rating for a player after a match.
// K=32, assumes opponent baseline of 1000.
func ELOUpdate(rating int, won bool, isDraw bool) int {
	const k = 32
	const opponentRating = 1000
	expected := 1.0 / (1.0 + pow10((opponentRating-rating)/400.0))
	var score float64
	switch {
	case isDraw:
		score = 0.5
	case won:
		score = 1.0
	default:
		score = 0.0
	}
	return rating + int(k*(score-expected))
}

// pow10 computes 10^x.
func pow10(x float64) float64 {
	result := 1.0
	negative := x < 0
	if negative {
		x = -x
	}
	// Simple integer part
	intPart := int(x)
	fracPart := x - float64(intPart)
	for i := 0; i < intPart; i++ {
		result *= 10
	}
	// Fractional part via exp: 10^f = e^(f*ln10)
	// ln(10) ≈ 2.302585
	const ln10 = 2.302585092994046
	// e^x ≈ Taylor series for small x
	ef := expApprox(fracPart * ln10)
	result *= ef
	if negative {
		return 1.0 / result
	}
	return result
}

// expApprox computes e^x via a 10-term Taylor series.
func expApprox(x float64) float64 {
	result := 1.0
	term := 1.0
	for i := 1; i <= 10; i++ {
		term *= x / float64(i)
		result += term
	}
	return result
}
