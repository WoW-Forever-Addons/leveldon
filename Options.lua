local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- (17.10., Daniel: "an option to hide background and borders; bring the options menu up to Questdon's look")
-- Leveldon's options window. The window itself is Questdon's (QuestdonAPI.NewOptionsWindow): its look, tabs,
-- cards with on/off pills, the explanation on the right and the search stay the same in both addons. Until now
-- Leveldon's settings were /lvd commands only; each option here reads and writes the same saved value its command
-- does (several are "on unless switched off"), and the switches that rebuild the route go through the command.
---------------------------------------------------------------------------
local function CharDB() LeveldonCharDB = LeveldonCharDB or {} return LeveldonCharDB end
local function AccDB() LeveldonDB = LeveldonDB or {} return LeveldonDB end
local function Cmd(msg)
  local f = SlashCmdList and SlashCmdList.LEVELDON
  if f then pcall(f, msg) end
end
local function Panel() return rawget(_G, "LeveldonPanel") end
local function Redraw() if ns.LeveldonRefresh then pcall(ns.LeveldonRefresh) end end

-- (25.10., Daniel: "lock, size and opacity like in Questdon") the window's own values are the Style kit's: they are
-- saved in LeveldonCharDB.panel by Leveldon.lua Get/Set (locked, scale, alpha, combatFade); with the window up the
-- kit's methods do the work, before that the value is written straight to the saved table.
local function Saved(key) local t = CharDB().panel return t and t[key] end
local function SaveRaw(key, v) local c = CharDB() c.panel = c.panel or {} c.panel[key] = v end
local function Kit() return ns.Style end

