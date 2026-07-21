# Module Contract and Channel Port Templates

Genericized Go templates. Translate idioms to the project's language; the *shape* is the contract.

## The module contract

A module is the tuple: **config schema + validation, capabilities it contributes, routes/UI it registers, adapters it provides, permissions it needs.** Encode that literally:

```go
// core/module.go — owned by the core, implemented by modules.
type Module interface {
    Name() string

    // ValidateConfig checks the module's OWN config section.
    // Core validates composition only (no duplicate names, deps present).
    ValidateConfig() error

    // Capabilities the core engine may invoke (tools, domain actions).
    Capabilities() []core.Capability

    // RegisterRoutes mounts the module's HTTP/UI surface, namespaced.
    RegisterRoutes(r core.Router)

    // Adapters returns implementations of core ports this module provides
    // (e.g. a Channel, a Store, a Notifier). Keyed by port name.
    Adapters() map[string]any

    // Permissions the module needs, DECLARED up front. Core enforces;
    // a module reaching for an undeclared permission is a startup error.
    Permissions() []core.Permission
}
```

### Example module

```go
// modules/tickets/module.go
type TicketsModule struct {
    cfg   TicketsConfig // the module owns its config struct...
    store TicketStore
}

func New(cfg TicketsConfig, store TicketStore) *TicketsModule { ... }

func (m *TicketsModule) ValidateConfig() error { return m.cfg.Validate() } // ...and its validation

func (m *TicketsModule) Capabilities() []core.Capability {
    return []core.Capability{
        {Name: "create_ticket", Handler: m.createTicket, Schema: createTicketSchema},
        {Name: "resolve_ticket", Handler: m.resolveTicket, Schema: resolveSchema},
    }
}
```

### Composition root — explicit registration, no magic

```go
// cmd/app/main.go — the ONE place wiring is visible.
func main() {
    cfg := config.Load() // Config{Core CoreConfig, Tickets TicketsConfig, Voice VoiceConfig, ...}

    app := core.NewApp(cfg.Core)
    app.Register(tickets.New(cfg.Tickets, pgTicketStore))
    app.Register(voicechannel.New(cfg.Voice, sttFactory, ttsFactory))
    app.Register(textchannel.New(cfg.Text))

    if err := app.Start(ctx); err != nil { log.Fatal(err) } // Start() runs ValidateConfig on every module first
}
```

Rules the template enforces:

- **No `init()` discovery, no blank imports for side effects, no classpath/reflection scanning.** "Who wired this in?" must be answerable by grepping `app.Register`.
- **Per-module config with per-module validation.** Core never reads a module's fields; a module never reads another module's config. Cross-module needs go through capabilities or ports.
- **Startup fails loudly** on: invalid module config, duplicate capability names, undeclared permission use.

## The Channel port (conversational/session systems)

The core engine sees the smallest interface that lets a conversation happen. Everything transport-specific stays in the adapter.

```go
// core/channel.go — consumer-defined: shaped by what the engine needs, nothing more.
type Channel interface {
    // Receive blocks for the next user input (final, endpointed).
    // The ADAPTER owns endpointing/VAD/debounce — the engine sees turns.
    Receive(ctx context.Context) (Input, error)

    // Emit sends assistant output. Adapter renders it (TTS, markdown, SMS segments).
    Emit(ctx context.Context, out Output) error

    // Interrupt is signaled by the adapter when the user barges in / cancels.
    Interrupt() <-chan struct{}

    // Close ends the channel; idempotent.
    Close(reason CloseReason) error

    // Meta describes capabilities so the engine can adapt output
    // (audio? rich cards? max message length?) without knowing the transport.
    Meta() ChannelMeta
}

type Input struct {
    Text     string
    At       time.Time
    Ext      map[string]any // per-channel extras (confidence, DTMF, attachment refs)
}

type Output struct {
    Text     string
    Actions  []Action       // channel-neutral domain actions the adapter may surface
    Ext      map[string]any
}
```

Adapters: `voicechannel` (STT/TTS/barge-in inside), `textchannel`, `surveychannel`, `apichannel`. The engine's tests run against a scripted fake `Channel` — this is the extraction that collapses test cost when real channels need paid APIs.

### Channel-neutral records

```go
// ONE session type. Never VoiceSession / ChatSession forks.
type Session struct {
    ID          string
    ChannelKind string         // "voice" | "text" | "survey" | ...
    Transcript  []Turn         // channel-neutral
    Outcome     Outcome
    ChannelData map[string]any // adapter-owned extras: call SID, phone, ws connection info
}
```

Decision rule: a field goes in the shared struct only if ≥2 channels use it with the same meaning; otherwise it goes in `ChannelData` (or a typed optional sub-struct once it stabilizes). Queries, retention, analytics, and admin UI read only the shared fields — so they work for every channel ever added.

## The Command port (request/response, batch, and job consumers)

Channel is for streaming/session transports only. Request/response consumers — REST endpoints, batch imports, queue workers — get a **Command-shaped port** instead: a consumer-defined interface whose methods take a context plus a request struct and return a typed result plus error.

```go
// core/commands.go — consumer-defined: shaped by what the callers need, nothing more.
type OrderCommands interface {
    PlaceOrder(ctx context.Context, req PlaceOrderRequest) (PlaceOrderResult, error)
    CancelOrder(ctx context.Context, req CancelOrderRequest) (CancelOrderResult, error)
}

type PlaceOrderRequest struct {
    IdempotencyKey string // caller-supplied; the core dedupes retries on it
    CustomerID     string
    Items          []LineItem
}

type PlaceOrderResult struct {
    OrderID string
    Status  OrderStatus
}
```

Batch note: batch adapters call the port **per item** and aggregate partial failures adapter-side:

```go
// adapter-side only — the core never sees this type.
type BatchItemResult struct {
    ID     string
    Result PlaceOrderResult
    Err    error
}

type BatchResult struct {
    Items []BatchItemResult
}
```

The core stays single-item and knows nothing about batching, concurrency policy, or aggregation — those are adapter concerns, and different batch consumers will want different policies.

Decision rule: Idempotency keys belong in the port signature from the moment a retrying or batch consumer is on the roadmap — cheap while the interface is being cut, expensive to retrofit once two adapters depend on it.

## Registry template (extraction step 4)

```go
// core/registry.go
type Registry[T any] struct{ m map[string]T }

func (r *Registry[T]) Register(name string, v T) {
    if _, dup := r.m[name]; dup { panic("duplicate registration: " + name) } // fail at startup, loudly
    r.m[name] = v
}
func (r *Registry[T]) Get(name string) (T, bool) { v, ok := r.m[name]; return v, ok }
```

Callers replace `switch kind {...}` with `handler, ok := reg.Get(kind)`; the `!ok` branch keeps whatever the old switch's `default` did (characterization tests confirm). All `Register` calls live in main/composition root.
