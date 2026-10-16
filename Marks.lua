local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- (0.1.8, Daniel 12.10.: "not the map pins for trainers, the target markers: skull, triangle, star, blue
-- square and circle, as soon as I come near the quest giver, the turn-in NPC, the trainer or the vendor
-- whose turn it is") The NPC of the current step gets a mark over its head (own drawing, see below). The
-- numbers are the kinds (once the game's raid icons, kept as keys):
--   1  quest giver of an accept step           gold
--   4  turn-in NPC                             green
--   6  trainer (class, profession)             teal
--   2  vendor (buy, sell)                      orange
--   3/5 flight master, innkeeper (new home)    violet
--   8  a named mob of the quest you are doing  red: the one creature of an objective that needs it once
--      (Garrick Padfoot, Supervisor Fizsprocket), or a rare of the objective. Never plain quest mobs.
-- The NPC is found when its nameplate shows: by its creature ID (Questdon's data) or its name. The next
-- step's NPC gets the mark, the last one loses it. Option db.raidMarks (on by default), /lvd raidmarks.
---------------------------------------------------------------------------
local ICON = { accept = 1, turnin = 4, train = 6, learn = 6, buy = 2, sell = 2, fp = 3, bind = 5 }
local M = {}
ns.LvdMarks = M
local stats = { marked = 0, failed = 0, secret = 0, seen = 0 }
M.stats = stats

local function DB() return LeveldonCharDB or {} end
local function API() return rawget(_G, "QuestdonAPI") end

local function Lower(s)
  if type(s) ~= "string" then return nil end
  local ok, v = pcall(string.lower, s)
  return ok and v or nil
end

-- what the current step wants marked: { icon, ids = { [creatureID] = true }, names = { [lower name] = true } }
function M.Want()
  local steps, cur = ns.LeveldonSteps and ns.LeveldonSteps(), ns.LeveldonCur and ns.LeveldonCur()
  local s = type(steps) == "table" and cur and steps[cur]
  if not s then return nil end
  local a = API()
  -- a turn-in of an unfinished quest is a "do" (as in the window)
  local kind = s.k
  if kind == "turnin" and s.q and a and a.InQuestLog and a.IsQuestComplete and a.InQuestLog(s.q) and not a.IsQuestComplete(s.q) then kind = "do" end
  if kind == "do" then
    if not (s.q and a and a.ObjectiveCreatures) then return nil end
    local w = { icon = 8, ids = {}, names = {}, kind = "do", rare = {} }
    for _, o in pairs(a.ObjectiveCreatures(s.q) or {}) do
      if not o.done then
        local single = (o.need == 1 or (o.need == nil and #o.ids == 1)) and #o.ids <= 2
        for _, id in ipairs(o.ids) do
          if single then w.ids[id] = true else w.rare[id] = true end
        end
      end
    end
    if not next(w.ids) and not next(w.rare) then return nil end
    return w
  end
  local icon = ICON[kind]
  if not icon then return nil end
  local w = { icon = icon, ids = {}, names = {}, kind = kind }
  -- (15.10., review round 1) the NPC's id from the route (inn, flight master, profession and class trainer, vendor):
  -- names alone matched in English only, and never the flight master or a profession trainer
  if s.npc then w.ids[s.npc] = true end
  if s.tn then w.names[Lower(s.tn) or ""] = true end   -- (15.10., review round 3) a start area's profession trainer
  if s.k == "train" and s.tr then
    local _, cls = UnitClass("player")
    local t = cls and s.tr[cls]
    if t and t.id then w.ids[t.id] = true end
  end
  if s.k == "accept" and s.q and a and a.GetQuest then
    local q = a.GetQuest(s.q)
    for _, id in ipairs(q and q.givers or {}) do w.ids[id] = true end
    if a.QuestStart then
      local _, _, _, npc = a.QuestStart(s.q)
      if npc then w.names[Lower(npc) or ""] = true end
    end
  elseif s.k == "turnin" and s.q and a and a.TurnInNpc then
    local id, name = a.TurnInNpc(s.q)
    if id then w.ids[id] = true end
    if name then w.names[Lower(name) or ""] = true end
  elseif s.k == "buy" then
    if s.v then w.names[Lower(s.v) or ""] = true end
  elseif s.n then
    w.names[Lower(s.n) or ""] = true
  end
  w.names[""] = nil
  if not next(w.ids) and not next(w.names) then return nil end
  return w
end

local function CreatureID(unit)
  local ok, g = pcall(UnitGUID, unit)
  if not ok or type(g) ~= "string" then return nil end
  local ok2, id = pcall(function()
    local kind, _, _, _, _, nid = strsplit("-", g)
    if kind ~= "Creature" then return nil end
    return tonumber(nid)
  end)
  if not ok2 then stats.secret = stats.secret + 1 return nil end
  return id
end

local function Matches(unit, w)
  local okP, isPlayer = pcall(UnitIsPlayer, unit)
  if not okP or isPlayer == true then return false end
  local id = CreatureID(unit)
  if id and w.ids[id] then return true end
  -- (skull) a mob of a many-mob objective only when the game calls it rare (a named one among them)
  if id and w.rare and w.rare[id] then
    local okC, c = pcall(UnitClassification, unit)
    return okC and (c == "rare" or c == "rareelite" or c == "worldboss") or false
  end
  if w.kind == "do" then return false end -- never by name: quest mobs share names
  local okN, name = pcall(UnitName, unit)
  local low = okN and Lower(name)
  return low ~= nil and w.names[low] == true
end

-- (0.1.8, Daniel's test 12.10.: "Leveldon has been blocked from an action only available to the Blizzard UI")
-- Forever keeps SetRaidTarget to Blizzard's own interface. So Leveldon draws its own mark on a small frame over
-- the NPC's nameplate (as Questdon's quest icons, a little higher so both fit). Needs the nameplates of
-- friendly NPCs; without a nameplate there is no mark. Nobody else sees it.
-- (0.1.8, Daniel 12.10.: "nice markers that fit; not a ! over Blizzard's !") Not the raid icons: the
-- compass needle of Questdon, small, pointing down at the NPC, in the colour of what to do there, with a soft
-- glow that pulses. Blizzard's ! and ? stay what they are.
local MEDIA = "Interface\\AddOns\\Questdon\\Media\\"
-- (Daniel 12.10.: "our arrow may be more striking") bigger, a brighter halo and a small bob down to the NPC
local SIZE, LIFT, BOB = 46, 12, 7
local COLORS = {
  [1] = { 1.00, 0.82, 0.25 },  -- accept: gold
  [4] = { 0.40, 0.92, 0.45 },  -- turn in: green
  [6] = { 0.25, 0.86, 0.82 },  -- trainer: teal
  [2] = { 1.00, 0.60, 0.20 },  -- vendor: orange
  [3] = { 0.74, 0.56, 1.00 },  -- flight master: violet
  [5] = { 0.74, 0.56, 1.00 },  -- innkeeper: violet
  [8] = { 1.00, 0.30, 0.25 },  -- named mob: red
}
local frames, free = {}, {} -- [unit] = frame
local function Take()
  local f = table.remove(free)
  if f then return f end
  f = CreateFrame("Frame", nil, UIParent)
  f:SetSize(SIZE, SIZE)
  f.glow = f:CreateTexture(nil, "ARTWORK")
  f.glow:SetPoint("CENTER")
  f.glow:SetSize(SIZE * 2.1, SIZE * 2.1)
  f.glow:SetTexture(MEDIA .. "ArrowNeedleGlow")
  f.glow:SetBlendMode("ADD")
  f.icon = f:CreateTexture(nil, "OVERLAY")
  f.icon:SetAllPoints()
  f.icon:SetTexture(MEDIA .. "ArrowNeedle")
  -- the needle points up in its art: turned round, it points down at the NPC
  if f.icon.SetRotation then pcall(f.icon.SetRotation, f.icon, math.pi) end
  if f.glow.SetRotation then pcall(f.glow.SetRotation, f.glow, math.pi) end
  if f.glow.CreateAnimationGroup then
    local ok, group = pcall(f.glow.CreateAnimationGroup, f.glow)
    if ok and group then
      group:SetLooping("BOUNCE")
      local fade = group:CreateAnimation("Alpha")
      if fade then
        fade:SetFromAlpha(0.55)
        fade:SetToAlpha(1)
        fade:SetDuration(0.8)
        if fade.SetSmoothing then fade:SetSmoothing("IN_OUT") end
      end
      f.pulse = group
    end
  end
  if f.CreateAnimationGroup then
    local ok, group = pcall(f.CreateAnimationGroup, f)
    if ok and group then
      group:SetLooping("BOUNCE")
      local move = group:CreateAnimation("Translation")
      if move then
        move:SetOffset(0, -BOB)
        move:SetDuration(0.6)
        if move.SetSmoothing then move:SetSmoothing("IN_OUT") end
      end
      f.bob = group
    end
  end
  if f.EnableMouse then f:EnableMouse(false) end
  return f
end
-- (Daniel 12.10.: "everything twice and three times") one mark per NPC: where ours stands, Questdon's small
-- ? and ! go (QuestdonAPI.SetPlateClaim) and come back when ours goes
local function Told(unit)
  local api = API()
  if api and api.RefreshPlate then pcall(api.RefreshPlate, unit) end
end
local function Release(unit)
  local f = frames[unit]
  if not f then return end
  frames[unit] = nil
  if f.pulse and f._pulsing then pcall(f.pulse.Stop, f.pulse) f._pulsing = nil end
  if f.bob then pcall(f.bob.Stop, f.bob) end
  f:Hide()
  pcall(f.SetParent, f, UIParent)
  free[#free + 1] = f
  Told(unit)
end
local function Art(f, icon)
  local c = COLORS[icon] or COLORS[1]
  -- gold for a quest giver as the compass; the others in their colour (the art made grey first)
  if f.icon.SetDesaturated then pcall(f.icon.SetDesaturated, f.icon, icon ~= 1) end
  f.icon:SetVertexColor(c[1], c[2], c[3], 1)
  f.glow:SetVertexColor(c[1], c[2], c[3], 1)
  if f.pulse and not f._pulsing then
    pcall(f.pulse.Play, f.pulse) f._pulsing = true
    if f.bob then pcall(f.bob.Play, f.bob) end
  end
  f._icon = icon
end
local function Plate(unit)
  if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
  local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
  if not ok or type(plate) ~= "table" then return nil end
  if plate.IsForbidden then
    local okF, forbidden = pcall(plate.IsForbidden, plate)
    if not okF or (forbidden ~= nil and forbidden ~= false) then return nil end
  end
  return plate
end

-- unit: a nameplate unit ("nameplate3"). true when it carries our mark now.
function M.Check(unit)
  local db = DB()
  if type(unit) ~= "string" then return false end
  if db.raidMarks == false then Release(unit) return false end
  local okE, exists = pcall(UnitExists, unit)
  local w = okE and exists and M.Want() or nil
  if not w then Release(unit) return false end
  stats.seen = stats.seen + 1
  if not Matches(unit, w) then Release(unit) return false end
  local plate = Plate(unit)
  if not plate then Release(unit) return false end
  local f = frames[unit]
  local new = not f
  if not f then
    f = Take()
    frames[unit] = f
    stats.marked = stats.marked + 1
  end
  Art(f, w.icon)
  local ok = pcall(function()
    f:SetParent(plate)
    f:ClearAllPoints()
    f:SetPoint("BOTTOM", plate, "TOP", 0, LIFT)
    if plate.GetFrameLevel then f:SetFrameLevel((plate:GetFrameLevel() or 1) + 6) end
  end)
  if not ok then stats.failed = stats.failed + 1 Release(unit) return false end
  f:Show()
  if new then Told(unit) end
  return true
end
function M.Frames() return frames end -- (tests)

-- all nameplates shown now (the route moved on next to the NPC)
function M.Scan()
  if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
  local seen = {}
  local ok, plates = pcall(C_NamePlate.GetNamePlates)
  for _, p in ipairs(ok and type(plates) == "table" and plates or {}) do
    local unit = type(p) == "table" and (p.namePlateUnitToken or (p.UnitFrame and p.UnitFrame.unit))
    if type(unit) == "string" then seen[unit] = true pcall(M.Check, unit) end
  end
  for unit in pairs(frames) do if not seen[unit] then Release(unit) end end
end

-- once: the nameplates of friendly NPCs are off, so no NPC can carry a mark
local hinted = false
local function Hint()
  if hinted or DB().raidMarks == false or not GetCVar then return end
  local ok, v = pcall(GetCVar, "nameplateShowFriendlyNPCs")
  if ok and v == "0" then
    hinted = true
    print(L["|cff3fa9f5Level|rdon: the marks over NPCs need the nameplates of friendly NPCs (interface options, Names)."])
  end
end

local function Claim()
  local api = API()
  if api and api.SetPlateClaim then pcall(api.SetPlateClaim, function(unit) return frames[unit] ~= nil end) end
end
M.Claim = Claim
Claim()

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(_, event, unit)
  if event == "NAME_PLATE_UNIT_ADDED" then pcall(M.Check, unit)
  elseif event == "NAME_PLATE_UNIT_REMOVED" then Release(unit)
  elseif event == "PLAYER_ENTERING_WORLD" then Claim() pcall(Hint) end
end)
for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_ENTERING_WORLD" }) do pcall(f.RegisterEvent, f, e) end
if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(1, function() pcall(M.Scan) end) end

function M.Command()
  local db = DB()
  db.raidMarks = db.raidMarks == false
  if db.raidMarks == false then for unit in pairs(frames) do Release(unit) end else pcall(M.Scan) end
  print(L["|cff3fa9f5Level|rdon: target markers "] .. (db.raidMarks ~= false and L["on"] or L["off"]) .. ".")
end
