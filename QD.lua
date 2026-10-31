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
