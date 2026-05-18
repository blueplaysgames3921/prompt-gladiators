package auth_test

import (
	"testing"

	"github.com/yourusername/prompt-gladiators/relay/internal/auth"
)

func TestValidator(t *testing.T) {
	t.Run("empty token disables auth", func(t *testing.T) {
		v := auth.New("")
		if v.IsEnabled() {
			t.Error("IsEnabled() should be false for empty token")
		}
		if !v.Validate("anything") {
			t.Error("Validate() should return true when auth is disabled")
		}
		if !v.Validate("") {
			t.Error("Validate('') should return true when auth is disabled")
		}
	})

	t.Run("correct token validates", func(t *testing.T) {
		v := auth.New("super-secret-token")
		if !v.IsEnabled() {
			t.Error("IsEnabled() should be true when token is set")
		}
		if !v.Validate("super-secret-token") {
			t.Error("Validate() should return true for correct token")
		}
	})

	t.Run("wrong token fails", func(t *testing.T) {
		v := auth.New("correct-token")
		if v.Validate("wrong-token") {
			t.Error("Validate() should return false for wrong token")
		}
		if v.Validate("") {
			t.Error("Validate('') should return false when auth is enabled")
		}
		if v.Validate("CORRECT-TOKEN") { // case sensitive
			t.Error("Validate() should be case-sensitive")
		}
	})

	t.Run("timing safe comparison", func(t *testing.T) {
		// Test that it doesn't short-circuit (constant-time)
		// We can't easily measure timing, but we can verify correctness
		// for same-length wrong tokens
		v := auth.New("aaaaaaaa")
		if v.Validate("aaaaaaab") {
			t.Error("Should not validate token that differs only in last char")
		}
		if v.Validate("baaaaaaa") {
			t.Error("Should not validate token that differs only in first char")
		}
	})
}