-- key -> { get, set, default }
local O = {
  locked = { default = false,
    get = function() return Saved("locked") == true end,
    set = function(v) local p = Panel() v = v and true or false if p and p.SetLocked then p:SetLocked(v) else SaveRaw("locked", v) end end },
  scale = { default = 1,
    get = function() local p = Panel() return tonumber(p and p._scale or Saved("scale")) or 1 end,
    set = function(v) local p = Panel() if p and p.SetPanelScale then p:SetPanelScale(v) else SaveRaw("scale", v) end end },
  alpha = { default = 0.82,
    get = function() local p = Panel() local k = Kit() return tonumber(p and p._bgAlpha or Saved("alpha")) or (k and k.DEFAULT_ALPHA) or 0.82 end,
    set = function(v) local p = Panel() if p and p.SetBackgroundAlpha then p:SetBackgroundAlpha(v) else SaveRaw("alpha", v) end end },
  combatFade = { default = false,
    get = function() return Saved("combatFade") == true end,
    set = function(v) local p = Panel() local k = Kit() v = v and true or false
      if p and k and k.CombatFade then k.CombatFade(p, v) else SaveRaw("combatFade", v) end end },
  -- (25.10., Daniel: "no background and no frame the default, also with the arrow") on is the unset value now
  plain = { default = true,
    get = function() return CharDB().plain ~= false end,
    set = function(v) if v then CharDB().plain = nil else CharDB().plain = false end if ns.LvdWin then pcall(ns.LvdWin.ApplyPlain, Panel()) end end },
  -- (25.10., Daniel: "for Leveldon an option Arrow instead of the compass in the list; the arrow must be able to lose
  -- its frame and background") Questdon's single direction arrow leads instead of the compass in Leveldon's window and
  -- in the quest list (QuestdonAPI.SetArrowMode keeps the values before). The state is read from the settings.
  -- (31.10.2026, Daniel: "standardmäßig den separaten Pfeil an, damit die Questliste cleaner ist") the arrow is the
  -- default: the compass is on only when switched on (compass == true), unset means the arrow
  arrowOnly = { default = true,
    get = function()
      local a = ns.QD()
      return CharDB().compass ~= true and a ~= nil and a.ArrowMode ~= nil and a.ArrowMode() or false
    end,
    set = function(v)
      local a = ns.QD()
      if not (a and a.SetArrowMode) then print((ns.QDAlone and ns.QDAlone() and L["|cff3fa9f5Level|rdon: this option needs Questdon."] or L["|cff3fa9f5Level|rdon: the arrow option needs Questdon 1.3.11 or newer."])) return end
      v = v and true or false
      if v then CharDB().compass = nil else CharDB().compass = true end
      Redraw()
      a.SetArrowMode(v)
    end },
  arrowPlain = { default = true,
    get = function() local a = ns.QD() if a and a.ArrowPlain then return a.ArrowPlain() end return true end,
    set = function(v)
      local a = ns.QD()
      if a and a.SetArrowPlain then a.SetArrowPlain(v) else print((ns.QDAlone and ns.QDAlone() and L["|cff3fa9f5Level|rdon: this option needs Questdon."] or L["|cff3fa9f5Level|rdon: the arrow option needs Questdon 1.3.11 or newer."])) end
    end },
  compass = { default = false,
    get = function() return CharDB().compass == true end,
    set = function(v) if v then CharDB().compass = true else CharDB().compass = nil end Redraw() end },
  raidMarks = { default = true,
    get = function() return CharDB().raidMarks ~= false end,
    set = function(v) if (CharDB().raidMarks ~= false) ~= (v and true or false) then Cmd("raidmarks") end end },
  hideTracker = { default = true,
    get = function() return CharDB().hideTracker ~= false end,
    set = function(v) if (CharDB().hideTracker ~= false) ~= (v and true or false) then Cmd("tracker") end end },
  bag = { default = true,
    get = function() return CharDB().bag ~= false end,
    set = function(v) CharDB().bag = v and true or false Redraw() end },
  camp = { default = true,
    get = function() return CharDB().camp ~= false end,
    set = function(v) CharDB().camp = v and true or false Redraw() end },
  -- (21.10.) the marks on bag items the route needs later (Bags.lua)
  bagMarks = { default = true,
    get = function() return CharDB().bagMarks ~= false end,
    set = function(v)
      if v then CharDB().bagMarks = nil else CharDB().bagMarks = false end -- (on is the unset value, like plain and compass)
      if ns.LvdBags then pcall(ns.LvdBags.Update) end
    end },
  dungeons = { default = false,
    get = function() return CharDB().dungeons == true end,
    set = function(v) Cmd(v and "dungeons on" or "dungeons off") end },
  solo = { default = false,
    get = function() return CharDB().solo == true end,
    set = function(v) if (CharDB().solo == true) ~= (v and true or false) then Cmd("solo") end end },
  share = { default = true,
    get = function() return not AccDB().shareOff end,
    set = function(v) Cmd(v and "share on" or "share off") end },
  rec = { default = true, -- (31.10.2026, Daniel: "standardweise gerne an") Recorder.lua
    get = function() return not AccDB().recOff end,
    set = function(v) Cmd(v and "rec on" or "rec off") end },
}
ns.LVD_OPTIONS = O -- (tests)

-- (25.10., Daniel: "can players only collect and share data?") one switch: the window and everything Leveldon shows
-- or marks by itself off, the recording and the shared route times on. The values before are kept per character
-- (LeveldonCharDB.recordOnlyPrev) and come back with the second click. /lvd quiet does the same.
local RECORD_ONLY = { rec = true, share = true, raidMarks = false, hideTracker = false, bag = false, camp = false, bagMarks = false }
ns.LVD_RECORD_ONLY = RECORD_ONLY -- (tests)
function ns.RecordOnly() return type(CharDB().recordOnlyPrev) == "table" end
function ns.SetRecordOnly(on)
  if on == nil then on = not ns.RecordOnly() end
  if on == ns.RecordOnly() then return end
  if on then
    local prev = { window = ns.WindowShown and ns.WindowShown() or false }
    for k, v in pairs(RECORD_ONLY) do
      prev[k] = O[k].get()
      if prev[k] ~= v then pcall(O[k].set, v) end
    end
    CharDB().recordOnlyPrev = prev
    if ns.SetWindowShown then pcall(ns.SetWindowShown, false) end
    print(L["|cff3fa9f5Level|rdon only records your run now. /lvd quiet brings the window and your settings back."])
  else
    local prev = CharDB().recordOnlyPrev
    CharDB().recordOnlyPrev = nil
    for k in pairs(RECORD_ONLY) do
      if prev[k] ~= nil and O[k].get() ~= prev[k] then pcall(O[k].set, prev[k]) end
    end
    if ns.SetWindowShown then pcall(ns.SetWindowShown, prev.window ~= false) end
    print(L["|cff3fa9f5Level|rdon: window and settings are back."])
  end
end

-- the options window reads and writes through this table: db[key] is the option's value
local proxy = setmetatable({}, {
  __index = function(_, k) local o = O[k] if o then return o.get() end end,
  __newindex = function(_, k, v) local o = O[k] if o then o.set(v) end end,
})

local SMIN, SMAX = 0.6, 1.6
local PAGES = { { items = {
  { key = "locked", name = "Lock window", tip = "The window can no longer be dragged." },
  { key = "scale", kind = "slider", name = "Size", tip = "Size of the whole window and its text. Ctrl + mouse wheel over the window does the same.", min = SMIN, max = SMAX, step = 0.05 },
  { key = "alpha", kind = "slider", name = "Background opacity", tip = "How dark the window's background is. Shift + mouse wheel over the window does the same.", min = 0, max = 1, step = 0.05 },
  { key = "combatFade", name = "Dim in combat", tip = "The window fades to a little more than a third of its strength while you fight." },
  { key = "plain", name = "No background and frame", tip = "Hides the window's background, its frame and the boxes behind the chapter and the current step: only the text, the compass and the buttons up top stay." },
  { key = "compass", name = "Compass in the current step", tip = "A compass beside the current step that points to its place. With it on, Questdon's own arrow steps aside while Leveldon's window is open." },
  { key = "arrowOnly", name = "Arrow instead of the compass", tip = "Questdon's direction arrow leads you to the step instead of the compass in Leveldon's window and in the quest list. Switch off again and the compass and your earlier arrow settings come back. It changes Questdon's settings for all your characters." },
  { key = "arrowPlain", name = "Arrow: no background and frame", tip = "Hides the plate and frame behind the arrow's text: only the arrow and the writing stay. Same as Questdon's option for the arrow." },
  { key = "raidMarks", name = "Markers over the next NPC", tip = "A marker over the head of the NPC or mob the current step is about." },
  { key = "hideTracker", name = "Hide the game's quest tracker", tip = "Leveldon and Questdon show your quests; the game's own list on the right goes away. A button in the quest log brings it back." },
  { key = "bag", name = "Sleeping bag reminder", tip = "When you rest, a hint to lie in your sleeping bag for 3 minutes: 3 % more XP for 2 hours." },
  { key = "camp", name = "Campfire reminder", tip = "A hint to light a campfire for the camp bonuses when you have the materials." },
  { key = "bagMarks", name = "Mark items the route needs later", tip = "A blue frame on the items in your bags that a later quest of the route still needs, so you do not sell them by mistake. The item's tooltip says which quest." },
  { key = "dungeons", name = "Dungeons in the route", tip = "The route with the dungeons of your faction planned in (levels 1 to 30): their quests before, the run at its level, the turn-ins after. Off: no dungeons." },
  { key = "solo", name = "Solo: no group or escort quests", tip = "Leaves out quests for a group (elite) and escort quests. The route goes on without them." },
  { key = "share", name = "Share route times", tip = "How the route goes for you (times per step, never names) goes to other Leveldon players through Questdon's channel, and theirs to you. It makes the plan better for everyone." },
  { key = "rec", name = "Record your run", tip = "Leveldon writes along how you play the route (steps, times, deaths, walking). Your reports and recordings help to fix the routes." },
} } }

local TOOLS = {
  -- (22.10., Daniel: routes selectable) Lines.lua: the start areas of your faction with hours, quests and reputation
  { "Choose your route", "Open", function() Cmd("line") end, "Your race starts in its own area. From there the route can go on through another start area of your faction (other quests, hours and reputation, e.g. Stormwind for a dwarf). You can change it in the middle of the route." },
  { "Choose your professions", "Open", function() Cmd("profs") end, "Pick the professions the route plans in: their trainers, tools and skill-ups come along the way." },
  { "Report this step", "Open", function() Cmd("report") end, "Quest giver not there, route makes no sense, or a remark: it goes into your recording." },
  { "Export your recordings", "Open", function() Cmd("export") end, "Your recordings and reports as text to copy, for a bug report." },
  { "Reset window position", "Reset", function() local p = Panel() if p and p.ResetPosition then p:ResetPosition() else SaveRaw("pos", nil) end end,
    "Puts Leveldon's window back to its starting place. The key for it: Key Bindings > AddOns > Leveldon." },
  { "Only record your run", "On / off", function() ns.SetRecordOnly() end, "Hides the window and switches off what Leveldon shows or marks by itself (markers over NPCs, bag frames, reminders); the recording and the shared route times stay on, so your run still helps the routes. Click again and the window and your settings are back. Also /lvd quiet." },
  { "Skip this step", "Skip", function() Cmd("next") end, "The route goes on with the next step. Right-click a step for more." },
}

local TABS = {
  { key = "window", title = "Window", pic = "opt_window", icon = "Interface\\Icons\\INV_Misc_Book_09",
    text = "How Leveldon's window looks: background and frame, the compass and the markers.",
    main = { "plain", "compass", "arrowOnly", "arrowPlain" }, more = { "locked", "scale", "alpha", "combatFade", "raidMarks", "hideTracker" },
    tools = { "Reset window position" } },
  { key = "route", title = "Route", pic = "opt_route", icon = "Interface\\Icons\\INV_Misc_Map_01",
    text = "What the route plans in for you: dungeons, group quests, professions and the small XP helpers.",
    main = { "dungeons", "solo", "bag", "camp", "bagMarks" }, tools = { "Choose your route", "Choose your professions" } },
  { key = "share", title = "Sharing and data", pic = "opt_share", icon = "Interface\\Icons\\INV_Misc_GroupNeedMore",
    text = "What Leveldon writes along and shares with other Leveldon players to make the routes better.",
    main = { "share", "rec" }, tools = { "Only record your run", "Report this step", "Export your recordings" } },
  { key = "help", title = "Help", pic = "opt_help", icon = "Interface\\Icons\\INV_Misc_QuestionMark",
    text = "Your route and the commands.", status = true, tools = { "Skip this step" } },
}
ns.LVD_OPTION_TABS = TABS -- (tests)

local HELP = "/lvd: show or hide the window\n/lvd options: this window\n/lvd next, /lvd back: a step on or back\n/lvd report: report this step\n/lvd profs: professions\n/lvd line [name]: the start area of your route\n/lvd dungeons on|off, /lvd solo\n/lvd reset: start the route again from your level"

local win
local function Window()
  if win then return win end
  local a = ns.QD()
  if not (a and a.NewOptionsWindow) then return nil end
  win = a.NewOptionsWindow({
    frameName = "LeveldonOptions",
    wordmark = ns.Style and ns.Style.Wordmark and ns.Style.Wordmark("Level", "don") or "Leveldon",
    media = "Interface\\AddOns\\Leveldon\\Media\\",
    tabs = TABS,
    pages = function() return PAGES end,
    tools = function() return TOOLS end,
    db = function() return proxy end,
    default = function(key) local o = O[key] if o then return o.default end end,
    changed = function() end,
    T = function(s) return L[s] end,
    status = function() return { ns.RouteInfo and ns.RouteInfo() or "" } end,
    help = function() return L[HELP] end,
  })
  return win
end

-- tab: optional tab key; false when Questdon is too old for the window
function ns.OpenOptions(tab)
  local w = Window()
  if not w then
    -- (31.10.2026, Kritikrunde) without Questdon there is no window at all: say that, not "too old"
    if ns.QDAlone and ns.QDAlone() then
      print(L["|cff3fa9f5Level|rdon: the options window comes with Questdon. Without it: /lvd commands."])
    else
      print(L["|cff3fa9f5Level|rdon: the options window needs Questdon 1.3.9 or newer. Until then: /lvd commands."])
    end
    return false
  end
  w.Open(tab)
  return true
end
function ns.ToggleOptions()
  local w = Window()
  if w then w.Toggle() else ns.OpenOptions() end
end
