// Package metrics provides simple in-memory counters for the relay server.
package metrics

import (
	"fmt"
	"sync/atomic"
	"time"
)

var (
	startTime      = time.Now()
	totalMessages  atomic.Int64
	totalConnects  atomic.Int64
	activeClients  atomic.Int64
	activeLobbies  atomic.Int64
)

func RecordMessage()    { totalMessages.Add(1) }
func RecordConnect()    { totalConnects.Add(1); activeClients.Add(1) }
func RecordDisconnect() { activeClients.Add(-1) }
func SetLobbies(n int)  { activeLobbies.Store(int64(n)) }

// Summary returns a JSON string with current metrics.
func Summary() string {
	uptime := time.Since(startTime).Round(time.Second)
	return fmt.Sprintf(
		`{"uptime":%q,"totalMessages":%d,"totalConnects":%d,"activeClients":%d,"activeLobbies":%d}`,
		uptime.String(),
		totalMessages.Load(),
		totalConnects.Load(),
		activeClients.Load(),
		activeLobbies.Load(),
	)
}
