# Notification dock

Two changes to how the sidebar's notification dock handles messages.

[▶ Demo](https://cykler.dev/caelestia/demos/notifications.mp4)

## Chat apps keep every message

Chat apps reuse a single notification per conversation and replace it with each new message, so the
dock used to show only the newest one. For the apps listed in `notifs.chatApps`, the replaced message
is now kept as its own notification instead: the old message is snapshotted before any of its fields
change, kept once all the changes have arrived, and the live notification moves to the top holding the
newest message.

```json
"notifs": {
    "keepChatHistory": true,
    "chatApps": ["vesktop", "discord", "vencord", "legcord", "webcord", "equibop", "slack", "signal", "telegram", "whatsapp", "firefox"]
}
```

Set `keepChatHistory` to `false` to go back to only ever showing the newest message, and trim
`chatApps` to the apps you actually want this for. Matching is a case-insensitive substring test, so
`discord` also catches `Vesktop`.

## Every message keeps its own picture

In a group, each message now shows its own image next to it rather than the group showing one picture
for everything. That is what makes a chat conversation keep its several senders' avatars apart, and it
applies to any grouped notification that carries images.

## Any corner, and sharing a column

Notification popups and toasts are no longer tied to the right edge:

```json
"notifs": {
    "side": "right",
    "edge": "top"
},
"utilities": {
    "toasts": {
        "side": "right",
        "edge": "bottom"
    }
}
```

`side` is `left` or `right` and `edge` is `top` or `bottom`, which together give any of the four
corners. When popups and toasts pick the same corner they share a column instead of stacking on top of
each other, so neither hides the other.

The sidebar, utilities and the popout have a side too (`sidebar.side`, `notifPopout.side`), and the
OSD and session menu have theirs (`osd.side`, `session.side`). All of them are set by dragging tiles on
*Settings → Layout* - see [layout.md](layout.md).

## Related

- The dock's placeholder image, and the rest of the shell's images, are configurable from
  [Shell assets](shell-assets.md).
- Expanded behaviour, expiry and grouping counts are the upstream `notifs.*` options
  (`expire`, `groupPreviewNum`, `clearThreshold`, `openExpanded` and so on); only `keepChatHistory`
  and `chatApps` are ours.
