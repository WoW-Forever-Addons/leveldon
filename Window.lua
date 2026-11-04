local _, ns = ...
local L = ns.L
local Style = ns.Style
local Kit = LibStub("DonCore-1.0"):Get("Kit", 7)

---------------------------------------------------------------------------
-- (02.11.2026, StyleKit 2 step 4, docs/layout_2026-11-02/leveldon/, approved by Daniel) The window in the Don style, made of
-- DonCore's blocks (Kit), like Questdon's quest list. Refresh (Leveldon.lua) puts it together from the top:
--   Run    (option, off by default) 24 px: time played on this route, ahead (green) or behind (red) of the plan, when the
--          next level is due, the last level-ups as small columns (Kit.Spark; not under 300 px)
--   Head   the chapter: Kit.Ring with its progress, the name, "Level a to b · step n of m"; with the option an XP bar with
--          the plan's mark (Kit.SegmentBar)
--   Done   the last two finished steps, dimmed with a green tick (Kit.DoneRow)
--   Card   the step you are on (Kit.FocusCard): symbol, "STEP 23 · DO · [7]", the title, the objectives with count and bar,
--          the way, what to do along here, up to three hints; Questdon's compass on the right only with the option
--   List   the coming steps (StepList.lua, Kit.List): it takes the rest of the window's height
--   Foot   "Step n of m", a gold bar, the chapter's percent
-- The window's height is the player's (the handle at the bottom right, Resize.lua): it never changes by itself, the card grows
-- downwards and the list gets what is left (Daniel 02.11.: "Höhe frei ziehbar" instead of "number of coming steps").
-- Opacity: Shift + mouse wheel over the title bar, down to no background and no frame.
---------------------------------------------------------------------------
local W = {}
ns.LvdWin = W
local C, S = Kit.C, Kit.SIZE
local COMPASS = 54
local RUN_H, HEAD_H, HEAD_XP_H, FOOT_H = 24, 44, 52, 24
local NARROW = 300 -- (Daniel 02.11.) under this width: no columns in the run line, no report and read buttons up top

local function DB() return LeveldonCharDB or {} end
-- (31.10.2026, Daniel: "Leveldon standardmäßig wie Questdon mit dem separaten Pfeil, damit die Questliste cleaner ist")
-- the compass in the current step only when switched on (true); unset or false: the separate arrow leads
local function CompassOn() return DB().compass == true end
local function API() return ns.QD() end
-- (02.11.2026, Daniel: "beides wie mockup abschaltbar, aber standard aus") the run line and the XP bar
function W.RunOn() return DB().runLine == true end
function W.XPOn() return DB().xpBar == true end
function W.Plain() return DB().plain ~= false end -- (25.10.) on unless switched off
-- (03.11.2026, Daniel: "der aktuelle step ist zu groß, zone und koordinaten weg. yards steht ja schon im pfeil von donmap")
-- the card has no way line any more (the place stays in the tooltip and on the map)
W.SHOW_WAY = false

---------------------------------------------------------------------------
-- Speedrun: time on the route
---------------------------------------------------------------------------
local function Run()
  local db = DB()
  if type(db.run) ~= "table" then db.run = {} end
  return db.run
end

