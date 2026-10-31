local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- (0.1.7, Daniel 11.10.: "what if Questdon does not accept automatically in such cases when Leveldon is
-- installed? Otherwise 2. makes sense, but the player has to accept them himself")
-- Leveldon's route takes only the quests worth the time. With Leveldon guiding (its window open):
--   * LeveldonAPI.WantsQuest(q): true for a quest of the route (its steps, its known chains, a quest fitted
--     in below), false for any other one; Questdon's auto accept leaves those to you (Quests.lua).
--   * You accept one yourself: Leveldon looks along the next steps of the route. Its objectives near a step
--     of the route (OBJ_NEAR) and its turn-in at a stop of the route (NPC_NEAR): it goes in there (a "do"
--     after that step, the turn-in at that stop). Else a chat line: not on your route, it costs extra time.
--   Plans: LeveldonCharDB.extraPlans[q] = { doAt, turnAt (route step numbers), n, d = {m,x,y}, t = {m,x,y} }.
--   Abandoned: the plan goes.
---------------------------------------------------------------------------
-- (11.10.) quests taken out of every route after a report: questID = why
-- (11.10.) what a quest needs that the game's quest log does not show (Daniel: Kyle; the quest's own text)
ns.QUEST_TIPS = {
  [99411] = L["First: Tender Strider Meat from the Plainstriders east of Bloodhoof, then put it down near Kyle (he runs around the village)"],
  -- (11.10., Daniel's Coldridge run) the troggs of A New Threat walk between the boars too
  [183] = L["Kill the Rockjaw Troggs here as well: they count for A New Threat"],
  [182] = L["Pick up Felix's crates on the way (A Refugee's Quandary): one by Talin's camp, one south of it, one at the cave"],
}
-- (11.10.) the objective to go for first, the others come along (Daniel: Rite of Vision (2/3): the Well Stones
-- at the well first, the Ambercorn lie on the way)
ns.LEAD_OBJECTIVE = { [771] = 1 }
ns.SKIP_QUESTS = {
  [1656] = L["A Task Unfinished (Mulgore): Antur Fallow stands up in the hills west of Camp Narache, the straight way runs into the mountains (Daniel 11.10.)"],
  -- (15.10., Daniel's mage Zip) not offered: Investigate the Scourge of Stormwind is a Scourge invasion quest
  -- (the giver never offered it, recorded), Research Access (mage) had nothing to take at the giver at level 9
  [9260] = L["Investigate the Scourge of Stormwind: a Scourge invasion quest, not offered"],
  [97286] = L["Research Access: not offered at the giver (Daniel's mage, level 9)"],
}
-- (15.10., Daniel's mage Zip: "Book Return is an elite quest, hard alone if nobody is there to help") group
-- quests (22.10., tools/open/build_group_quests.py: CMaNGOS classic-db, GPL v3, quest type 1, and Forever's
-- own ones Daniel's game showed): the route leaves them out; one you take yourself is marked
ns.GROUP_QUESTS = {}
for id in ("19 55 99 105 115 155 169 176 193 197 202 206 208 211 228 248 249 253 255 256 271 278 303 304 314 442 450 452 474 504 517 518 519 520 531 540 541 543 547 591 611 613 614 618 628 629 630 631 639 640 643 644 645 646 652 656 673 679 680 682 684 685 694 695 696 697 705 706 717 731 735 736 762 793 969 1051 1089 1100 1107 1150 1151 1166 1172 1173 1380 1381 1383 1424 1448 1488 1655 1701 1713 1955 2078 2203 2359 2478 2499 2501 2721 2935 2937 2944 2946 2954 2966 2967 2977 2993 2994 3062 3127 3181 3182 3201 3372 3385 3452 3463 3510 3514 3566 3602 3627 3628 3962 4021 4023 4146 4182 4787 4961 5054 5055 5056 5063 5065 5067 5068 5088 5098 5121 5124 5151 5153 5156 5162 5164 5166 5167 5168 5247 5264 5265 5342 5344 5461 5462 5464 5465 5803 5804 5862 5944 5981 6025 6041 6135 6136 6145 6146 6147 6148 6182 6183 6184 6185 6186 6283 6284 6481 6570 6621 6641 6983 7043 7582 7583 7603 7701 7816 7845 7846 7847 7849 7850 7861 7862 8283 8301 8302 8304 8306 8308 8309 8310 8314 8315 8331 8332 8341 8348 8349 8361 8362 8363 8481 8498 8501 8502 8507 8534 8535 8536 8537 8538 8539 8551 8552 8554 8606 8687 8731 8737 8738 8739 8740 8770 8771 8772 8773 8774 8775 8776 8777 8829 8928 8962 8963 8964 8965 8970 8985 8986 8987 8988 9051 9085 91775"):gmatch("%d+") do ns.GROUP_QUESTS[tonumber(id)] = true end

-- (11.10., Daniel: "Grace of An'she and Mu'sha failed") quests with a timer: their do and turn-in go right
-- behind the accept (Compose, ns.TimedOrder); seconds (from the quest texts; the game's own timer, when it
-- shows one at accept, adds a quest here for the session)
ns.TIMED_QUESTS = {
  [257] = 900, [258] = 720, [654] = 1800, [2969] = 360, [3364] = 300, [3843] = 3600, [6022] = 600,
  [95805] = 600, [97257] = 600,
}

local WINDOW = 150   -- steps ahead
local OBJ_NEAR = 250 -- yards from a step of the route to the quest's objectives
local NPC_NEAR = 80  -- yards from a stop of the route to the quest's turn-in

local function DB()
  LeveldonCharDB = LeveldonCharDB or {}
  return LeveldonCharDB
end
local function Say(msg) print("|cff3fa9f5Level|rdon: " .. msg) end

local function InRoute(q)
  for _, s in ipairs(ns.LeveldonSteps and ns.LeveldonSteps() or {}) do if s.q == q then return true end end
  local R = ns.LeveldonRoute and ns.LeveldonRoute()
  for root, chain in pairs(R and R.bonus or {}) do
    if root == q then return true end
    for _, st in ipairs(chain) do if st.q == q then return true end end
  end
  for _, d in ipairs(R and R.dungeons or {}) do
    for _, dq in ipairs(d.quests or {}) do if (type(dq) == "table" and dq.q or dq) == q then return true end end
  end
  return false
end

-- true: the route's quest; false: not the route's (Questdon leaves it to you); nil: Leveldon is not guiding
function ns.WantsQuest(q)
  q = tonumber(q)
  if not q then return nil end
  local steps = ns.LeveldonSteps and ns.LeveldonSteps()
  if not steps or #steps == 0 then return nil end
  local db = DB()
  if db.panel and db.panel.shown == false then return nil end -- window closed: not guiding
  if InRoute(q) then return true end
  if ns.IsClassQuest(q) then return true end -- (11.10.) class quests: always (the game offers only your class's)
  if db.extraPlans and db.extraPlans[q] then return true end
  return false
end
LeveldonAPI = LeveldonAPI or {}
LeveldonAPI.WantsQuest = function(q) return ns.WantsQuest(q) end

-- the route's own step number at or before j (inserted steps have none)
local function RouteIndex(steps, j)
  for k = j, 1, -1 do if steps[k] and steps[k]._i then return steps[k]._i end end
  return 1
end

-- (Daniel 11.10.: "Call of Earth" got "not on your route", but shamans need it for their totems) a class
-- quest of your class: always wanted; not in the route, it goes in at once (ClassQuestToDo below)
function ns.IsClassQuest(q)
  local a = ns.QD()
  local g = q and a and a.GetQuest and a.GetQuest(q)
  return type(g) == "table" and type(g.classes) == "table" and #g.classes > 0 or false
end

function ns.FitIn(q)
  q = tonumber(q)
  if not q then return nil end
  local classQ = ns.IsClassQuest(q) and not InRoute(q) and not (DB().extraPlans and DB().extraPlans[q])
  if ns.WantsQuest(q) ~= false and not classQ then return nil end
  local a = ns.QD()
  if not a then return nil end
  local steps, cur = ns.LeveldonSteps(), ns.LeveldonCur()
  local name = (a.QuestTitle and a.QuestTitle(q)) or (L["quest "] .. q)
  local last = math.min(#steps, cur + WINDOW)
  local objs = a.ObjectivePoints and a.ObjectivePoints(q) or {}
  local complete = a.IsQuestComplete and a.IsQuestComplete(q)
  local doAt, doPt
  if #objs > 0 and not complete then
    for j = cur, last do
      local s = steps[j]
      if s and s.m and s.x then
        for _, p in ipairs(objs) do
          local pt = { m = p.mapID, x = p.x * 100, y = p.y * 100 }
          if ns.Within(s, pt, OBJ_NEAR) then doAt, doPt = j, pt break end
        end
      end
      if doAt then break end
    end
  end
  local turnAt, turnPt
  local tm, tx, ty = nil, nil, nil
  if a.TurnInPoint then tm, tx, ty = a.TurnInPoint(q) end
  if tm and tx and ty and (doAt or #objs == 0 or complete) then
    local t = { m = tm, x = tx * 100, y = ty * 100 }
    for j = doAt or cur, last do
      local s = steps[j]
      if s and s.m and s.x and ns.Within(s, t, NPC_NEAR) then turnAt, turnPt = j, t break end
    end
  end
  if not turnAt and classQ then
    -- a class quest: right now, behind the current step (its objectives first, then the turn-in)
    local here = RouteIndex(steps, cur)
    if #objs > 0 and not complete and not doAt then
      local p = objs[1]
      doAt, doPt = cur, { m = p.mapID, x = p.x * 100, y = p.y * 100 }
    end
    turnAt = cur
    turnPt = tm and tx and ty and { m = tm, x = tx * 100, y = ty * 100 } or nil
    local db = DB()
    db.extraPlans = db.extraPlans or {}
    db.extraPlans[q] = { doAt = doAt and here or nil, turnAt = here, n = name, d = doPt and { doPt.m, doPt.x, doPt.y } or nil,
      t = turnPt and { turnPt.m, turnPt.x, turnPt.y } or nil, class = true }
    if ns.LeveldonRecompose then ns.LeveldonRecompose() end
    -- (15.10., review round 2) the route keeps its step by the step itself now: the class quest put in right here
    -- (before it) comes first
    local S, c = ns.LeveldonSteps and ns.LeveldonSteps(), ns.LeveldonCur and ns.LeveldonCur()
    if S and c then
      for j = math.max(1, c - 12), c - 1 do
        if S[j] and S[j].q == q and (S[j].k == "do" or S[j].k == "turnin") then
          ns.LeveldonCur(j)
          if ns.SaveStep then ns.SaveStep() end
          if ns.LeveldonRefresh then ns.LeveldonRefresh() end
          break
        end
      end
    end
    Say((L["\"%s\" is a class quest you need: Leveldon takes you there now."]):format(name))
    return true
  end
  if not turnAt then
    Say((L["\"%s\" is not on your route (its objectives or its turn-in are far from it). It costs extra time; abandon it for the fastest way."]):format(name))
    return false
  end
  local db = DB()
  db.extraPlans = db.extraPlans or {}
  db.extraPlans[q] = { doAt = doAt and RouteIndex(steps, doAt) or nil, turnAt = RouteIndex(steps, turnAt), n = name,
    d = doPt and { doPt.m, doPt.x, doPt.y } or nil, t = { turnPt.m, turnPt.x, turnPt.y } }
  if ns.LeveldonRecompose then ns.LeveldonRecompose() end
  Say((L["\"%s\" fits your route: done along the way, turned in at a stop you pass anyway."]):format(name)
    .. (ns.GROUP_QUESTS[q] and L[" It is a group quest (elite): hard alone, bring help."] or ""))
  return true
end

-- Compose (Leveldon.lua): a timed quest's do and turn-in steps right behind its accept, in their order
local TIMED_NEAR = 250
function ns.TimedOrder(out)
  for q in pairs(ns.TIMED_QUESTS) do
    local acc
    for j, st in ipairs(out) do if st.k == "accept" and st.q == q then acc = j break end end
    -- (11.10., Daniel's Coldridge run: Scalding Mornbrew, then the hearthstone home) the route took the hearthstone
    -- right after the accept: its order stays (the clock is no race then)
    if acc and out[acc + 1] and out[acc + 1].k == "hearth" then acc = nil end
    if acc then
      local moved, j = {}, acc + 1
      while j <= #out do
        local st = out[j]
        if st.q == q and (st.k == "do" or st.k == "turnin") then
          moved[#moved + 1] = table.remove(out, j)
        else
          j = j + 1
        end
      end
      -- (11.10., Daniel: "first finish the pumas, or kill them on the way to the turn-in") with 10 minutes or
      -- more on the clock up to two kill steps right next to the quest giver (TIMED_NEAR yards) stay first
      local at = acc
      if (ns.TIMED_QUESTS[q] or 0) >= 600 and ns.Within then
        local n = 0
        while out[at + 1] and out[at + 1].k == "do" and out[at + 1].q ~= q and n < 2
            and ns.Within(out[at + 1], out[acc], TIMED_NEAR) do
          at, n = at + 1, n + 1
        end
      end
      for k, st in ipairs(moved) do table.insert(out, at + k, st) end
    end
  end
end

-- Seconds left on a quest's timer, or nil (C_QuestLog.GetTimeAllowed: total, elapsed)
function ns.TimeLeft(q)
  if not (C_QuestLog and C_QuestLog.GetTimeAllowed) then return nil end
  local ok, total, elapsed = pcall(C_QuestLog.GetTimeAllowed, q)
  if ok and type(total) == "number" and type(elapsed) == "number" and total > 0 then return math.max(0, total - elapsed) end
  return nil
end
-- (17.10., Daniel's gnome warlock Dorandy: "I got a timed quest and you send me killing Frostmanes") a quest's clock
-- runs: nothing is pulled in front of its steps (FinishNearbyFirst put The Troll Cave before Scalding Mornbrew's
-- turn-in, the trolls were 100 yards off)
function ns.TimedRunning()
  for q in pairs(ns.TIMED_QUESTS) do
    local left = ns.TimeLeft(q)
    if left and left > 0 and not ns.QuestFailed(q) then return q end
  end
  return nil
end
function ns.QuestFailed(q)
  if not (C_QuestLog and C_QuestLog.IsFailed) then return false end
  local ok, v = pcall(C_QuestLog.IsFailed, q)
  return ok and v == true
end

-- Compose (Leveldon.lua): the plans into the steps, behind their route steps
function ns.ApplyExtraPlans(out)
  local db = LeveldonCharDB
  if not (db and db.extraPlans) then return end
  local a = ns.QD()
  for q, p in pairs(db.extraPlans) do
    if a and a.IsQuestDone and a.IsQuestDone(q) then
      db.extraPlans[q] = nil
    else
      local function After(i)
        for j, s in ipairs(out) do if s._i == i then return j end end
      end
      local at = p.doAt and After(p.doAt)
      if p.d and at then
        table.insert(out, at + 1, { k = "do", q = q, n = p.n, m = p.d[1], x = p.d[2], y = p.d[3], _extra = true, grp = ns.GROUP_QUESTS[q] })
      end
      local tat = After(p.turnAt)
      if tat and at and tat <= at then tat = at + 1 end
      if tat and p.t then
        local e = ns.HubEnd and ns.HubEnd(out, tat) or tat
        table.insert(out, e + 1, { k = "turnin", q = q, n = p.n, m = p.t[1], x = p.t[2], y = p.t[3], _extra = true })
      end
    end
  end
end

local turned = {}
local f = ns.CreateFrame("Frame")
f:SetScript("OnEvent", function(_, e, a1, a2)
  if e == "QUEST_ACCEPTED" then
    local q = tonumber(a2) or tonumber(a1) -- (the old clients send the log index first)
    if q and C_Timer and C_Timer.After then
      ns.After(1, function()
        pcall(ns.FitIn, q) -- Questdon knows its places a moment later
        -- a timer the list did not know: timed from now on (this session), the steps again
        if not ns.TIMED_QUESTS[q] and ns.TimeLeft(q) then
          ns.TIMED_QUESTS[q] = ns.TimeLeft(q)
          if ns.LeveldonRecompose then ns.LeveldonRecompose() end
        end
      end)
    elseif q then
      pcall(ns.FitIn, q)
    end
  elseif e == "QUEST_TURNED_IN" then
    turned[tonumber(a1) or 0] = true
  elseif e == "QUEST_REMOVED" then
    local q = tonumber(a1)
    local db = LeveldonCharDB
    if q and db and db.extraPlans and db.extraPlans[q] then
      local function Drop()
        if turned[q] or not (db.extraPlans and db.extraPlans[q]) then return end
        db.extraPlans[q] = nil
        if ns.LeveldonRecompose then ns.LeveldonRecompose() end
      end
      if C_Timer and C_Timer.After then ns.After(2, Drop) else Drop() end
    end
  end
end)
for _, e in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED" }) do pcall(f.RegisterEvent, f, e) end

-- (11.10.) class quests already in the log at login (taken before this version, or told "not on your
-- route"): they go in as well
local function LogClassQuests()
  if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return end
  for i = 1, C_QuestLog.GetNumQuestLogEntries() or 0 do
    local info = C_QuestLog.GetInfo and C_QuestLog.GetInfo(i)
    local q = type(info) == "table" and not info.isHeader and info.questID or nil
    if q and ns.IsClassQuest(q) then pcall(ns.FitIn, q) end
  end
end
ns.LogClassQuests = LogClassQuests -- (tests)
local g = ns.CreateFrame("Frame")
g:SetScript("OnEvent", function() if C_Timer and C_Timer.After then ns.After(5, function() pcall(LogClassQuests) end) end end)
pcall(g.RegisterEvent, g, "PLAYER_LOGIN")

---------------------------------------------------------------------------
-- (11.10., Daniel: "when the bags are full and I am in a hub, the way to a vendor"; "not even a silver to learn
-- Cooking") a vendor stop goes in before the current step: bags full (at most one slot free), or the money short
-- for a profession still to learn in this chapter; a vendor of the route's list within SELL_NEAR yards on this
-- map, not in a fight, at most every SELL_EVERY seconds. Done when a vendor window opened (or 4 slots free).
---------------------------------------------------------------------------
local SELL_NEAR, SELL_EVERY, GREY_WORTH = 220, 300, 25
-- (22.10., Daniel: "no vendor visits while you are on the way") the walk to the step may get this long through the vendor;
-- with no place to walk to (a flight, a boat, the hearthstone) only a vendor you stand at; at a hub (an NPC step this close)
-- the hub's vendor as before
local ON_WAY, ON_WAY_NO_PLACE, HUB_WALK = 80, 60, 200
local HUB_STEP = { accept = true, turnin = true, train = true, learn = true, buy = true, bind = true, fp = true, sell = true }
-- copper the grey items in the bags sell for
function ns.GreyValue()
  local C = C_Container
  if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return 0 end
  local sum = 0
  for bag = 0, 4 do
    for slot = 1, (C.GetContainerNumSlots(bag) or 0) do
      local ok, info = pcall(C.GetContainerItemInfo, bag, slot)
      if ok and type(info) == "table" and info.quality == 0 and not info.hasNoValue and info.itemID then
        local gi = (C_Item and C_Item.GetItemInfo) or GetItemInfo   -- (review round 4) the C_Item one first
        local price = gi and select(11, gi(info.itemID))
        if type(price) == "number" then sum = sum + price * (info.stackCount or 1) end
      end
    end
  end
  return sum
end
-- (11.10., Daniel's dwarf: "you can sell inside Anvilmar too") every merchant you opened is remembered (account
-- wide) and counts as a vendor for the selling stop
function ns.NoteMerchant()
  if not (LeveldonDB and UnitGUID) then return end
  local g = UnitGUID("npc")
  if type(g) ~= "string" then return end
  local kind, _, _, _, _, id = strsplit("-", g)
  id = tonumber(id)
  if kind ~= "Creature" or not id then return end
  local m = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local p = m and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(m, "player")
  local x, y = p and p.GetXY and p:GetXY()
  if not (m and x and y) then return end
  LeveldonDB.merchants = LeveldonDB.merchants or {}
  LeveldonDB.merchants[id] = { n = UnitName and UnitName("npc") or "?", m = m, x = math.floor(x * 1000 + 0.5) / 10, y = math.floor(y * 1000 + 0.5) / 10 }
end
local sellAsked = -1e9
function ns.CheckSell()
  local steps, cur = ns.LeveldonSteps and ns.LeveldonSteps(), ns.LeveldonCur and ns.LeveldonCur()
  local route = ns.LeveldonRoute and ns.LeveldonRoute()
  if not (steps and cur and route and steps[cur]) or steps[cur].k == "sell" then return end
  if UnitAffectingCombat and UnitAffectingCombat("player") then return end
  local now = GetTime and GetTime() or 0
  if now - sellAsked < SELL_EVERY or now - (ns._merchantAt or -1e9) < SELL_EVERY then return end
  -- (11.10., Daniel's dwarf: "selling while a timed quest runs is bad, afterwards") not while a quest's clock runs
  if ns.TimeLeft then
    for q in pairs(ns.TIMED_QUESTS or {}) do
      local left = ns.TimeLeft(q)
      if left and left > 0 then return end
    end
  end
  local why
  -- (25.10., review round 8) a hunter without any ammunition first: with full bags too he must reach a vendor that sells it
  if ns.IsHunter and ns.IsHunter() and ns.AmmoCount and ns.AmmoCount() <= 0 then why = "ammo" end
  if not why and ns.FreeSlots and ns.FreeSlots() <= 1 then why = "bags" end
  -- (12.10., Daniel's hunter: "less than 100 arrows and I should keep killing") ammunition running out: the next
  -- vendor that sells it, whatever the step
  local AMMO_LOW = 100
  if not why and ns.IsHunter and ns.IsHunter() and ns.AmmoCount and ns.AmmoCount() < AMMO_LOW then why = "ammo" end
  -- (11.10., Daniel's dwarf at level 1: "sell the loot right at the start?") for the money only with grey loot
  -- worth the way
  if not why and GetMoney and ns.SkillRank and (ns.GreyValue and ns.GreyValue() or 0) >= GREY_WORTH then
    local money = GetMoney()
    for j = cur, math.min(#steps, cur + 60) do
      local t = steps[j]
      if t.k == "chapter" then break end
      if t.k == "learn" and t.sk and ns.SkillRank(t.sk) == nil and type(money) == "number" and money < (ns.LEARN_COST or 100) then why = "money" break end
    end
  end
  if not why then return end
  local a = ns.QD()
  local here = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not (a and a.DistanceTo and here) then return end
  local best, bd
  local list = {}
  for _, v in ipairs(route.vendors or {}) do list[#list + 1] = v end
  for _, v in pairs(LeveldonDB and LeveldonDB.merchants or {}) do if type(v) == "table" then list[#list + 1] = v end end
  -- (22.10., Daniel: "no vendor visits while you are on the way") a vendor stop only at a hub (the step is an NPC
  -- stop within HUB_WALK yards of you: the hub's vendor as before), when it is nearly on the way (the walk to the
  -- step's place gets at most ON_WAY yards longer through the vendor), or when you cannot go on without it (no
  -- free slot, no ammunition left). Measured on the builder's routes: of 158 walks of 300 yards or more per route
  -- 106 pass a vendor within 220 yards, 85 within an extra 80 yards.
  local dest = steps[cur]
  local dPD = dest.m == here and dest.x and a.DistanceTo(dest.m, dest.x / 100, dest.y / 100) or nil
  local atHub = type(dPD) == "number" and HUB_STEP[dest.k] == true and dPD <= HUB_WALK
  -- (24.10., Daniel's Skyborne warrior on Zephras Isle: bags full 26 times in 24 minutes, "no selling in the middle of a
  -- quest", valid for every route) full bags are no reason for a detour either: the stop comes at a hub or on the way
  -- (above); only a hunter without any ammunition cannot go on
  local urgent = why == "ammo" and ns.AmmoCount and ns.AmmoCount() <= 0
  for _, v in ipairs(list) do
    if v.m == here and (why ~= "ammo" or v.ammo) then
      local d = a.DistanceTo(v.m, v.x / 100, v.y / 100)
      if type(d) == "number" and d <= SELL_NEAR and (not bd or d < bd) then
        local ok = atHub or urgent
        if not ok then
          local dVD = type(dPD) == "number" and ns.Yards and ns.Yards(v, dest) or nil
          ok = type(dVD) == "number" and d + dVD - dPD <= ON_WAY or (not dVD and d <= ON_WAY_NO_PLACE)
        end
        if ok then best, bd = v, d end
      end
    end
  end
  if not best then return end
  sellAsked = now
  table.insert(steps, cur, { k = "sell", n = best.n, m = best.m, x = best.x, y = best.y, why = why, t0 = now, ammo = best.ammo })
end
ns.SellReset = function() sellAsked = -1e9 end -- (tests)

-- (11.10., Daniel: "send me to the cooking trainer for the cooking, there is mostly a fire") without what a campfire
-- needs, Cooking's skill-up goes to the fire by the cooking trainer (same map); with it you cook where you
-- caught the fish (10.10.: no trip back). Leveldon.lua Place() picks.
function ns.CookAtFire(out)
  local learn
  for _, t in ipairs(out) do if t.k == "learn" and t.sk == 185 and t.m and t.x then learn = t break end end
  if not learn then return end
  for _, t in ipairs(out) do
    if t.k == "skillup" and t.sk == 185 and t.m == learn.m then t.fireM, t.fireX, t.fireY = learn.m, learn.x, learn.y end
  end
end

-- (11.10., Daniel's recording: "Camping 101: Cooking [Mulgore]" turned in 31 seconds after learning Cooking at
-- Pyall Silentstride) every "Camping 101: Cooking" only asks you to learn Cooking ("Speak with ... to learn to
-- become a cook"), unlike the other Camping 101 quests (a camping item once you are proficient): its turn-in
-- right after the learning, no Cooking skill-up, no cooking recipe to buy, no "do" step
ns.CAMPING_COOKING = { [96626] = true, [96629] = true, [96634] = true, [96646] = true, [96655] = true, [96658] = true, [96661] = true }
function ns.CookingAtLearn(out)
  local camping = false
  for _, t in ipairs(out) do if t.k == "turnin" and ns.CAMPING_COOKING[t.q] then camping = true break end end
  if not camping then return end
  local learn = false   -- only a route that learns Cooking itself (no learn step: leave it as it is)
  for _, t in ipairs(out) do if t.k == "learn" and t.sk == 185 then learn = true break end end
  if not learn then return end
  local L
  local j = 1
  while j <= #out do
    local t = out[j]
    if (t.k == "skillup" and t.sk == 185) or (t.k == "buy" and t.ck == 185) or (t.k == "do" and ns.CAMPING_COOKING[t.q]) then
      table.remove(out, j)
    else
      if not L and t.k == "learn" and t.sk == 185 then L = j end
      j = j + 1
    end
  end
  if not L then return end
  for k, t in ipairs(out) do
    if t.k == "turnin" and ns.CAMPING_COOKING[t.q] then
      local acc
      for a = 1, #out do if out[a].k == "accept" and out[a].q == t.q then acc = a break end end
      -- (11.10., Tauren route: learn at Bloodhoof, then back to the camp for the accept) an accept after the learning
      -- moves in front of it when you stand at its NPC just before (no skill needed to take it) and its
      -- prerequisites are turned in by then; else the turn-in follows the accept
      if acc and acc > L and L > 1 and ns.Within(out[L - 1], out[acc], 30) and not ns.CookingPrereqAfter(out, out[acc].q, L) then
        local at = table.remove(out, acc)
        table.insert(out, L, at)
        L, acc = L + 1, L
        for kk, tt in ipairs(out) do if tt == t then k = kk break end end
      end
      local after = (acc and acc > L) and acc or L
      if k > after + 1 then
        table.remove(out, k)
        table.insert(out, after + 1, t)
      end
      break
    end
  end
end
-- a prerequisite of the quest turned in at or after position j (Questdon's data)
function ns.CookingPrereqAfter(out, q, j)
  local a = ns.QD()
  if not (a and a.GetQuest) then return false end
  local ok, info = pcall(a.GetQuest, q)
  if not (ok and type(info) == "table" and type(info.prereqs) == "table") then return false end
  for _, p in ipairs(info.prereqs) do
    for k = j, #out do if out[k].k == "turnin" and out[k].q == p then return true end end
  end
  return false
end

---------------------------------------------------------------------------
-- (0.1.8, Daniel 12.10., Northshire: kobolds and wolves killed together, then sent to the abbey to turn in the
-- wolves, back out for the last kobolds, back to the abbey again) Finish what is around you first: when the
-- step now sends you away (a turn-in, an accept, a stop more than LEAVE_YD off) while a coming "do" of a quest
-- in your log still has an open objective within NEAR_YD of you, that "do" comes first. Looks at the next
-- LOOK steps only; at most once per step and quest (no ping-pong).
---------------------------------------------------------------------------
local NEAR_YD, LEAVE_YD, LOOK = 120, 200, 10
local AWAY = { turnin = true, accept = true, train = true, learn = true, buy = true, sell = true, fp = true, bind = true, travel = true, hearth = true }
local pulled = {}
function ns.FinishNearbyFirst(steps, cur)
  local a = ns.QD()
  local s = steps and steps[cur]
  if not (s and AWAY[s.k] and a and a.DistanceTo and a.ObjectivePoints and a.InQuestLog and a.IsQuestComplete) then return false end
  if ns.TimedRunning and ns.TimedRunning() then return false end
  -- a turn-in of an unfinished quest is a "do" itself (Kind)
  if s.k == "turnin" and s.q and a.InQuestLog(s.q) and not a.IsQuestComplete(s.q) then return false end
  if s.m and s.x and s.y then
    local d = a.DistanceTo(s.m, s.x / 100, s.y / 100)
    if type(d) ~= "number" or d < LEAVE_YD then return false end
  elseif s.k ~= "travel" and s.k ~= "hearth" then
    return false
  end
  for j = cur + 1, math.min(#steps, cur + LOOK) do
    local n = steps[j]
    -- (review round 4) once per composition: after the steps are built again it is pulled again
    if n and n.k == "do" and n.q and pulled[n] ~= ns._composeId and a.InQuestLog(n.q) and not a.IsQuestComplete(n.q) then
      local best
      for _, p in ipairs(a.ObjectivePoints(n.q) or {}) do
        local d = a.DistanceTo(p.mapID, p.x, p.y)
        if type(d) == "number" and (not best or d < best) then best = d end
      end
      if best and best <= NEAR_YD then
        pulled[n] = ns._composeId
        table.remove(steps, j)
        table.insert(steps, cur, n)
        n._nearPulled = ns._composeId   -- (15.10., review round 3/4) moved here for now: SaveStep keeps the step it left
        return true
      end
    end
  end
  return false
end
ns.FinishNearbyReset = function() pulled = {} end -- (tests)

---------------------------------------------------------------------------
-- (22.10., Daniel: "setting the hearthstone must not be skipped when you take other quests in the hub")
-- The bind step is not left out by progress: Advance's "a later quest step is done" rule at a login, and
-- FollowPlayer's jump ahead after you took later quests, skipped it (and with it the home the route's later hearth
-- steps count on). Now both keep it while you are in its hub (BIND_HUB yards) and the hearthstone is not bound
-- there yet. Bound there: the home you set at an inn is kept by the inn's place (LeveldonCharDB.boundInn) and
-- counts while GetBindLocation still names it, so the step goes by at a second visit (it stayed open before: the
-- innkeeper cannot bind what is bound). And standing at the inn with the bind step later in this visit, it comes first.
---------------------------------------------------------------------------
local BIND_HUB, BIND_AT, BIND_LOOK, BIND_NEAR = 200, 50, 8, 150
local pulledBind = {}
local function BindKey(s) return ("%d:%.1f:%.1f"):format(s.m, s.x, s.y) end
-- your home changed (Update): the inns of the route you stand at are bound to it now
function ns.NoteHome(home)
  local db = LeveldonCharDB
  local a = ns.QD()
  local steps = ns.LeveldonSteps and ns.LeveldonSteps()
  if not (db and home and steps and a and a.DistanceTo) then return end
  for _, s in ipairs(steps) do
    if s.k == "bind" and s.m and s.x and s.y then
      local d = a.DistanceTo(s.m, s.x / 100, s.y / 100)
      if type(d) == "number" and d <= BIND_NEAR then
        db.boundInn = db.boundInn or {}
        db.boundInn[BindKey(s)] = home
      end
    end
  end
end
-- the bind step's inn is your home
function ns.BoundHere(s)
  local db = LeveldonCharDB
  local home = GetBindLocation and GetBindLocation()
  return (db and db.boundInn and s and s.m and s.x and s.y and home ~= nil and db.boundInn[BindKey(s)] == home) and true or false
end
-- the bind step is open and you are in its hub
function ns.BindOpenHere(s)
  if not (s and s.k == "bind" and s.m and s.x and s.y) or ns.BoundHere(s) then return false end
  local a = ns.QD()
  local d = a and a.DistanceTo and a.DistanceTo(s.m, s.x / 100, s.y / 100)
  return type(d) == "number" and d <= BIND_HUB
end
-- you stand at the inn (BIND_AT yards) and the step now is another stop of its visit: the hearthstone first
function ns.BindFirst(steps, cur)
  local s = steps and steps[cur]
  local a = ns.QD()
  if not (s and s.k ~= "bind" and HUB_STEP[s.k] and s.m and s.x and a and a.DistanceTo) then return false end
  if UnitAffectingCombat and UnitAffectingCombat("player") then return false end
  for j = cur + 1, math.min(#steps, cur + BIND_LOOK) do
    local n = steps[j]
    if not (n and HUB_STEP[n.k] and n.m == s.m) then return false end   -- the run of stops at NPCs ends
    if n.k == "bind" then
      if pulledBind[n] == ns._composeId or not n.x or not n.y or not (ns.Within and ns.Within(n, s, 80)) or ns.BoundHere(n) then return false end
      local d = a.DistanceTo(n.m, n.x / 100, n.y / 100)
      if type(d) ~= "number" or d > BIND_AT then return false end
      pulledBind[n] = ns._composeId
      table.remove(steps, j)
      table.insert(steps, cur, n)
      n._nearPulled = ns._composeId   -- moved here for now: SaveStep keeps the step it left (as FinishNearbyFirst)
      return true
    end
  end
  return false
end
ns.BindReset = function() pulledBind = {} end -- (tests)
