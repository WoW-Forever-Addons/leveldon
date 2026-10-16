local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- (0.1.7, Daniel 11.10.: "can the addon write along while I play, walking ways, turn-ins, accepts,
-- buys, everything, to make better routes from it") The recorder.
--
-- While you play (option on by default, /lvd rec off), Leveldon writes down per session:
--   where you walk (a point every few seconds when you moved, not on a flight),
--   quests accepted, turned in (with XP and money) and abandoned, level ups, deaths,
--   flights, hearthstone, every NPC you talk to (once per session),
--   what you bought and sold at a vendor and what you learned at a trainer (with the cost),
--   the guide's step changes (done, skipped, back) and, per minute, XP from mobs,
--   kills by mob and time in combat.
-- Plus the reports (Report.lua): "quest giver not there", "route makes no sense", a remark.
-- Everything stays in LeveldonDB.rec (SavedVariables), only numbers, IDs and map points;
-- the reports keep your text. Old sessions go first when it gets too big.
-- Event lines: "<seconds since session start> <kind> <values ...>", see EVENT KINDS below.
---------------------------------------------------------------------------
local MAX_SESSIONS = 40
local MAX_EVENTS = 60000   -- all sessions together
local MAX_POINTS = 120000  -- walking points, all sessions together
local SAMPLE = 3           -- seconds between walking points
local MOVED = 0.08         -- map percent: less is standing still
local BUCKET = 60          -- seconds per XP/kill/combat line

-- EVENT KINDS
--   A q m x y level step       quest accepted          T q m x y level xp copper step   turned in
--   X q                        abandoned               L level                          level up
--   D m x y                    died                    U m x y                          alive again
--   F m x y / f m x y          flight start / landing  H m x y                          hearthstone cast
--   N npc m x y                talked to an NPC        B item count copper npc          bought
--   S copper npc               sold (money in)         R spell                          learned a spell
--   W npc copper secs          trainer visit           G i ri k q how                   guide step (how: d s b f)
--   K xp kills combat n:c,...  per minute              Q reason step q                  a report (text in reports)
--   I m x y / O m x y          went inside (cave, mine, building) / outside again: the way in
-- (Daniel 11.10.: "1 to 7 except 3")
--   J q i have need m x y      an objective's counter went up (where and when)
--   Z kind secs m x y          a pause ended: eat (food or drink), afk, idle (standing, no fight, no NPC)
--   Y n                        group size changed (0 = alone)
--   C q at                     (13.10.) a class quest chain moved to step at (hunter at level 10)
--   C 0 from to                (13.10.) the route followed you: from step "from" on to "to" (G how "f")
--   P q level how              (13.10.) an accept above your level: m moved behind the next stop there, s left
--                              out, w it was the step anyway (Leveldon moved on)
--   M copper free              every 5 minutes: money and free bag slots; V 0 / V n: bags full / free again
--   E inst type mapID / e inst secs   into an instance / out again (the quests in between were done there)
--   D m x y npc                died (npc: your target then); U m x y: alive again (the time between
--                              is the way back); L level rested: level up with the rested XP left
-- Walking points: "<seconds> <map> <x> <y>" and " i" when inside (Daniel 11.10.: the arrow through a
-- mine's wall: the ways in and the tunnels people walked, for Questdon's arrow)
local rec, sess, t0
local function Now() return GetTime and GetTime() or 0 end
local function Clock() return time and time() or 0 end
local function Num(v) return type(v) == "number" and v == v and v or nil end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d = pcall(fn, ...)
  if ok then return a, b, c, d end
end
local function Usable(v)
  if v == nil then return false end
  local ok = pcall(function() return v == v end)
  return ok
end

local function On() return LeveldonDB and LeveldonDB.recOff ~= true end

local function Pos()
  local m = C_Map and Call(C_Map.GetBestMapForUnit, "player")
  if not Num(m) then return nil end
  local p = Call(C_Map.GetPlayerMapPosition, m, "player")
  if not (p and p.GetXY) then return nil end
  local ok, x, y = pcall(p.GetXY, p)
  if not (ok and Num(x) and Num(y)) or (x == 0 and y == 0) then return nil end
  return m, x * 100, y * 100
end
local function PosText()
  local m, x, y = Pos()
  if not m then return "0 0 0" end
  return ("%d %.2f %.2f"):format(m, x, y)
end
local function NpcID(unit)
  local g = Call(UnitGUID, unit or "npc")
  if type(g) ~= "string" or not Usable(g) then return 0 end
  local kind, _, _, _, _, id = strsplit("-", g)
  if kind == "Creature" or kind == "Vehicle" then return tonumber(id) or 0 end
  return 0
end
local function Money() return Num(Call(GetMoney)) or 0 end
local function Level() return Num(Call(UnitLevel, "player")) or 0 end

local counts = { events = 0, points = 0 }
local function Recount()
  counts.events, counts.points = 0, 0
  for _, s in ipairs(rec.sessions) do counts.events = counts.events + #s.e counts.points = counts.points + #s.p end
end
local function Trim()
  while #rec.sessions > 1 and (#rec.sessions > MAX_SESSIONS or counts.events > MAX_EVENTS or counts.points > MAX_POINTS) do
    local old = table.remove(rec.sessions, 1)
    counts.events, counts.points = counts.events - #old.e, counts.points - #old.p
  end
end

local function Ev(kind, ...)
  if not (sess and On()) then return end
  local parts = { tostring(math.floor(Now() - t0 + 0.5)), kind }
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
  sess.e[#sess.e + 1] = table.concat(parts, " ")
  counts.events = counts.events + 1
  if counts.events > MAX_EVENTS then Trim() end
end
ns.RecEvent = Ev

local function Start()
  LeveldonDB = LeveldonDB or {}
  LeveldonDB.rec = type(LeveldonDB.rec) == "table" and LeveldonDB.rec or {}
  rec = LeveldonDB.rec
  rec.v = 1
  rec.sessions = type(rec.sessions) == "table" and rec.sessions or {}
  local name, realm = Call(UnitFullName, "player")
  local _, race = Call(UnitRace, "player")
  local _, cls = Call(UnitClass, "player")
  t0 = Now()
  sess = { c = (name or "?") .. "-" .. (realm or ""), r = race, cl = cls, s = Clock(), lv = Level(),
    xp = Num(Call(UnitXP, "player")), route = ns.LeveldonRouteKey and ns.LeveldonRouteKey() or nil,
    rid = ns.LeveldonRouteId and ns.LeveldonRouteId() or nil, -- (13.10.) the exact route bands played
    ver = ns.LeveldonVersion, m = Money(), rest = Num(Call(GetXPExhaustion)) or 0, e = {}, p = {} }
  rec.sessions[#rec.sessions + 1] = sess
  Recount()
  Trim()
end
ns.RecSession = function() return sess end -- (tests)

---------------------------------------------------------------------------
-- walking points
---------------------------------------------------------------------------
local last -- { m, x, y }
local onTaxi = false
local function Walk()
  if not (sess and On()) then return end
  local taxi = Call(UnitOnTaxi, "player") and true or false
  if taxi ~= onTaxi then
    onTaxi = taxi
    Ev(taxi and "F" or "f", PosText())
    last = nil
  end
  if taxi then return end
  local m, x, y = Pos()
  if not m then return end
  if last and last[1] == m and math.abs(last[2] - x) < MOVED and math.abs(last[3] - y) < MOVED then return end
  last = { m, x, y }
  sess.p[#sess.p + 1] = ("%d %d %.2f %.2f%s"):format(math.floor(Now() - t0 + 0.5), m, x, y, Call(IsIndoors) and " i" or "")
  counts.points = counts.points + 1
  if counts.points > MAX_POINTS then Trim() end
end
ns.RecWalk = Walk -- (tests)

-- inside or outside, checked often: where the change happens is the way in (two seconds of running are
-- 14 yards, so every half second)
local wasInside
local function InsideWatch()
  if not (sess and On()) or onTaxi then return end
  local inside = Call(IsIndoors) and true or false
  if wasInside ~= nil and inside ~= wasInside then
    local m, x, y = Pos()
    if m then
      Ev(inside and "I" or "O", ("%d %.2f %.2f"):format(m, x, y))
      -- a walking point right at the door, so the tunnel starts there
      sess.p[#sess.p + 1] = ("%d %d %.2f %.2f%s"):format(math.floor(Now() - t0 + 0.5), m, x, y, inside and " i" or "")
      counts.points = counts.points + 1
      last = { m, x, y }
    end
  end
  wasInside = inside
end
ns.RecInsideWatch = InsideWatch -- (tests)

---------------------------------------------------------------------------
-- per minute: XP from mobs, kills by mob, time in combat
---------------------------------------------------------------------------
local bucket = { xp = 0, kills = {}, n = 0, combat = 0, since = nil }
local lastXP, lastMax, lastLevel
local questXP, questAt = 0, -1e9
local recentGain, recentAt = 0, -1e9 -- the last XP counted as mob XP (a turn-in's XP may come first)
local function Flush()
  if bucket.since then bucket.combat = bucket.combat + (Now() - bucket.since) bucket.since = Now() end
  if bucket.xp == 0 and bucket.n == 0 and bucket.combat < 1 then return end
  local ks = {}
  for id, c in pairs(bucket.kills) do ks[#ks + 1] = id .. ":" .. c end
  table.sort(ks)
  Ev("K", bucket.xp, bucket.n, math.floor(bucket.combat + 0.5), #ks > 0 and table.concat(ks, ",") or "-")
  bucket.xp, bucket.kills, bucket.n, bucket.combat = 0, {}, 0, 0
end
ns.RecFlush = Flush -- (tests)
-- (11.10., Daniel's screenshot: "Leveldon was blocked, the function is reserved for the Blizzard UI")
-- The combat log is closed to addons in Forever: no COMBAT_LOG_EVENT_UNFILTERED. A kill is the dead target
-- when mob XP comes in; the mob that killed you is your target when you die.
local function TargetCreature()
  local g = Call(UnitGUID, "target")
  if type(g) ~= "string" or not Usable(g) then return 0 end
  local kind, _, _, _, _, id = strsplit("-", g)
  return kind == "Creature" and (tonumber(id) or 0) or 0
end
local lastKill -- { id } the last kill noted (a turn-in's XP that came first takes it back)
local function NoteKill()
  bucket.n = bucket.n + 1
  local id = Call(UnitIsDead, "target") and TargetCreature() or 0
  if id > 0 then bucket.kills[id] = (bucket.kills[id] or 0) + 1 end
  lastKill = { id = id }
end
local function TakeBackKill()
  if not lastKill then return end
  bucket.n = math.max(0, bucket.n - 1)
  local id = lastKill.id
  if id > 0 and bucket.kills[id] then
    bucket.kills[id] = bucket.kills[id] - 1
    if bucket.kills[id] <= 0 then bucket.kills[id] = nil end
  end
  lastKill = nil
end

local function XPChanged()
  local xp, max, lv = Num(Call(UnitXP, "player")), Num(Call(UnitXPMax, "player")), Level()
  if not xp then return end
  if lastXP then
    local gain = (lv > (lastLevel or lv)) and ((lastMax or 0) - lastXP + xp) or (xp - lastXP)
    if gain > 0 then
      -- a turn-in just now: its XP is in the T line
      if Now() - questAt < 2 and questXP > 0 then
        local q = math.min(gain, questXP)
        questXP = questXP - q
        gain = gain - q
      end
      bucket.xp = bucket.xp + gain
      recentGain, recentAt = gain, Now()
      if gain > 0 then NoteKill() end
    end
  end
  lastXP, lastMax, lastLevel = xp, max, lv
end

---------------------------------------------------------------------------
-- vendors and trainers: what changed in the bags and the purse
---------------------------------------------------------------------------
local function Bags()
  local have = {}
  for bag = 0, 4 do
    local n = C_Container and Call(C_Container.GetContainerNumSlots, bag) or Call(GetContainerNumSlots, bag)
    for slot = 1, Num(n) or 0 do
      local id, count
      if C_Container and C_Container.GetContainerItemInfo then
        local info = Call(C_Container.GetContainerItemInfo, bag, slot)
        if type(info) == "table" then id, count = info.itemID, info.stackCount end
      else
        local _, c, _, _, _, _, _, _, _, iid = Call(GetContainerItemInfo, bag, slot)
        id, count = iid, c
      end
      if Num(id) then have[id] = (have[id] or 0) + (Num(count) or 1) end
    end
  end
  return have
end
local shop, school -- { npc, money, bags, t }
local function ShopOpen() shop = { npc = NpcID("npc"), money = Money(), bags = Bags(), t = Now() } end
local function ShopClosed()
  if not shop then return end
  local now, spent = Bags(), shop.money - Money()
  local bought = {}
  for id, c in pairs(now) do
    local d = c - (shop.bags[id] or 0)
    if d > 0 then bought[#bought + 1] = { id, d } end
  end
  table.sort(bought, function(a, b) return a[1] < b[1] end)
  if #bought > 0 then
    -- the money goes to the first line (one visit, one sum)
    for i, b in ipairs(bought) do Ev("B", b[1], b[2], i == 1 and math.max(0, spent) or 0, shop.npc) end
  elseif spent < 0 then
    Ev("S", -spent, shop.npc)
  end
  shop = nil
end
local function SchoolOpen()
  local trade = Call(IsTradeskillTrainer) and true or false
  school = { npc = NpcID("npc"), money = Money(), t = Now(), trade = trade }
end
local function SchoolClosed()
  if not school then return end
  Ev("W", school.npc, math.max(0, school.money - Money()), math.floor(Now() - school.t + 0.5), school.trade and 1 or 0)
  school = nil
end

---------------------------------------------------------------------------
-- the guide's steps
---------------------------------------------------------------------------
local lastStep, lastObj, lastAt
local function StepWatch()
  if not ns.LeveldonCur then return end
  local i = ns.LeveldonCur()
  local steps = ns.LeveldonSteps and ns.LeveldonSteps() or {}
  local s = steps[i]
  -- (15.10., review round 3) a stop put in at the same number is a new step too (a vendor stop, a pulled class quest)
  if i == lastStep and s == lastObj then return end
  local how = ns._recHow or "d"
  ns._recHow = nil
  if lastStep ~= nil then Ev("G", i, s and s._i or 0, s and s.k or "end", s and s.q or 0, how) end
  -- (0.2.0) the step just left, for the other Leveldon players (Share.lua)
  -- (15.10., review round 3) not when it was only pushed on by a stop put in before it (still ahead, not done)
  local pushed = false
  if lastObj then
    for j = i, #steps do
      if steps[j] == lastObj then pushed = not (ns.LeveldonStepDone and ns.LeveldonStepDone(j)) break end
    end
  end
  if lastObj and ns.ShareStep and not pushed then pcall(ns.ShareStep, lastObj, how, Now() - (lastAt or Now())) end
  lastStep, lastObj, lastAt = i, s, Now()
end
ns.RecStepWatch = StepWatch -- (tests)

---------------------------------------------------------------------------
-- events
---------------------------------------------------------------------------
local talked = {}
local lastTalk = -1e9 -- an NPC dialog keeps a pause from counting as idle
local function Talked()
  lastTalk = Now()
  local id = NpcID("npc")
  if id > 0 and not talked[id] then talked[id] = true Ev("N", id, PosText()) end
end
local turnedAt = {}
local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(_, e, ...)
  if e == "PLAYER_LOGIN" then
    Start()
    lastXP, lastMax, lastLevel = Num(Call(UnitXP, "player")), Num(Call(UnitXPMax, "player")), Level()
    if C_Timer and C_Timer.NewTicker then
      C_Timer.NewTicker(SAMPLE, function() pcall(Walk) end)
      C_Timer.NewTicker(BUCKET, function() pcall(Flush) end)
      C_Timer.NewTicker(1, function() pcall(StepWatch) end)
      C_Timer.NewTicker(0.5, function() pcall(InsideWatch) end)
    end
    return
  end
  if not (sess and On()) then return end
  if e == "QUEST_ACCEPTED" then
    local a, b = ...
    local q = Num(b) or Num(a) -- (the old clients send the log index first)
    if q and q > 0 then Ev("A", q, PosText(), Level(), ns.LeveldonCur and ns.LeveldonCur() or 0) end
  elseif e == "QUEST_TURNED_IN" then
    local q, xp, copper = ...
    q, xp, copper = Num(q) or 0, Num(xp) or 0, Num(copper) or 0
    -- its XP already came and was counted as mob XP: take it back
    if Now() - recentAt < 2 and recentGain > 0 and xp > 0 then
      local back = math.min(recentGain, xp, bucket.xp)
      if back >= recentGain then TakeBackKill() end -- that XP was the turn-in's, not a kill
      bucket.xp, recentGain = bucket.xp - back, recentGain - back
      questXP, questAt = questXP + xp - back, Now()
    else
      questXP, questAt = questXP + xp, Now()
    end
    turnedAt[q] = Now()
    Ev("T", q, PosText(), Level(), xp, copper, ns.LeveldonCur and ns.LeveldonCur() or 0)
  elseif e == "QUEST_REMOVED" then
    local q = Num((...))
    if q and not (turnedAt[q] and Now() - turnedAt[q] < 5) then
      -- turned in a moment later (the events come in either order)
      local at = Now()
      if C_Timer and C_Timer.After then
        C_Timer.After(2, function() if not (turnedAt[q] and turnedAt[q] >= at - 5) then Ev("X", q) end end)
      else
        Ev("X", q)
      end
    end
  elseif e == "PLAYER_LEVEL_UP" then
    Flush()
    Ev("L", Num((...)) or Level(), Num(Call(GetXPExhaustion)) or 0)
    -- (12.10., Daniel's run to Goldshire: "level 5 -> 3" at logout) the level reached, from the event itself
    if sess then sess.lv2 = math.max(sess.lv2 or 0, Num((...)) or Level()) end
  elseif e == "PLAYER_XP_UPDATE" then
    XPChanged()
  elseif e == "PLAYER_DEAD" then
    Ev("D", PosText(), TargetCreature())
  elseif e == "PLAYER_UNGHOST" or e == "PLAYER_ALIVE" then
    if not Call(UnitIsDeadOrGhost, "player") then Ev("U", PosText()) end
  elseif e == "PLAYER_REGEN_DISABLED" then
    bucket.since = Now()
  elseif e == "PLAYER_REGEN_ENABLED" then
    if bucket.since then bucket.combat = bucket.combat + (Now() - bucket.since) bucket.since = nil end
  elseif e == "MERCHANT_SHOW" then
    Talked() ShopOpen()
  elseif e == "MERCHANT_CLOSED" then
    ShopClosed()
  elseif e == "TRAINER_SHOW" then
    Talked() SchoolOpen()
  elseif e == "TRAINER_CLOSED" then
    SchoolClosed()
  elseif e == "LEARNED_SPELL_IN_TAB" then
    local id = Num((...))
    if id then Ev("R", id) end
  elseif e == "GOSSIP_SHOW" or e == "QUEST_DETAIL" or e == "QUEST_PROGRESS" or e == "QUEST_COMPLETE"
      or e == "QUEST_GREETING" or e == "TAXIMAP_OPENED" then
    Talked()
  elseif e == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, _, spell = ...
    if unit == "player" and spell == 8690 then Ev("H", PosText()) end
  elseif e == "PLAYER_LOGOUT" then
    Flush()
    sess.endAt = Clock()
    sess.lv2 = math.max(sess.lv2 or 0, Level())
  end
end)
for _, e in ipairs({ "PLAYER_LOGIN", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "PLAYER_LEVEL_UP",
  "PLAYER_XP_UPDATE", "PLAYER_DEAD", "PLAYER_UNGHOST", "PLAYER_ALIVE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
  "MERCHANT_SHOW", "MERCHANT_CLOSED", "TRAINER_SHOW", "TRAINER_CLOSED",
  "LEARNED_SPELL_IN_TAB", "GOSSIP_SHOW", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING",
  "TAXIMAP_OPENED", "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_LOGOUT" }) do
  pcall(f.RegisterEvent, f, e)
end

---------------------------------------------------------------------------
-- (Daniel 11.10.: "1 to 7 except 3") objectives with time, pauses, group and rested XP, money and bag
-- space, deaths with the way back, dungeons
---------------------------------------------------------------------------
local more = { objs = nil, pause = nil, still = nil, group = nil, inst = nil, full = false, moneyAt = 0 }

-- objective counters: J when one went up (the first look only notes them)
local function ObjectiveWatch()
  if not (sess and On() and C_QuestLog and C_QuestLog.GetQuestObjectives) then return end
  local ids = {}
  local n = (C_QuestLog.GetNumQuestLogEntries and Call(C_QuestLog.GetNumQuestLogEntries)) or Call(GetNumQuestLogEntries) or 0
  for i = 1, Num(n) or 0 do
    local id
    if C_QuestLog.GetInfo then
      local info = Call(C_QuestLog.GetInfo, i)
      id = type(info) == "table" and not info.isHeader and info.questID or nil
    elseif GetQuestLogTitle then
      local _, _, _, header, _, _, _, qid = Call(GetQuestLogTitle, i)
      id = not header and qid or nil
    end
    if Num(id) and id > 0 then ids[#ids + 1] = id end
  end
  local now, first = {}, more.objs == nil
  for _, q in ipairs(ids) do
    local objs = Call(C_QuestLog.GetQuestObjectives, q)
    now[q] = {}
    for i, o in ipairs(type(objs) == "table" and objs or {}) do
      local have, need = Num(o.numFulfilled) or 0, Num(o.numRequired) or 0
      now[q][i] = have
      local before = not first and more.objs[q] and more.objs[q][i]
      if before and have > before then Ev("J", q, i, have, need, PosText()) end
    end
  end
  more.objs = now
end
ns.RecObjectiveWatch = ObjectiveWatch -- (tests)

local foodName, drinkName
local function Eating()
  local get = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
  foodName = foodName or Call(get, 433)
  drinkName = drinkName or Call(get, 430)
  for i = 1, 40 do
    local name
    if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
      local a = Call(C_UnitAuras.GetBuffDataByIndex, "player", i)
      name = type(a) == "table" and a.name or nil
    else
      name = Call(UnitBuff, "player", i)
    end
    if not name then break end
    if Usable(name) and (name == foodName or name == drinkName) then return true end
  end
  return false
end

local function FreeSlots()
  local free = 0
  for bag = 0, 4 do
    local n = C_Container and C_Container.GetContainerNumFreeSlots and Call(C_Container.GetContainerNumFreeSlots, bag)
      or Call(GetContainerNumFreeSlots, bag)
    free = free + (Num(n) or 0)
  end
  return free
end

ns.FreeSlots = FreeSlots -- (11.10. Fit.lua: bags full, a vendor stop)
local IDLE = 15 -- seconds standing still before it counts as a pause
local function Watch()
  if not (sess and On()) then return end
  local now = Now()
  -- pauses
  local kind
  if Call(UnitIsAFK, "player") then kind = "afk"
  elseif Eating() then kind = "eat" end
  local m, x, y = Pos()
  local moved = not more.still or not m or more.still[1] ~= m or math.abs(more.still[2] - x) > 0.03 or math.abs(more.still[3] - y) > 0.03
  if moved then more.still = m and { m, x, y, now } or nil end
  if not kind and more.still and not onTaxi and not bucket.since and now - lastTalk > 5 and now - more.still[4] >= IDLE then kind = "idle" end
  local p = more.pause
  if p and p.kind ~= kind then
    local secs = now - p.t
    if secs >= 10 then Ev("Z", p.kind, math.floor(secs + 0.5), p.pos) end
    more.pause = nil
  end
  if kind and not more.pause then
    more.pause = { kind = kind, t = kind == "idle" and more.still[4] or now, pos = PosText() }
  end
  -- group
  local g = Num(Call(GetNumGroupMembers)) or 0
  if g ~= more.group then
    if more.group ~= nil then Ev("Y", g) end
    more.group = g
  end
  -- instances
  local inside, itype = Call(IsInInstance)
  local isIn = (inside == true or inside == 1) and (itype == "party" or itype == "raid")
  if isIn and not more.inst then
    local ok, _, t, _, _, _, _, _, mapID = pcall(GetInstanceInfo or function() end)
    if not ok then t, mapID = nil, nil end
    more.inst = { id = Num(mapID) or 0, t = now }
    Ev("E", more.inst.id, t or itype or "-", Num(mapID) or 0)
  elseif not isIn and more.inst then
    Ev("e", more.inst.id, math.floor(now - more.inst.t + 0.5))
    more.inst = nil
  end
  -- money and bag space
  local free = FreeSlots()
  if free == 0 and not more.full then more.full = true Ev("V", 0)
  elseif free > 0 and more.full then more.full = false Ev("V", free) end
  if now - more.moneyAt >= 300 then
    more.moneyAt = now
    Ev("M", Money(), free)
  end
end
ns.RecWatch = Watch -- (tests)
ns.RecPause = function() return more.pause end -- (tests)

local f2 = CreateFrame("Frame")
local objPending = false
f2:SetScript("OnEvent", function(_, e)
  if e == "PLAYER_LOGIN" then
    if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(1, function() pcall(Watch) end) end
    if C_Timer and C_Timer.After then C_Timer.After(3, function() pcall(ObjectiveWatch) end) end
  elseif e == "QUEST_LOG_UPDATE" or e == "UNIT_QUEST_LOG_CHANGED" then
    if objPending then return end
    objPending = true
    if C_Timer and C_Timer.After then
      C_Timer.After(0.5, function() objPending = false pcall(ObjectiveWatch) end)
    else
      objPending = false pcall(ObjectiveWatch)
    end
  end
end)
for _, e in ipairs({ "PLAYER_LOGIN", "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED" }) do pcall(f2.RegisterEvent, f2, e) end

-- /lvd rec, /lvd rec on, /lvd rec off
function ns.RecCommand(arg)
  LeveldonDB = LeveldonDB or {}
  if arg == "off" then LeveldonDB.recOff = true
  elseif arg == "on" then LeveldonDB.recOff = nil end
  local n = rec and #rec.sessions or 0
  print((L["|cff3fa9f5Level|rdon: writing along %s. %d sessions, %d events, %d walking points, %d reports kept (/lvd rec on|off)."]):format(
    On() and L["on"] or L["off"], n, counts.events, counts.points, LeveldonDB.reports and #LeveldonDB.reports or 0))
end
