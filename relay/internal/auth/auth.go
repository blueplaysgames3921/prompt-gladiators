// Package auth provides simple bearer token validation for the relay server.
package auth

import (
	"crypto/subtle"
)

// Validator holds the configured auth token.
type Validator struct {
	token string
}

// New returns a Validator. If token is empty, all connections are allowed.
func New(token string) *Validator {
	return &Validator{token: token}
}

// IsEnabled returns true if auth is configured.
func (v *Validator) IsEnabled() bool {
	return v.token != ""
}

// Validate checks whether the provided token matches.
// Uses constant-time comparison to prevent timing attacks.
func (v *Validator) Validate(provided string) bool {
	if !v.IsEnabled() {
		return true
	}
	return subtle.ConstantTimeCompare(
		[]byte(provided),
		[]byte(v.token),
	) == 1
}
