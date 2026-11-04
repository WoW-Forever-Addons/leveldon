local addonName, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- (04.11.2026, Era-Test, Daniel: "jeder minimap button sollte doch einen goldenen ring bekommen. Dann sollte der Minimap
-- knopf so aussehen wie das Bild aus curseforge"; decided 04.11.: every Don addon its own button, each one can be
-- switched off) Leveldon's minimap button. The button itself is DonCore's (Libs\DonCore\MinimapButton.lua, minor 3:
-- gold ring, round symbol, dragging, the option); here only what is Leveldon's:
--   Left click   show or hide the route window (as /lvd)
--   Right click  a small menu like Questdon's (see Menu below)
--   Mouse over   the route and the step you are on
--   Drag         moves it around the minimap (angle in LeveldonDB.minimapAngle, 175 to start with)
-- Saved account-wide in LeveldonDB (minimapButton: nil counts as on). ns.db is LeveldonDB for the module; no other
-- Leveldon file reads ns.db.
---------------------------------------------------------------------------
local MB = LibStub and LibStub("DonCore-1.0", true) and LibStub("DonCore-1.0"):Get("MinimapButton", 3)
if not MB then return end

local function Lines()
  local lines = {}
  local info = ns.RouteInfo and ns.RouteInfo()
  if type(info) == "string" and info ~= "" then lines[#lines + 1] = { info } end
  local steps = ns.LeveldonSteps and ns.LeveldonSteps()
  local cur = ns.LeveldonCur and ns.LeveldonCur()
  if type(steps) == "table" and #steps > 0 and type(cur) == "number" then
    lines[#lines + 1] = { L["Step %d of %d"]:format(math.min(cur, #steps), #steps) }
  end
  return lines
end

---------------------------------------------------------------------------
-- Menu (04.11.2026, Era-Test, Daniel: "bei questdon kommt mit rechtsklick so ein menü, das hätte ich bei den anderen
-- auch gerne, und bei jedem meiner addons soll mit rechtsklick und dem menü auch eine option sein, dass man direkt dort
-- den minimap knopf ausschalten kann"): the window, a line, the most used switches of the options (check rows, the menu
-- stays open), a line, all options. DonCore adds the line and "Hide minimap button" at the end. Each switch does what
-- its option in the options window does (ns.LVD_OPTIONS, Options.lua) and the open options window shows it at once.
-- The rows are built at the first right click, Options.lua is loaded by then.
---------------------------------------------------------------------------
local SWITCHES = {
  { label = "Only record your run", isOn = function() return ns.RecordOnly and ns.RecordOnly() end,
    toggle = function() if ns.SetRecordOnly then ns.SetRecordOnly() end end },
  { label = "Arrow instead of the compass", key = "arrowOnly" },
  { label = "Markers over the next NPC", key = "raidMarks" },
  { label = "Mark items the route needs later", key = "bagMarks" },
  { label = "Sleeping bag reminder", key = "bag" },
  { label = "Hide the game's quest tracker", key = "hideTracker" },
}
ns.LVD_MENU_SWITCHES = SWITCHES -- (tests)

local function Opt(sw) local O = ns.LVD_OPTIONS return sw.key and type(O) == "table" and O[sw.key] or nil end
local function IsOn(sw)
  if sw.isOn then return sw.isOn() and true or false end
  local o = Opt(sw)
  if not o then return false end
  local ok, v = pcall(o.get)
  return ok and v and true or false
end
local function Toggle(sw)
  if sw.toggle then pcall(sw.toggle)
  else
    local o = Opt(sw)
    if o then pcall(o.set, not IsOn(sw)) end
  end
  if ns.RefreshOptions then pcall(ns.RefreshOptions) end
end

local function MenuItems()
  local items = {
    { text = L["Show or hide the window"], onClick = function() if ns.ToggleWindow then pcall(ns.ToggleWindow) end end },
    { line = true },
  }
  for _, sw in ipairs(SWITCHES) do
    items[#items + 1] = { text = L[sw.label], onClick = function() Toggle(sw) end, isOn = function() return IsOn(sw) end }
  end
  items[#items + 1] = { line = true }
  items[#items + 1] = { text = L["All options"], onClick = function() if ns.OpenOptions then ns.OpenOptions() end end }
  return items
end

MB:Attach(ns, {
  name = "LeveldonMinimapButton", icon = "Interface\\AddOns\\Leveldon\\Media\\minimap", addon = "Leveldon",
  angleKey = "minimapAngle", defaultAngle = 175,
  title = function() return ns.Style and ns.Style.Wordmark and ns.Style.Wordmark("Level", "don") or "|cff3fa9f5Level|rdon" end,
  lines = Lines,
  hint = function() return L["Left click: show or hide the window. Right click: menu. Drag: move it around the minimap."] end,
  onLeft = function() if ns.ToggleWindow then pcall(ns.ToggleWindow) end end,
  -- (04.11.2026, Era-Test) right click: the menu (onRight is not used with a menu); before: the options
  menu = { name = "LeveldonMinimapMenu", width = 340, items = MenuItems }, -- 340: the long German and French rows fit
})

-- the saved table once the game has read it; the button after login (the minimap has its size then)
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" then
    if name ~= addonName then return end
    LeveldonDB = LeveldonDB or {}
    ns.db = LeveldonDB
  else
    LeveldonDB = LeveldonDB or {}
    ns.db = LeveldonDB
    pcall(ns.RefreshMinimapButton)
  end
end)
