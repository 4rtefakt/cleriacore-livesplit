-- LiveSplit Autosplitter: the game's events, sent to LiveSplit's own server as its text commands
-- (LiveSplit > right click > Control > Start WebSocket Server; ws://<host>:16834/livesplit).

local S, G = cleria.settings, cleria.game

local enabled = S.get("Enabled", true)
local address = S.get("Address", "ws://127.0.0.1:16834/livesplit")
local start_on_new = S.get("StartOnNewGame", true)
local reset_first = S.get("ResetFirst", true)        -- a new game resets a timer that still runs
local split_bosses = S.get("SplitBosses", true)      -- the floor bosses, Dalles and Darm
local split_mid = S.get("SplitMidBosses", true)      -- the duels and mid-bosses
local split_zones = S.get("SplitZones", false)       -- the first room of each new zone
local game_time = S.get("GameTime", false)           -- send the play time, cutscenes excluded

local ws, queue, status, retry_at = nil, {}, "not connected", 0
local sent = 0

local function connect()
    if ws then ws:close() else ws = cleria.net.websocket() end   -- one socket, reused: a closed one is only freed by the collector
    ws:open(address)
    status = "connecting"
end
local function send(cmd)
    if not enabled then return end
    if ws and ws:state() == "open" then
        ws:send(cmd)
        sent = sent + 1
        if not cmd:find("^setgametime") then cleria.log("-> " .. cmd) end
    elseif not cmd:find("^setgametime") then
        queue[#queue + 1] = cmd                      -- sent when the socket opens (a new game at start-up)
    end
end

-- ---- the socket: polled every frame, reopened every 5 seconds while it is down -------------------------------
cleria.events.on("frame", function()
    if not enabled then
        if ws then ws:close() ws = nil status = "off" end
        return
    end
    if not ws then
        if cleria.time() >= retry_at then connect() end
        return
    end
    for _, e in ipairs(ws:poll()) do
        if e.kind == "open" then
            status = "connected"
            cleria.log("connected to " .. address)
            local q = queue
            queue = {}
            for _, cmd in ipairs(q) do send(cmd) end
        elseif e.kind == "close" then
            if status == "connected" then cleria.log("connection closed") end
            local why = type(e.text) == "string" and e.text ~= "" and e.text or nil
            status = why and ("not connected (" .. why .. ")") or "not connected"
            ws, retry_at = nil, cleria.time() + 5
            return
        end
    end
end)

-- ---- the run -------------------------------------------------------------------------------------------------
local ticks = 0                                      -- play time of this save, cutscenes and boxes excluded
local function restore() ticks = cleria.save.get("ticks", 0) end
cleria.events.on("load", restore)
cleria.events.on("new_game", function()
    ticks = 0
    if cleria.save.ready() then cleria.save.set("zone", G.scene() // 1000) end
    if not start_on_new then return end
    if reset_first then send("reset") end
    send("starttimer")
    if game_time then send("initgametime") end
end)

cleria.events.on("boss_defeated", function(e)
    if e.flag then
        if split_bosses then send("split") end
    elseif split_mid then
        send("split")
    end
end)

cleria.events.on("room_enter", function()
    if not split_zones or not cleria.save.ready() then return end
    local zone = G.scene() // 1000
    if zone >= 1 and zone <= 7 and zone > cleria.save.get("zone", 1) then
        cleria.save.set("zone", zone)
        send("split")
    end
end)

cleria.events.on("tick", function()
    if not G.in_game() or G.frozen() then return end
    ticks = ticks + 1
    if ticks % 60 == 0 and cleria.save.ready() then cleria.save.set("ticks", ticks) end
    if game_time and ticks % 15 == 0 then send(string.format("setgametime %.2f", ticks / 60)) end
end)

cleria.ui.page("LiveSplit", function(p)
    p:section("LiveSplit")
    p:info("Connection", status, {color = status == "connected" and "good" or "warn",
           desc = "In LiveSplit: right click > Control > Start WebSocket Server."})
    local v, ch = p:toggle("Enabled", enabled, "Connects to LiveSplit and sends it the run's events.")
    if ch then enabled = v S.set("Enabled", v) retry_at = 0 end
    v, ch = p:text_field("Address", address, {desc = "LiveSplit's WebSocket server. The default is this computer, port 16834."})
    if ch then address = v S.set("Address", v) if ws then ws:close() ws = nil end retry_at = 0 end
    p:section("Start")
    v, ch = p:toggle("Start on New Game", start_on_new, "The timer starts when a new game begins.")
    if ch then start_on_new = v S.set("StartOnNewGame", v) end
    v, ch = p:toggle("Reset first", reset_first, "A new game resets a timer that is still running, then starts it.")
    if ch then reset_first = v S.set("ResetFirst", v) end
    p:section("Splits")
    v, ch = p:toggle("Floor bosses", split_bosses, "Velagunder, Nygtilger, Gelaldy, Khonsclard, Pictimos, Zava, Dalles and Darm.")
    if ch then split_bosses = v S.set("SplitBosses", v) end
    v, ch = p:toggle("Mid-bosses and duels", split_mid, "Every other boss fight you win.")
    if ch then split_mid = v S.set("SplitMidBosses", v) end
    v, ch = p:toggle("New zones", split_zones, "The first room of each zone you have not been to in this save.")
    if ch then split_zones = v S.set("SplitZones", v) end
    p:section("Game time")
    v, ch = p:toggle("Send the game time", game_time, "The play time without cutscenes and text boxes, four times a second. Compare against Game Time in LiveSplit.")
    if ch then game_time = v S.set("GameTime", v) end
    if p:button("Split now", {desc = "Sends one split, to check the connection.", enabled = status == "connected"}) then send("split") end
end)

cleria.speedrun.modification("LiveSplit Autosplitter (sends events, changes nothing in the game)")
cleria.command("ls", function() cleria.log("status " .. status .. " sent " .. sent .. " queued " .. #queue) end)
cleria.log("LiveSplit Autosplitter loaded")
