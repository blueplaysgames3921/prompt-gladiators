package metrics_test

import (
	"strings"
	"testing"

	"github.com/yourusername/prompt-gladiators/relay/pkg/metrics"
)

func TestMetrics_Summary(t *testing.T) {
	// Summary should return valid JSON-like output
	summary := metrics.Summary()
	if summary == "" {
		t.Fatal("Summary() returned empty string")
	}
	if !strings.Contains(summary, "uptime") {
		t.Errorf("Summary missing 'uptime': %s", summary)
	}
	if !strings.Contains(summary, "totalMessages") {
		t.Errorf("Summary missing 'totalMessages': %s", summary)
	}
	if !strings.Contains(summary, "activeClients") {
		t.Errorf("Summary missing 'activeClients': %s", summary)
	}
}

func TestMetrics_RecordMessage(t *testing.T) {
	before := metrics.Summary()
	metrics.RecordMessage()
	metrics.RecordMessage()
	after := metrics.Summary()

	// Both are valid JSON strings - just verify no panic and both non-empty
	if before == "" || after == "" {
		t.Error("Summary should not be empty")
	}
}

func TestMetrics_ConnectDisconnect(t *testing.T) {
	// Record a connect and disconnect - should not panic
	metrics.RecordConnect()
	metrics.RecordDisconnect()
	summary := metrics.Summary()
	if summary == "" {
		t.Error("Summary should not be empty after connect/disconnect")
	}
}

func TestMetrics_SetLobbies(t *testing.T) {
	metrics.SetLobbies(5)
	summary := metrics.Summary()
	if !strings.Contains(summary, "activeLobbies") {
		t.Errorf("Summary missing 'activeLobbies': %s", summary)
	}
	// Reset
	metrics.SetLobbies(0)
}
