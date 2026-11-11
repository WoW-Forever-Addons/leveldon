local _, ns = ...

---------------------------------------------------------------------------
-- (30.10.2026, DONCORE_PLAN.md "DonData Lese-Engine" L4) Where Leveldon reads the quests and points the arrow.
-- ns.QD() is QuestdonAPI when Questdon runs (everything as before: its list, its compass, its options window).
-- Without Questdon it is a stand-in: the quest data from DonData (DonDataAPI, the same answers), the arrow and the
-- compass from DonMap (DonMapAPI); what only Questdon has (its options window, the quest text, nameplate claims,
-- the shared channel, docking under its list) is not there, and Leveldon's own checks (a.X and a.X()) leave it out.
---------------------------------------------------------------------------
local ALONE_READ = { "GetQuest", "QuestTitle", "CanTakeQuest", "CanTakeQuestLater", "NotOfferedLevel", "IsQuestDone",
  "InQuestLog", "QuestNpcWalks", "IsQuestComplete", "CreatureName", "QuestExists", "QuestStart", "BreadcrumbTargets",
  "ObjectivePoints", "QuestPOI", "ObjectiveHint", "ItemName", "TurnInPoint", "DistanceTo", "PlayerPosition",
  "ObjectiveCreatures", "TurnInNpc" }

local alone
local function Alone()
  local D = rawget(_G, "DonDataAPI")
  if type(D) ~= "table" then return nil end
  if alone and alone._D == D then return alone end
  local M = rawget(_G, "DonMapAPI")
  local a = { _D = D, version = 2, alone = true } -- version: the reading part answers as QuestdonAPI 2 does
  for _, k in ipairs(ALONE_READ) do a[k] = D[k] end
  if type(M) == "table" and type(M.SetArrowTarget) == "function" then
    -- the guide's step on DonMap's arrow (as a guide, below a clicked pin); nil releases it
    -- (31.10.2026, Kritikrunde) a do step's area (target.area, .points) is Questdon's: without it the arrow goes to
    -- the area's nearest point, picked again every 2 s while the step stays (Leveldon sends the same area only once)
    local ticker, areaT
    local function Nearest(t)
      local best, bd
      for _, p in ipairs(t.points) do
        local d = D.DistanceTo and D.DistanceTo(p.mapID, p.x, p.y)
        if d and (not bd or d < bd) then best, bd = p, d end
      end
      return best
    end
    local last
    local function Point(t)
      local p = Nearest(t)
      if not p then return t end
      if last and last.mapID == p.mapID and last.x == p.x and last.y == p.y and last.label == t.label then return nil end
      last = { mapID = p.mapID, x = p.x, y = p.y, label = t.label }
      return last
    end
    function a.SetArrowTarget(target)
      if ticker then ticker:Cancel() ticker = nil end
      areaT, last = nil, nil
      local send = target
      if target and target.area and type(target.points) == "table" and #target.points > 0 then
        areaT = target
        send = Point(target) or target
        if C_Timer and C_Timer.NewTicker then
          ticker = C_Timer.NewTicker(2, function()
            if not areaT then return end
            local p = Point(areaT)
            if p then pcall(M.SetArrowTarget, "leveldon", p, M.PRIO and M.PRIO.guide or 2) end
          end)
        end
      end
      if M.SetArrowUser then pcall(M.SetArrowUser, "leveldon", target ~= nil) end
      pcall(M.SetArrowTarget, "leveldon", send, M.PRIO and M.PRIO.guide or 2)
    end
    if type(M.ArrowState) == "function" then a.ArrowState = M.ArrowState end
    -- (31.10.2026) the compass in Leveldon's window shows the way: DonMap's arrow window then draws nothing (two
    -- pointers otherwise); DonMapAPI 5, older DonMap keeps its window
    if type(M.SetArrowCompass) == "function" then
      function a.SetGuideCompass(on) pcall(M.SetArrowCompass, "leveldon", on) end
    end
    if type(M.NewCompass) == "function" then a.NewCompass = M.NewCompass end
  end
  alone = a
  return a
end

function ns.QD()
  local q = rawget(_G, "QuestdonAPI")
  if q then return q end
  return Alone()
end
-- (tests, /lvd diag) true when Leveldon runs on DonData and DonMap without Questdon
function ns.QDAlone() return rawget(_G, "QuestdonAPI") == nil and Alone() ~= nil end

-- (05.11.2026, as Guildon b8dc89d9, Daniel's /gn names on WoW Forever) Forever has surnames
-- (C_PlayerInfo.ShouldDisplaySurname() true): UnitName and UnitFullName give the surname where other clients give the
-- realm ("Mae", "Wipeborn"); the roster and the senders of addon messages say "Ratloff Ashbloom" (no realm), and a
-- whisper needs that whole name. There the name is "<first> <surname>", the realm comes from GetNormalizedRealmName,
-- never from the second value of UnitName or UnitFullName.
-- (05.11.2026, Siyo) with the surnames hidden in the game's options ShouldDisplaySurname() is false, yet UnitFullName still
-- gives the surname in the realm's place and the senders still say "Siyo Fren": the surname became the realm. So a client
-- that knows the function counts as one with surnames also when the second value of UnitFullName is not the own realm;
-- its realm never comes from there (ns.MyRealmKey).
function ns.SurnameClient()
  local P = C_PlayerInfo
  return type(P) == "table" and type(P.ShouldDisplaySurname) == "function"
end
local function SurnameRealmKey(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b = pcall(fn, ...)
  local v = a
  if fn == UnitFullName then v = b end
  if not ok or type(v) ~= "string" or v == "" or (issecretvalue and issecretvalue(v)) then return nil end
  return (v:gsub("[%s%-]", ""))
end
function ns.Surnames()
  if not ns.SurnameClient() then return false end
  local ok, v = pcall(C_PlayerInfo.ShouldDisplaySurname)
  if ok and v == true then return true end
  local second = SurnameRealmKey(UnitFullName, "player")
  local norm, plain = SurnameRealmKey(GetNormalizedRealmName), SurnameRealmKey(GetRealmName)
  if not second or not (norm or plain) then return false end
  return second ~= norm and second ~= plain
end
-- name and realm of a unit as chat and addon messages know it: on Forever ("Mae Wipeborn", nil), elsewhere
-- (name, realm or nil); nil for anything unreadable
function ns.UnitNameRealm(unit)
  local ok, n, r = pcall(UnitName, unit)
  if not ok or type(n) ~= "string" then return nil end
  if issecretvalue and (issecretvalue(n) or (r ~= nil and issecretvalue(r))) then return nil end
  if n == "" then return nil end
  if type(r) ~= "string" or r == "" then r = nil end
  if ns.Surnames() then return r and (n .. " " .. r) or n, nil end
  return n, r
end
-- the own realm for "Name-Realm" (no spaces): on Forever GetNormalizedRealmName, elsewhere UnitFullName's realm first
function ns.MyRealmKey()
  local r
  if not ns.SurnameClient() then
    local ok, _, rr = pcall(UnitFullName, "player")
    if ok and type(rr) == "string" and rr ~= "" then r = rr end
  end
  for _, fn in ipairs({ GetNormalizedRealmName, GetRealmName }) do
    if not r and type(fn) == "function" then
      local ok, v = pcall(fn)
      if ok and type(v) == "string" and v ~= "" then r = v end
    end
  end
  return r and (r:gsub("[%s%-]", "")) or "?"
end
