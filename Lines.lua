local _, ns = ...
local L = ns.L
local Style = ns.Style

---------------------------------------------------------------------------
-- (22.10., Daniel: "routes selectable, maybe you want the human route as a dwarf for the reputation"; "every race for
-- every start area, the Horde alike") The route choice. Your race starts in its own area; from there the route goes on
-- through the second stage of any start area of your faction (Elwynn, Dun Morogh, Teldrassil; Durotar, Mulgore,
-- Tirisfal). The quests differ, so do the hours and the reputation (Stormwind for every Alliance race, Orgrimmar for
-- every Horde race). ns.LINES (LinesData.lua, built by export_variants.py) has hours, quests and the reputation each
-- route earns; the routes themselves are in Leveldon_<Race>Lines (load on demand). The choice window shows them, the
-- choice is saved per character (LeveldonCharDB.line) and can change in the middle of the route:
-- ns.SetLine -> ns.ReloadRoute goes on with the same step or the first unfinished one.
---------------------------------------------------------------------------
local FACTION_NAME = { [72] = "Stormwind", [47] = "Ironforge", [54] = "Gnomeregan", [69] = "Darnassus",
  [76] = "Orgrimmar", [81] = "Thunder Bluff", [68] = "Undercity", [530] = "Darkspear" }
-- the standings of the game: from this much reputation on (Neutral 0, Friendly 3000, Honored 9000, Revered 21000, Exalted 42000)
local STANDINGS = { { 42000, 8, "Exalted" }, { 21000, 7, "Revered" }, { 9000, 6, "Honored" }, { 3000, 5, "Friendly" }, { 0, 4, "Neutral" } }

local function Standing(value)
  for _, s in ipairs(STANDINGS) do
    if value >= s[1] then
      local label = _G and _G["FACTION_STANDING_LABEL" .. s[2]]
      return s[2], type(label) == "string" and label or s[3]
    end
  end
  return 3, "Unfriendly"
end

-- name and earned reputation of a faction as the game says (nil: not known to this client)
local function FactionNow(id)
  if GetFactionInfoByID then
    local ok, name, _, _, _, _, value = pcall(GetFactionInfoByID, id)
    if ok and type(name) == "string" and type(value) == "number" then return name, value end
  end
  if C_Reputation and C_Reputation.GetFactionDataByID then
    local ok, d = pcall(C_Reputation.GetFactionDataByID, id)
    if ok and type(d) == "table" and type(d.name) == "string" and type(d.currentStanding) == "number" then
      return d.name, d.currentStanding   -- (the absolute value, like barValue)
    end
  end
  return nil
end

local function Thousands(n) return Style.Number and Style.Number(n) or tostring(n) end

-- "Stormwind +5,200: Friendly to Honored", the reputation lines of one route (largest first)
local function RepLines(info)
  local ids = {}
  for id, v in pairs(info.r or {}) do if v > 0 then ids[#ids + 1] = id end end
  table.sort(ids, function(a, b) return info.r[a] > info.r[b] end)
  local out = {}
  for _, id in ipairs(ids) do
    local name, value = FactionNow(id)
    name = name or L[FACTION_NAME[id] or tostring(id)]
    local gain = info.r[id]
    if value then
      local _, was = Standing(value)
      local _, now = Standing(value + gain)
      if was == now then out[#out + 1] = (L["%s +%s (stays %s)"]):format(name, Thousands(gain), now)
      else out[#out + 1] = (L["%s +%s: %s to %s"]):format(name, Thousands(gain), was, now) end
    else
      out[#out + 1] = (L["%s +%s"]):format(name, Thousands(gain))
    end
  end
  return out
end
ns.LineRepLines = RepLines -- (tests)

local Kit = ns.Kit
local dlg, picked
local function Hours(info) return (LeveldonCharDB and LeveldonCharDB.dungeons and (info.hd or 0) > 0) and info.hd or info.h end

-- (02.11.2026, StyleKit 2 step 4, docs/layout_2026-11-02/leveldon/) DonCore's dialog (Kit.Dialog): a line on top, the
-- routes as list rows with a choice point (hours and quests on the right, the reputation in the tooltip), the hint
-- below, Cancel and Take it; a click picks, "Take it" sets the route
local function Rows()
  local list, current = ns.LineChoices()
  local items = {}
  if not list then return items, nil end
  local faction = UnitFactionGroup and select(2, UnitFactionGroup("player")) or ""
  items[1] = { kind = "group", text = L["Route for levels 1 to 30"], static = true, right = faction }
  for _, e in ipairs(list) do
    local info, key = e.info, e.key
    local title = ns.LineTitle(key)
    local rep = RepLines(info)
    items[#items + 1] = { title = e.own and (L["%s (your own)"]):format(title) or title, sub = rep[1] or "",
      radio = key == (picked or current), active = key == (picked or current), key = key, rightWidth = 110,
      right = (L["%.1f h"]):format(Hours(info)) .. "  ·  " .. (L["%d quests"]):format(info.q),
      tooltipFn = function()
        local lines = { (L["About %.1f hours, %d quests handed in"]):format(info.h, info.q) }
        if (info.hd or 0) > 0 then lines[#lines + 1] = (L["With dungeons: about %.1f hours"]):format(info.hd) end
        for _, t in ipairs(rep) do lines[#lines + 1] = t end
        return title, lines, key == current and L["This is your route."] or L["Click: take this route from here on"]
      end }
  end
  return items, current
end

local function Refresh()
  if not dlg then return end
  local items, current = Rows()
  if #items == 0 then
    dlg.intro:SetText(L["No other start areas for this character yet."])
    dlg.list:SetItems({})
  else
    dlg.intro:SetText(L["Your race starts in its own area. From there the route can go on through the start area of another race of your faction: other quests, other hours, other reputation."])
    dlg.list:SetItems(items)
  end
  dlg.current = current
  dlg:SetButtons({ { text = L["Cancel"], onClick = function(d) d:Hide() end },
    { text = L["Take it"], kind = "primary", disabled = not picked or picked == current, onClick = function(d)
      if picked and picked ~= current then ns.SetLine(picked) end
      d:Hide()
    end } })
end
ns.LineRefresh = Refresh

local function Create()
  local d = Kit.Dialog("LeveldonLines", { width = 460, height = 340, onLayout = function(self, w, h)
    if not self.list then return end
    self.intro:ClearAllPoints() self.intro:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, 0)
    Kit.Fit(self.intro, w)
    self.list:ClearAllPoints() self.list:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, -22)
    self.list:Resize(w, math.max(40, h - 22 - 22))
    self.foot:ClearAllPoints() self.foot:SetPoint("BOTTOMLEFT", self.body, "BOTTOMLEFT", 0, 2)
    Kit.Fit(self.foot, w)
  end })
  d:SetTitle(L["Choose your route"], "Interface\\Icons\\INV_Misc_Map_01")
  d.intro = Kit.Text(d.body, "sub", Kit.C.muted)
  d.foot = Kit.Text(d.body, "sub", Kit.C.muted)
  d.foot:SetText(L["You can change it in the middle of the route: Leveldon goes on with the same step, or the first one you have not done yet. Levels 30 to 60 stay the same."])
  d.list = Kit.List(d.body, { zebra = false, onClick = function(it)
    if it.key then picked = it.key Refresh() end
  end })
  dlg = d
  return d
end

function ns.ShowLines()
  if not dlg then Create() end
  picked = nil
  Refresh()
  dlg:Show()
  dlg:Layout()
  return dlg
end
ns.LinesPanel = function() return dlg end -- (tests)
ns.LinesPick = function(key) picked = key Refresh() end -- (tests)

-- /lvd line: the choice window; /lvd line <key>: take that start area (own: back to the race's own)
function ns.LineCommand(arg)
  arg = (arg or ""):lower():match("^%s*(.-)%s*$")
  local list, current = ns.LineChoices()
  if not list then
    print("|cff3fa9f5Level|rdon: " .. L["No other start areas for this character yet."])
    return
  end
  if arg == "" then ns.ShowLines() return end
  if arg == "own" or arg == "default" then arg = list[1].key end
  if ns.SetLine(arg) then
    print("|cff3fa9f5Level|rdon: " .. (L["Route: %s"]):format(ns.RouteInfo()))
  else
    local keys = {}
    for _, e in ipairs(list) do keys[#keys + 1] = e.key end
    print("|cff3fa9f5Level|rdon: " .. (L["Unknown start area. Choose from: %s"]):format(table.concat(keys, ", ")))
  end
end