-- the plan's time "now": the planned time of the last step before the current one
function W.PlanNow(steps, cur)
  for j = math.min(cur - 1, #steps), 1, -1 do
    local s = steps[j]
    if s and type(s.t) == "number" then return s.t end
  end
  return 0
end
-- when the plan reaches level lv: the first step whose level after it (el) gets there
function W.PlanLevel(steps, lv)
  for _, s in ipairs(steps) do
    if type(s.el) == "number" and type(s.t) == "number" and s.el >= lv then return s.t end
  end
end

local function Clock(sec)
  sec = math.max(0, math.floor((sec or 0) + 0.5))
  return ("%d:%02d:%02d"):format(math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60)
end
local function Delta(sec)
  local a = math.floor(math.abs(sec) + 0.5)
  local txt = ("%d:%02d"):format(math.floor(a / 60), a % 60)
  if a >= 3600 then txt = ("%d:%02d:%02d"):format(math.floor(a / 3600), math.floor(a % 3600 / 60), a % 60) end
  return (sec <= 0 and "-" or "+") .. txt
end
W.Clock, W.Delta = Clock, Delta -- (tests)

-- time counts while you are logged in; the first time it starts where the plan has you
-- (12.10., Daniel: "I have only played 32 min") it stops after IDLE seconds without doing anything (standing,
-- chatting, away) and goes on with the next move, fight, cast, loot or talk to an NPC
local IDLE = 120
local ticker = ns.CreateFrame("Frame")
local acc, lastActive = 0, nil
function W.Active() lastActive = GetTime and GetTime() or 0 end
-- (13.10., Daniel's error "Window.lua:101: attempt to perform numeric conversion on a secret number value") in
-- combat the game hands out the speed (and other unit values) as secret values: never compute with one; a value we
-- cannot read counts as busy
local function Busy(f, ...)
  if not f then return false end
  local ok, v = pcall(f, ...)
  if not ok then return true end
  if issecretvalue and issecretvalue(v) then return true end
  if type(v) == "number" then return v > 0 end
  return v and true or false
end
function W.Idle()
  local now = GetTime and GetTime() or 0
  if UnitIsAFK then
    local ok, afk = pcall(UnitIsAFK, "player")
    if ok and afk == true then return true end
  end
  if Busy(UnitAffectingCombat, "player") or Busy(GetUnitSpeed, "player") or Busy(UnitCastingInfo, "player")
    or Busy(UnitChannelInfo, "player") then
    lastActive = now
    return false
  end
  return lastActive ~= nil and now - lastActive > IDLE
end
ticker:SetScript("OnUpdate", function(_, dt)
  if not LeveldonCharDB or not ns.LeveldonSteps then return end
  local r = LeveldonCharDB.run
  if type(r) ~= "table" or type(r.t) ~= "number" then return end
  if lastActive == nil then W.Active() end
  acc = acc + (tonumber(dt) or 0)
  if acc >= 1 then
    local ok, idle = pcall(W.Idle)
    if not (ok and idle) then r.t = r.t + acc end
    acc = 0
  end
end)
for _, e in ipairs({ "PLAYER_STARTED_MOVING", "PLAYER_REGEN_DISABLED", "UNIT_SPELLCAST_START", "LOOT_OPENED", "GOSSIP_SHOW",
  "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "MERCHANT_SHOW", "TRAINER_SHOW", "TAXIMAP_OPENED", "PLAYER_XP_UPDATE" }) do
  pcall(ticker.RegisterEvent, ticker, e)
end
ticker:SetScript("OnEvent", function() W.Active() end)
local function StartRun(steps, cur)
  local r = Run()
  if type(r.t) ~= "number" then r.t = W.PlanNow(steps, cur) r.splits = {} end
  return r
end
W.StartRun = StartRun
function W.LevelUp(level)
  local steps, cur = ns.LeveldonSteps and ns.LeveldonSteps(), ns.LeveldonCur and ns.LeveldonCur()
  if type(steps) ~= "table" or not cur then return end
  local r = StartRun(steps, cur)
  local plan = W.PlanLevel(steps, level)
  if plan then
    r.splits = r.splits or {}
    r.splits[#r.splits + 1] = { lv = level, d = r.t - plan }
    while #r.splits > 12 do table.remove(r.splits, 1) end
  end
end
local ev = ns.CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, _, level) pcall(W.LevelUp, tonumber(level)) end)
pcall(ev.RegisterEvent, ev, "PLAYER_LEVEL_UP")

---------------------------------------------------------------------------
-- The parts: own frames, made once, handed to the panel with Style.Content on every build
---------------------------------------------------------------------------
local parts = {}
W.parts = parts -- (tests)

local function Part(key, h)
  local f = ns.CreateFrame("Frame", nil, UIParent)
  f:SetSize(300, h)
  f:Hide()
  parts[key] = f
  return f
end

-- (Daniel 02.11.: with background and frame the parts went over the gold frame) every part stands W.INSET px inside the
-- window's edges; Refresh hands them the width without that
W.INSET = 2
function W.Put(panel, f, h, opts)
  opts = opts or {}
  opts.inset, opts.gapBefore = false, 0
  local holder = Style.Content(panel, f, h, opts)
  if holder then
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", holder, "TOPLEFT", W.INSET, 0)
    f:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -W.INSET, 0)
  end
  return holder
end
local function Put(panel, f, h)
  W.Put(panel, f, h)
  return h
end

---------------------------------------------------------------------------
-- Run line
---------------------------------------------------------------------------
local function RunPart()
  if parts.run then return parts.run end
  local f = Part("run", RUN_H)
  f.bg = Kit.Fill(f, C.panel)
  f.line = Kit.Tex(f, "ARTWORK", C.divider)
  f.line:SetPoint("BOTTOMLEFT") f.line:SetPoint("BOTTOMRIGHT") f.line:SetHeight(1)
  f.clock = f:CreateTexture(nil, "ARTWORK")
  f.clock:SetSize(12, 12)
  f.clock:SetPoint("LEFT", f, "LEFT", 8, 0)
  Style.SetIcon(f.clock, "timer")
  f.time = Kit.Text(f, "sub", C.muted)
  f.delta = Kit.Text(f, "sub", C.green)
  f.next = Kit.Text(f, "sub", C.muted)
  f.spark = Kit.Spark(f, { h = 12 })
  f.spark:SetPoint("RIGHT", f, "RIGHT", -8, 0)
  -- (12.10., Daniel: "I don't get the clock up there") what the line says, on the mouse
  if f.EnableMouse then f:EnableMouse(true) end
  f:SetScript("OnEnter", function(self)
    Kit.Tooltip(self, L["Speedrun line"], {
      L["Your time on this route. It stops when you do nothing for 2 minutes."],
      L["Green: ahead of the plan. Red: behind it."],
      L["Bars: your last level-ups, up ahead of the plan, down behind it."],
    }, L["Options > Window: speedrun line"])
  end)
  f:SetScript("OnLeave", function(self) Kit.HideTooltip(self) end)
  return f
end

-- returns the height it took (0: off, or the route has no planned times)
function W.Run(panel, steps, cur, width)
  if not W.RunOn() or type(steps) ~= "table" or #steps == 0 then return 0 end
  -- routes built before 12.10. have no planned times: no line
  if W._timed ~= steps then
    W._timed, W._hasT = steps, false
    for _, s in ipairs(steps) do if type(s.t) == "number" then W._hasT = true break end end
  end
  if not W._hasT then return 0 end
  local r = StartRun(steps, cur)
  local f = RunPart()
  width = width or 300
  local d = r.t - W.PlanNow(steps, cur)
  f.time:SetText(Clock(r.t))
  f.delta:SetText((d <= 0 and L["%s ahead"] or L["%s behind"]):format(Delta(d):sub(2)))
  Kit.TextColor(f.delta, d <= 0 and C.green or C.red)
  local lv = UnitLevel and UnitLevel("player") or 1
  local plan = W.PlanLevel(steps, lv + 1)
  -- (12.10.) how long the plan needs from here to the next level, not a time on the clock
  local left = plan and (plan - W.PlanNow(steps, cur))
  f.next:SetText(not left and "" or left < 60 and L["Level %d: almost there"]:format(lv + 1)
    or L["Level %d in about %d min"]:format(lv + 1, math.floor(left / 60 + 0.5)))
  -- the last level-ups as columns: green ahead of the plan, red behind it
  local vals, cols = W._sparkV or {}, W._sparkC or {}
  W._sparkV, W._sparkC = vals, cols
  for k = #vals, 1, -1 do vals[k], cols[k] = nil, nil end
  if width >= NARROW then
    for i, s in ipairs(r.splits or {}) do
      vals[i] = math.max(1, math.abs(s.d or 0))
      cols[i] = (s.d or 0) <= 0 and C.green or C.red
    end
  end
  f.spark:SetValues(vals, cols)
  if #vals > 0 then f.spark:Show() else f.spark:Hide() end
  local x = 24
  f.time:ClearAllPoints() f.time:SetPoint("LEFT", f, "LEFT", x, 0)
  Kit.Fit(f.time, 60)
  x = x + math.min(Kit.TextWidth(f.time), 60) + 6
  f.delta:ClearAllPoints() f.delta:SetPoint("LEFT", f, "LEFT", x, 0)
  local room = width - x - 8 - (#vals > 0 and f.spark:Width() + 8 or 0)
  Kit.Fit(f.delta, math.max(20, math.min(Kit.TextWidth(f.delta), room)))
  x = x + math.min(Kit.TextWidth(f.delta), room) + 6
  f.next:ClearAllPoints() f.next:SetPoint("LEFT", f, "LEFT", x, 0)
  Kit.Fit(f.next, math.max(1, width - x - 8 - (#vals > 0 and f.spark:Width() + 8 or 0)))
  if width - x < 30 then f.next:Hide() else f.next:Show() end
  return Put(panel, f, RUN_H)
end

---------------------------------------------------------------------------
-- Head: the chapter
---------------------------------------------------------------------------
local function HeadPart()
  if parts.head then return parts.head end
  local f = Part("head", HEAD_H)
  f.bg = Kit.Fill(f, C.panel)
  f.line = Kit.Tex(f, "ARTWORK", C.divider)
  f.line:SetPoint("BOTTOMLEFT") f.line:SetPoint("BOTTOMRIGHT") f.line:SetHeight(1)
  -- (Daniel 02.11.: "der kreis mit % sollte durchgängig sein") a closed ring, not single dots
  f.ring = Kit.Ring(f, 36, { solid = true })
  f.ring:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -4)
  f.title = Kit.Text(f, "title", C.hero)
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 52, -7)
  f.sub = Kit.Text(f, "sub", C.muted)
  f.sub:SetPoint("TOPLEFT", f, "TOPLEFT", 52, -24)
  f.bar = Kit.SegmentBar(f, { ticks = 4 })
  f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", 52, -40)
  if f.EnableMouse then f:EnableMouse(true) end
  f:SetScript("OnEnter", function(self)
    local lines = {}
    if Kit.FullText(self.title) then lines[#lines + 1] = Kit.FullText(self.title) end
    lines[#lines + 1] = self.sub:GetText()
    if self.xpTip then lines[#lines + 1] = self.xpTip end
    Kit.Tooltip(self, self.name, lines)
  end)
  f:SetScript("OnLeave", function(self) Kit.HideTooltip(self) end)
  return f
end

-- d: name, lo, hi, step, total, progress (0..1), plan (the planned level now, e.g. 6.4)
function W.Head(panel, d, width)
  local f = HeadPart()
  width = width or 300
  local pct = math.floor((d.progress or 0) * 100 + 0.5)
  f.ring:SetValue(pct, 100)
  f.name = d.name or ""
  f.title:SetText(Kit.Upper(f.name))
  Kit.Fit(f.title, math.max(20, width - 52 - 8))
  f.sub:SetText(L["Level %d to %d  ·  step %d of %d"]:format(d.lo or 0, d.hi or 0, d.step or 0, d.total or 0))
  Kit.Fit(f.sub, math.max(20, width - 52 - 8))
  local h = HEAD_H
  f.xpTip = nil
  if W.XPOn() then
    h = HEAD_XP_H
    local lv = UnitLevel and UnitLevel("player") or 1
    local xp, mx = UnitXP and UnitXP("player") or 0, UnitXPMax and UnitXPMax("player") or 0
    local v = (tonumber(mx) or 0) > 0 and (tonumber(xp) or 0) / mx or 0
    f.bar:Layout(math.max(20, width - 52 - 8))
    f.bar:SetValue(v)
    local plan = tonumber(d.plan)
    local mark = nil
    if plan then mark = plan < lv and 0 or plan >= lv + 1 and 1 or (plan - lv) end
    f.bar:SetMark(mark)
    f.bar:Show()
    f.xpTip = plan and (L["Plan: level %.1f now"]):format(plan) or nil
  else
    f.bar:Hide()
  end
  f.ring:ClearAllPoints()
  f.ring:SetPoint("LEFT", f, "LEFT", 8, 0)
  f:SetHeight(h)
  return Put(panel, f, h)
end

---------------------------------------------------------------------------
-- A line under the head: the preview of an untested chapter (yellow)
---------------------------------------------------------------------------
function W.Note(panel, text, kind, width)
  local f = parts.note or Part("note", 22)
  if not f.hint then
    f.bg = Kit.Fill(f, C.yellowBg)
    f.hint = Kit.Hint(f)
    f.hint:SetPoint("LEFT", f, "LEFT", 8, 0)
  end
  f.hint:SetHint(text, kind or "warn")
  f.hint:Layout(math.max(20, (width or 300) - 16))
  return Put(panel, f, 22)
end

---------------------------------------------------------------------------
-- Done: the last finished steps
---------------------------------------------------------------------------
function W.Done(panel, list, width)
  if not list or #list == 0 then return 0 end
  local f = parts.done or Part("done", S.done)
  f.rows = f.rows or {}
  local n = math.min(2, #list)
  for i = 1, n do
    local r = f.rows[i]
    if not r then
      r = Kit.DoneRow(f)
      f.rows[i] = r
    end
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(i - 1) * S.done)
    r:SetSize(width or 300, S.done)
    r.plain = W.Plain()
    r:SetItem(list[i])
    r:Show()
  end
  for i = n + 1, #f.rows do f.rows[i]:Hide() end
  return Put(panel, f, n * S.done)
end

---------------------------------------------------------------------------
-- Card: the step you are on
---------------------------------------------------------------------------
local function CardPart()
  if parts.card then return parts.card end
  local f = Part("card", 60)
  f.card = Kit.FocusCard(f, { side = COMPASS })
  f.card:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  -- (31.10.2026, Leistungsprüfung B10) 10 times a second with the compass, twice without (only the way's yards). The card
  -- hangs in the window (Style.Content sets its parent), so it stops with the hidden or collapsed window.
  local elapsed = 0
  f:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + (tonumber(dt) or 0)
    if elapsed < (W.compass and f.card.sideOn and 0.1 or 0.5) then return end
    elapsed = 0
    pcall(W.CompassTick)
  end)
  return f
end
W.CardPart = CardPart -- (tests)

local function Yards(d)
  if type(d) ~= "number" then return nil end
  return (L["%d yd"]):format(math.floor(d + 0.5))
end

-- the way's line: the place and how far ("Mulgore · 45.8, 57.2 · 340 yd")
local function WayText()
  local w = W._way
  if not w then return nil end
  local text = w.text
  local yd
  local st = W._state
  if st and type(st.distShort) == "string" and st.distShort ~= "" then yd = st.distShort
  else
    local a = API()
    if a and a.DistanceTo and w.m then
      local ok, d = pcall(a.DistanceTo, w.m, w.x / 100, w.y / 100)
      if ok then yd = Yards(d) end
    end
  end
  if yd then text = text .. "  ·  " .. yd end
  return text
end

function W.CompassTick()
  local f = parts.card
  if not f then return end
  W._state = nil
  local cp = W.compass
  if cp and f.card.sideOn then
    local a = API()
    local st = a and a.ArrowState and a.ArrowState() or {}
    W._state = st
    local facing = GetPlayerFacing and GetPlayerFacing() or nil
    if type(facing) ~= "number" then facing = nil end
    cp:Arrived(st.seal)
    if st.needle and type(st.angle) == "number" and facing then
      -- (Daniel 12.10.: "the arrow towards the quest target, the minimap shows where to walk") the target itself
      local bearing = type(st.bearing) == "number" and st.bearing or (-st.angle - facing)
      cp:Point(bearing, facing, st.nearness)
    else
      cp:Point(nil, facing)
    end
  end
  if not W.SHOW_WAY then return end
  local t = WayText()
  if t and t ~= W._wayShown then W._wayShown = t f.card:SetWay(t) end
end

-- data: the FocusCard's data (Kit.FocusCard SetData) plus way = { text, m, x, y }; returns the height
function W.Card(panel, data, width)
  local f = CardPart()
  local card = f.card
  -- the compass: Questdon's (or DonMap's) in the card's side room, only with the option
  if CompassOn() and not W.compass then
    local a = API()
    W.compass = a and a.NewCompass and a.NewCompass(card.side, COMPASS) or nil
    if W.compass then W.compass:SetPoint("TOP", card.side, "TOP", 0, 0) end
  end
  card:SetSide(CompassOn() and W.compass ~= nil)
  W._way = data.way
  W._wayShown = nil
  data.way = nil
  card:SetData(data)
  data.way = W._way and W._way.text or nil
  card.data.way = W.SHOW_WAY and (WayText() or data.way) or nil
  card:SetPlain(W.Plain())
  local h = card:Layout(width or 300)
  f:SetHeight(h)
  W._wayShown = card.data.way
  Put(panel, f, h)
  W.CompassTick()
  return h
end

---------------------------------------------------------------------------
-- Foot: where you are in the route
---------------------------------------------------------------------------
function W.Foot(panel, step, total, chapter, width)
  local f = parts.foot
  if not f then
    f = Part("foot", FOOT_H)
    f.bg = Kit.Fill(f, C.panel)
    f.line = Kit.Tex(f, "ARTWORK", C.divider)
    f.line:SetPoint("TOPLEFT") f.line:SetPoint("TOPRIGHT") f.line:SetHeight(1)
    f.left = Kit.Text(f, "sub", C.muted)
    f.left:SetPoint("LEFT", f, "LEFT", 8, 0)
    f.right = Kit.Text(f, "sub", C.txGold, "RIGHT")
    f.right:SetPoint("RIGHT", f, "RIGHT", -20, 0) -- room for the size handle
    f.bar = Kit.ProgressBar(f)
  end
  width = width or 300
  f.left:SetText((L["Step %d of %d"]):format(step or 0, total or 0))
  f.right:SetText((L["chapter %d%%"]):format(math.floor((chapter or 0) * 100 + 0.5)))
  local lw = math.min(Kit.TextWidth(f.left), math.floor(width * 0.4))
  local rw = math.min(Kit.TextWidth(f.right), math.floor(width * 0.3))
  Kit.Fit(f.left, math.max(1, lw))
  Kit.Fit(f.right, math.max(1, rw))
  local bw = width - 8 - lw - 12 - 12 - rw - 20
  if bw >= 30 then
    f.bar:ClearAllPoints()
    f.bar:SetPoint("LEFT", f, "LEFT", 8 + lw + 12, 0)
    f.bar:Layout(bw)
    f.bar:SetValue((total or 0) > 0 and (step or 0) / total or 0)
    f.bar:Show()
  else
    f.bar:Hide()
  end
  return Put(panel, f, FOOT_H)
end

---------------------------------------------------------------------------
-- Without background and frame: the panel's chrome and the parts' fills go, lines, marks and texts stay (variant A)
---------------------------------------------------------------------------
-- (17.10., Daniel: "an option to hide background and borders") /lvd options "No background and frame"
function W.ApplyPlain(panel)
  local plain = W.Plain()
  if panel and panel.SetChromeHidden and (panel.IsChromeHidden and panel:IsChromeHidden()) ~= plain then panel:SetChromeHidden(plain) end
  for _, f in pairs(parts) do
    if f.bg then if plain then f.bg:Hide() else f.bg:Show() end end
  end
  if parts.card then parts.card.card:SetPlain(plain) end
  for _, r in ipairs(parts.done and parts.done.rows or {}) do r.plain = plain Kit.Refresh(r) end
  local l = ns.LvdList and ns.LvdList.list
  if l and (l.plain and true or false) ~= plain then l:SetPlain(plain) end
end

---------------------------------------------------------------------------
-- After a build: Questdon's arrow steps aside while our compass shows the way; Questdon's list docks under the window
---------------------------------------------------------------------------
function W.Finish(panel)
  W.ApplyPlain(panel)
  local a = API()
  local on = panel and panel:IsShown() and not (panel.IsCollapsed and panel:IsCollapsed()) and CompassOn()
    and parts.card ~= nil and W.compass ~= nil
  if a and a.SetGuideCompass and W._guide ~= on then
    W._guide = on
    a.SetGuideCompass(on)
  end
  -- (0.1.8, Daniel 12.10.: both windows open, "dock it") Questdon's quest list hangs under this window; (02.11.2026, Daniel:
  -- "questdons fenster frei beweglich machen, und standardweise aus, das hindert nur") only with the option, off by default
  local frame = panel and panel:IsShown() and DB().dock == true and panel or nil
  if a and a.SetGuideFrame and W._dock ~= frame then
    W._dock = frame
    a.SetGuideFrame(frame)
  end
end

-- (23.10., /lvd mem) the window's parts by name (inner within "window build")
if ns.Track then
  W.Run = ns.Track("win run", W.Run)
  W.Head = ns.Track("win head", W.Head)
  W.Card = ns.Track("win card", W.Card)
  W.Finish = ns.Track("win finish", W.Finish)
end

-- Shift + mouse wheel over the title bar: the background's opacity (down to nothing, frame included)
function W.WheelAlpha(panel, delta)
  if not (IsShiftKeyDown and IsShiftKeyDown()) or not panel then return false end
  local a = panel._bgAlpha or Style.DEFAULT_ALPHA
  a = math.max(0, math.min(1, a + (delta > 0 and 0.1 or -0.1)))
  panel:SetBackgroundAlpha(a)
  return true
end
