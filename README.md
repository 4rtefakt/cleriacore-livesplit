# LiveSplit Autosplitter

Drives [LiveSplit](https://livesplit.org) from **Ys Origin** on CleriaCore. No memory reading, no `.asl` script:
the game tells the mod what happened, and the mod tells LiveSplit over its own WebSocket server.

| Event in the game | Sent to LiveSplit |
|---|---|
| A new game begins | `reset` (optional), then `starttimer` |
| A floor boss, Dalles or Darm is beaten | `split` |
| A mid-boss or a duel is won | `split` (can be turned off) |
| The first room of a new zone | `split` (off by default) |
| Play time, cutscenes and text boxes excluded | `initgametime`, then `setgametime` four times a second (off by default) |

## Setup

1. Download `4rtefakt.livesplit-1.0.0.cleriamod` from the [releases](../../releases), double-click it, turn
   **LiveSplit Autosplitter** on in F1 > Mods and restart CleriaCore.
2. In LiveSplit (1.8.29 or newer): right click > **Control > Start WebSocket Server**. LiveSplit asks for this at each
   launch unless you set *Startup Behavior* in its settings.
3. **F1 > Mods > LiveSplit** shows the connection. *Split now* sends one split to check it.

The address is `ws://127.0.0.1:16834/livesplit` by default (LiveSplit on the same computer); change it on the page
for another computer or port. If LiveSplit is not running the mod retries every five seconds and the game is not
affected.

Make your splits match what you turned on: with the defaults that is one split per boss fight won, in the order you
fight them.

Note: CleriaCore marks any run with an active mod as modded in its own speedrun mode. This mod changes nothing in
the game, but check your leaderboard's rules.

## How it works

One Lua file, [main.lua](main.lua), about 130 lines. LiveSplit's server takes one text command per WebSocket
message, so the whole link is:

```lua
local ws = cleria.net.websocket()
ws:open("ws://127.0.0.1:16834/livesplit")

cleria.events.on("boss_defeated", function(e)
    if e.flag then                       -- a floor boss: e.flag is its story flag
        if split_bosses then ws:send("split") end
    elseif split_mid then                -- a duel or a mid-boss
        ws:send("split")
    end
end)
```

| Part | API |
|---|---|
| The link | `cleria.net.websocket` (`open`, `poll` every frame, `send`, `state`) |
| What is sent | the events `new_game`, `boss_defeated`, `room_enter`, `tick` |
| Game time | ticks counted while `not cleria.game.frozen()`, kept in `cleria.save` |
| Settings and status | `cleria.ui.page` with toggles, a text field and a button |

## Tests

`python .dev/run.py` runs three cases through CleriaCore's headless harness against a small stand-in server
(`.dev/mock_livesplit.py`, needs the Python package `websockets`) that accepts `/livesplit` and records the
commands: the start is queued until the socket opens, a floor boss and a duel each split, the options turn splits
off and game time on, and with nothing listening the mod keeps retrying without disturbing the game.

**Not tested with LiveSplit itself.** The commands and the address are the ones LiveSplit's README documents, but no
run has been timed with the real program yet.

## About

Written with AI assistance (Claude Code) as a showcase of the CleriaCore mod API, and tested as described above.
MIT license.
