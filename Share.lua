local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- (0.2.0 beta, Daniel 12.10.: "how do we get data from other players? like Questdon"; "build it in, by all
-- means") Leveldon shares how its routes go, the way Questdon shares learned quest data:
--   * only your own observations, only numbers and the route's names (never text, never names of players),
--   * through Questdon's open channel (QuestdonNet, QuestdonAPI.ShareChannelID), your guild and your group,
--   * receivers add them up (LeveldonDB.net); your own copy of what others saw goes into /lvd export, so it
--     reaches the route builder whenever one Leveldon player sends his export.
-- Lines (one fact each):
--   G race cls ri k q how secs lv   a step left: route index ri, kind k (letter), quest q, how d (done) or
--                                   s (skipped by hand), seconds spent on it, your level
--   R race cls ri k q reason lv     a report: g (quest giver not there), r (route makes no sense), n (note);
--                                   the text you wrote stays with you (/lvd export)
-- Message: "L1:<seq>:<line>;<line>;..." at most MAX_MSG characters, one every GAP seconds, at most PER_HOUR
-- an hour, never in a fight or a chat lockdown. Receivers: exact line shapes, number ranges, at most PER_SENDER
-- lines a sender and hour, a message seen through two ways counts once, at most MAX_KEYS facts kept.
-- /lvd share off stops sending (receiving stays: it costs nothing and helps the routes).
---------------------------------------------------------------------------
local PREFIX = "LvdNet"
local MAX_MSG, GAP, PER_HOUR, QUEUE = 240, 20, 40, 200
local MAX_KEYS, PER_SENDER, MAX_WHO = 4000, 80, 40
local KIND = { accept = "a", turnin = "t", ["do"] = "d", train = "r", learn = "l", buy = "b", sell = "v", fp = "f",
  bind = "i", travel = "w", grind = "g", farm = "m", skillup = "u", die = "x", hearth = "h", profs = "p",
  dungeon = "n", use = "e" }
local REASON = { giver = "g", route = "r", note = "n" }

local S = { queue = {}, seq = 0, sentAt = -1e9, hourAt = 0, hourN = 0, senders = {}, seen = {}, stats = { sent = 0, got = 0, bad = 0 } }
ns.LvdShare = S

local function DB() LeveldonDB = LeveldonDB or {} return LeveldonDB end
local function On() return DB().shareOff ~= true end
local function Now() return GetTime and GetTime() or 0 end
local function Level() return (UnitLevel and tonumber(UnitLevel("player"))) or 0 end
local function Route()
  local key = ns.LeveldonRouteKey and ns.LeveldonRouteKey()
  return tostring(key or ""):match("^([%a_]+):([%a_]+)")
end
local function Queue(line)
  local q = S.queue
  q[#q + 1] = line
  while #q > QUEUE do table.remove(q, 1) end
end

-- a step left (Recorder.lua StepWatch): how "d" done, "s" skipped by hand, "b" back (not shared)
function ns.ShareStep(s, how, secs)
  if not On() or type(s) ~= "table" or how == "b" then return end
  local race, cls = Route()
  local k = KIND[s.k]
  if not (race and k) then return end
  secs = math.max(0, math.min(7200, math.floor((tonumber(secs) or 0) + 0.5)))
  Queue(("G %s %s %d %s %d %s %d %d"):format(race, cls, tonumber(s._i) or 0, k, tonumber(s.q) or 0,
    how == "s" and "s" or "d", secs, Level()))
end
-- a report (Report.lua): the reason only, the text stays here
function ns.ShareReport(ri, k, q, reason)
  if not On() then return end
  local race, cls = Route()
  local r = REASON[reason]
  if not (race and r) then return end
  Queue(("R %s %s %d %s %d %s %d"):format(race, cls, tonumber(ri) or 0, KIND[k] or "o", tonumber(q) or 0, r, Level()))
end

---------------------------------------------------------------------------
-- sending
---------------------------------------------------------------------------
local function Register()
  if S.registered then return true end
  if not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) then return false end
  local ok, res = pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
  S.registered = ok and (res == nil or res == true or res == 0 or res == 1) or false
  return S.registered
end
local function Channels()
  local out = {}
  if IsInGuild and IsInGuild() then out[#out + 1] = { "GUILD" } end
  if IsInRaid and IsInRaid() then out[#out + 1] = { "RAID" }
  elseif IsInGroup and IsInGroup() then out[#out + 1] = { "PARTY" } end
  local api = rawget(_G, "QuestdonAPI")
  local id = api and api.ShareChannelID and api.ShareChannelID()
  if type(id) == "number" and id > 0 then out[#out + 1] = { "CHANNEL", id } end
  return out
end
function S.Flush()
  if not On() or #S.queue == 0 or not Register() then return false end
  local now = Now()
  if now - S.sentAt < GAP then return false end
  if now - S.hourAt >= 3600 then S.hourAt, S.hourN = now, 0 end
  if S.hourN >= PER_HOUR then return false end
  if UnitAffectingCombat and UnitAffectingCombat("player") then return false end
  if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
    local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
    if ok and locked then return false end
  end
  local chans = Channels()
  if #chans == 0 then return false end
  S.seq = (S.seq % 9999) + 1
  local head = ("L1:%d:"):format(S.seq)
  local body, n = {}, 0
  local len = #head
  while S.queue[1] and len + #S.queue[1] + 1 <= MAX_MSG do
    local line = table.remove(S.queue, 1)
    body[#body + 1] = line
    len = len + #line + 1
    n = n + 1
  end
  if n == 0 then table.remove(S.queue, 1) return false end -- a line too long: drop it
  local msg = head .. table.concat(body, ";")
  local any = false
  for _, ch in ipairs(chans) do
    local ok = pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, ch[1], ch[2])
    if ok then any = true end
  end
  S.sentAt, S.hourN = now, S.hourN + 1
  if any then S.stats.sent = S.stats.sent + n end
  return any
end

---------------------------------------------------------------------------
-- receiving
---------------------------------------------------------------------------
local function Checksum(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 16777216 end
  return h
end
local function Me()
  if not UnitFullName then return nil end
  local name, realm = UnitFullName("player") -- (both: "a and f()" would keep only the first)
  return name and (name .. "-" .. (realm or "")) or nil
end
local function Keys(net) local n = 0 for _ in pairs(net) do n = n + 1 end return n end
local function Add(line, who)
  local net = DB().net or {}
  DB().net = net
  local key, secs
  local race, cls, ri, k, q, how, sec, lv = line:match("^G ([%a_]+) ([%a_]+) (%d+) (%l) (%d+) ([ds]) (%d+) (%d+)$")
  if race then
    sec, lv = tonumber(sec), tonumber(lv)
    if #race > 12 or #cls > 12 or tonumber(ri) > 20000 or tonumber(q) > 999999 or sec > 7200 or lv < 1 or lv > 70 then return false end
    key, secs = ("G %s %s %s %s %s %s"):format(race, cls, ri, k, q, how), sec
  else
    local r2, c2, ri2, k2, q2, why, lv2 = line:match("^R ([%a_]+) ([%a_]+) (%d+) (%l) (%d+) ([grn]) (%d+)$")
    if not r2 or #r2 > 12 or #c2 > 12 or tonumber(ri2) > 20000 or tonumber(q2) > 999999 or tonumber(lv2) > 70 then return false end
    key, lv = ("R %s %s %s %s %s %s"):format(r2, c2, ri2, k2, q2, why), tonumber(lv2)
  end
  local e = net[key]
  if not e then
    if Keys(net) >= MAX_KEYS then return false end
    e = { n = 0, s = 0, lv = 0, w = {} }
    net[key] = e
  end
  e.n, e.s, e.lv = e.n + 1, e.s + (secs or 0), e.lv + (lv or 0)
  local wc = 0
  for _ in pairs(e.w) do wc = wc + 1 end
  if not e.w[who] and wc < MAX_WHO then e.w[who] = true end
  return true
end
function S.OnMessage(prefix, msg, channel, sender)
  if prefix ~= PREFIX or type(msg) ~= "string" or type(sender) ~= "string" then return end
  if channel ~= "GUILD" and channel ~= "PARTY" and channel ~= "RAID" and channel ~= "CHANNEL" then return end
  local me = Me()
  local full = sender:find("-", 1, true) and sender or (sender .. "-" .. ((me or ""):match("%-(.*)$") or ""))
  if full == me then return end
  local seq, body = msg:match("^L1:(%d+):(.+)$")
  if not seq then S.stats.bad = S.stats.bad + 1 return end
  local who = Checksum(full)
  local now = Now()
  -- the same message through guild and channel counts once
  local seen = S.seen[who] or {}
  S.seen[who] = seen
  if seen[seq] and now - seen[seq] < 600 then return end
  seen[seq] = now
  local snd = S.senders[who]
  if not snd or now - snd.at >= 3600 then snd = { at = now, n = 0 } S.senders[who] = snd end
  for line in body:gmatch("[^;]+") do
    if snd.n >= PER_SENDER then break end
    if Add(line, who) then snd.n = snd.n + 1 S.stats.got = S.stats.got + 1 else S.stats.bad = S.stats.bad + 1 end
  end
end

-- what came in, for /lvd export: "N <key> <reports> <players> <mean secs> <mean level>"
function ns.ShareExportLines()
  local out, keys = {}, {}
  for k in pairs(DB().net or {}) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local e = DB().net[k]
    local w = 0
    for _ in pairs(e.w or {}) do w = w + 1 end
    out[#out + 1] = ("N %s %d %d %d %d"):format(k, e.n, w, math.floor(e.s / math.max(1, e.n) + 0.5), math.floor(e.lv / math.max(1, e.n) + 0.5))
  end
  return out
end

function ns.ShareCommand(arg)
  if arg == "off" then DB().shareOff = true elseif arg == "on" then DB().shareOff = nil end
  local n = 0
  for _ in pairs(DB().net or {}) do n = n + 1 end
  print((L["|cff3fa9f5Level|rdon: sharing %s (sent %d, received %d facts, %d kept). /lvd share on|off"]):format(
    On() and L["on"] or L["off"], S.stats.sent, S.stats.got, n))
end

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(_, e, ...)
  if e == "CHAT_MSG_ADDON" then pcall(S.OnMessage, ...)
  elseif e == "PLAYER_LOGIN" then
    Register()
    if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(5, function() pcall(S.Flush) end) end
  end
end)
for _, e in ipairs({ "CHAT_MSG_ADDON", "PLAYER_LOGIN" }) do pcall(f.RegisterEvent, f, e) end
