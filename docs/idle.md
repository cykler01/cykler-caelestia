# Keep awake

The utilities panel's *Keep awake* card is a single tri-state control instead of two separate
toggles, so the states cannot contradict each other.

[▶ Demo](https://cykler.dev/caelestia/demos/idle.mp4)

| State | What it does |
|---|---|
| Off | Nothing is inhibited |
| Prevent sleep | The display and suspend idle actions are gated, so the machine stays awake but can still lock |
| Prevent lock and sleep | The real Wayland idle inhibitor is used, so the machine neither locks nor sleeps |

When it is on, the card grows an active-since chip showing when the current state started.

## How it works

Only the strongest state takes a Wayland idle inhibitor, because that inhibitor cannot block sleep
while still allowing the lock. The weaker *prevent sleep* state is implemented by gating the
individual idle actions in `modules/IdleMonitors.qml` instead, which is why locking still works there
and not in the strongest state.

The state is persisted, so it survives a shell restart, and it can be driven without the panel:

```sh
qs -c caelestia ipc call idleInhibitor getMode
qs -c caelestia ipc call idleInhibitor setMode 2
qs -c caelestia ipc call idleInhibitor cycle
```

`0` is off, `1` is prevent sleep and `2` is prevent lock and sleep.

## Related settings

- `general.idle.inhibitWhenAudio` and `general.idle.inhibitWhenCharging` in `shell.json`, which the
  idle service also honours (`inhibitWhenCharging` is an upstream option; the fork's idle work is the
  card and its states).
- `general.idle.timeouts` for the idle actions themselves (lock, `dpms off`, suspend), and the lock
  and display timeouts in [Power & battery](battery.md).
