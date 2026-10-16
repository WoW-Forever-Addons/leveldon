local _, ns = ...
local L = ns.L
local Style = ns.Style

---------------------------------------------------------------------------
-- (0.1.8, Daniel 12.10.: "the chapter path, the compass in the current station, the speedrun line on
-- top", in the frame of Questdon's quest book) The parts of the window Refresh (Leveldon.lua) puts
-- together:
--   Run       a thin speedrun line: time played on this route, ahead (green) or behind (red) of the
--             plan, the last level-ups as small bars, when the next level is due (button: stopwatch)
--   Banner    the chapter: a golden ring with its progress, the name, levels, step, and the XP bar
--             with a gold mark where the plan has you now
--   Line      the path: a thin line through the icons, gold behind you, grey ahead
--   Done      the last finished stations, dimmed
--   Milestone a gold diamond where the plan reaches the next level
--   Station   under the current step: its objectives as blocks, the place, and Questdon's compass
--             (QuestdonAPI.NewCompass): Questdon's own arrow then draws nothing (SetGuideCompass)
-- Opacity: Shift + mouse wheel over the title bar, down to no background and no frame.
---------------------------------------------------------------------------
local W = {}
ns.LvdWin = W
Style.ICONS.lvdRead = Style.ICONS.lvdRead or {
  atlas = { "Campaign-QuestLog-LoreBook", "questlog-questtypeicon-lore" }, file = "Interface\\Icons\\INV_Misc_Book_09" }
Style.ICONS.lvdTimer = Style.ICONS.lvdTimer or {
  atlas = { "auctionhouse-icon-clock", "Mobile-QuestIcon" }, file = "Interface\\Icons\\INV_Misc_PocketWatch_01" }
local B = Style.BOOK or {}
local WHITE = "Interface\\Buttons\\WHITE8x8"
local GOLD = B.gold or { 0.86, 0.71, 0.42 }
local GOLD_L = B.goldLight or { 0.97, 0.87, 0.60 }
local CREAM = B.textPrimary or { 0.96, 0.92, 0.84 }
local SECOND = B.textSecondary or { 0.80, 0.76, 0.68 }
local HINT = B.textHint or { 0.58, 0.57, 0.66 }
local GREEN, RED, VIOLET = { 0.40, 0.85, 0.45 }, { 0.94, 0.42, 0.37 }, { 0.58, 0.40, 0.92 }
local COMPASS = 54

local function DB() return LeveldonCharDB or {} end
local function API() return rawget(_G, "QuestdonAPI") end

local function Font(parent, size, color, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  if size and fs.SetFont then pcall(function() local p = fs:GetFont() if p then fs:SetFont(p, size, "") end end) end
  if justify and fs.SetJustifyH then fs:SetJustifyH(justify) end
  if fs.SetWordWrap then fs:SetWordWrap(false) end
  if type(color) == "table" and fs.SetTextColor then fs:SetTextColor(color[1], color[2], color[3], 1) end
  return fs
end
local function Color(fs, c) if type(c) == "table" and fs and fs.SetTextColor then fs:SetTextColor(c[1], c[2], c[3], 1) end end
local function Tex(parent, layer, c, a)
  local t = parent:CreateTexture(nil, layer)
  t:SetTexture(WHITE)
  if type(c) == "table" then t:SetVertexColor(c[1], c[2], c[3], a or 1) end
  return t
end

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
local ticker = CreateFrame("Frame")
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
local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, _, level) pcall(W.LevelUp, tonumber(level)) end)
pcall(ev.RegisterEvent, ev, "PLAYER_LEVEL_UP")

local runFrame
local function RunFrame()
  if runFrame then return runFrame end
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetSize(300, 26)
  f.bg = Tex(f, "BACKGROUND", { 0.05, 0.06, 0.14 }, 0.55)
  f.bg:SetAllPoints()
  f.time = Font(f, 15, CREAM, "LEFT")
  f.time:SetPoint("LEFT", f, "LEFT", 6, 0)
  f.delta = Font(f, 13, GREEN, "LEFT")
  f.delta:SetPoint("LEFT", f.time, "RIGHT", 8, 0)
  f.next = Font(f, 10, HINT, "RIGHT")
  f.next:SetPoint("RIGHT", f, "RIGHT", -6, 0)
  f.bars = {}
  f.mid = Tex(f, "BORDER", { 1, 1, 1 }, 0.15)
  f.mid:SetHeight(1)
  -- (12.10., Daniel: "I don't get the clock up there") what the line says, on the mouse
  if f.EnableMouse then f:EnableMouse(true) end
  f:SetScript("OnEnter", function(self)
    Style.Tooltip(self, L["Speedrun line"], {
      L["Your time on this route. It stops when you do nothing for 2 minutes."],
      L["Green: ahead of the plan. Red: behind it."],
      L["Bars: your last level-ups, up ahead of the plan, down behind it."],
    }, L["/lvd run: off  ·  /lvd run reset: start again"])
  end)
  f:SetScript("OnLeave", function(self) Style.HideTooltip(self) end)
  runFrame = f
  return f
end

function W.Run(panel, steps, cur)
  -- (12.10., Daniel: "let's do it") off unless you switch it on (/lvd run, the stopwatch button)
  if DB().runLine ~= true or type(steps) ~= "table" or #steps == 0 then return end
  -- routes built before 12.10. have no planned times: no line
  if W._timed ~= steps then
    W._timed, W._hasT = steps, false
    for _, s in ipairs(steps) do if type(s.t) == "number" then W._hasT = true break end end
  end
  if not W._hasT then return end
  local r = StartRun(steps, cur)
  local f = RunFrame()
  local d = r.t - W.PlanNow(steps, cur)
  f.time:SetText(Clock(r.t))
  f.delta:SetText(Delta(d))
  Color(f.delta, d <= 0 and GREEN or RED)
  local lv = UnitLevel and UnitLevel("player") or 1
  local plan = W.PlanLevel(steps, lv + 1)
  -- (12.10.) how long the plan needs from here to the next level, not a time on the clock
  local left = plan and (plan - W.PlanNow(steps, cur))
  f.next:SetText(not left and "" or left < 60 and L["Level %d: almost there"]:format(lv + 1)
    or L["Level %d in about %d min"]:format(lv + 1, math.floor(left / 60 + 0.5)))
  -- the last level-ups: small bars, up = ahead of the plan, down = behind
  for _, b in ipairs(f.bars) do b:Hide() end
  local splits = r.splits or {}
  local maxd = 60
  for _, s in ipairs(splits) do maxd = math.max(maxd, math.abs(s.d or 0)) end
  local x0 = 150
  f.mid:ClearAllPoints()
  f.mid:SetPoint("LEFT", f, "LEFT", x0, 0)
  f.mid:SetWidth(math.max(1, #splits * 6))
  for i, s in ipairs(splits) do
    local b = f.bars[i]
    if not b then b = Tex(f, "ARTWORK", GREEN, 1) f.bars[i] = b end
    local h = math.max(2, math.floor(9 * math.abs(s.d or 0) / maxd + 0.5))
    local ahead = (s.d or 0) <= 0
    b:SetVertexColor((ahead and GREEN or RED)[1], (ahead and GREEN or RED)[2], (ahead and GREEN or RED)[3], 1)
    b:ClearAllPoints()
    b:SetSize(4, h)
    if ahead then b:SetPoint("BOTTOMLEFT", f, "LEFT", x0 + (i - 1) * 6, 0) else b:SetPoint("TOPLEFT", f, "LEFT", x0 + (i - 1) * 6, 0) end
    b:Show()
  end
  Style.Content(panel, f, 26, { inset = false })
end

---------------------------------------------------------------------------
-- Banner: ring, chapter, step, XP with the plan's mark
---------------------------------------------------------------------------
local banner
local function BannerFrame()
  if banner then return banner end
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetSize(300, 46)
  f.bg = Tex(f, "BACKGROUND", { 0.20, 0.15, 0.35 }, 0.35)
  f.bg:SetAllPoints()
  f.ring = f:CreateTexture(nil, "ARTWORK")
  f.ring:SetSize(38, 38)
  f.ring:SetPoint("LEFT", f, "LEFT", 6, 0)
  f.ring:SetTexture("Interface\\AddOns\\Questdon\\Media\\BookRing")
  f.pct = Font(f, 10, GOLD_L, "CENTER")
  f.pct:SetPoint("CENTER", f.ring, "CENTER", 0, 0)
  f.title = Font(f, 14, GOLD_L, "LEFT")
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 52, -6)
  f.sub = Font(f, 10, SECOND, "LEFT")
  f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -2)
  f.xpBack = Tex(f, "BORDER", { 1, 1, 1 }, 0.10)
  f.xpBack:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 52, 6)
  f.xpBack:SetHeight(4)
  f.xp = Tex(f, "ARTWORK", VIOLET, 1)
  f.xp:SetPoint("TOPLEFT", f.xpBack, "TOPLEFT", 0, 0)
  f.xp:SetHeight(4)
  f.mark = Tex(f, "OVERLAY", GOLD_L, 1)
  f.mark:SetSize(2, 10)
  banner = f
  return f
end

function W.Banner(panel, title, lo, hi, step, total, progress, planEl, width)
  local f = BannerFrame()
  f.pct:SetText(("%d%%"):format(math.floor((progress or 0) * 100 + 0.5)))
  f.title:SetText(title or "")
  f.sub:SetText(L["Level %d to %d  ·  step %d of %d"]:format(lo or 0, hi or 0, step or 0, total or 0))
  local w = math.max(60, (width or 300) - 52 - 10)
  f.title:SetWidth(w)
  if Style.FitText then Style.FitText(f.title, w) end
  f.xpBack:SetWidth(w)
  local xp, max = UnitXP and UnitXP("player"), UnitXPMax and UnitXPMax("player")
  local frac = (type(xp) == "number" and type(max) == "number" and max > 0) and xp / max or 0
  f.xp:SetWidth(math.max(1, w * math.min(1, frac)))
  local lv = UnitLevel and UnitLevel("player") or 1
  if type(planEl) == "number" then
    local p = planEl - lv
    if p < 0 then p = 0 elseif p > 1 then p = 1 end
    f.mark:ClearAllPoints()
    f.mark:SetPoint("CENTER", f.xpBack, "LEFT", w * p, 0)
    f.mark:Show()
  else
    f.mark:Hide()
  end
  Style.Content(panel, f, 46, { inset = false })
end

---------------------------------------------------------------------------
-- The path: a line through the icons
---------------------------------------------------------------------------
function W.Begin(panel)
  for _, it in ipairs(panel._items or {}) do
    if it._lvdLine then it._lvdLine:Hide() end
    if it._lvdDiamond and it.icon and it.icon.SetRotation then pcall(it.icon.SetRotation, it.icon, 0) it._lvdDiamond = nil end
  end
end

function W.Line(row, kind)
  if not row then return row end
  local t = row._lvdLine
  if not t then
    t = row:CreateTexture(nil, "BACKGROUND")
    t:SetTexture(WHITE)
    row._lvdLine = t
  end
  local S = Style.SPACING or {}
  local x = (S.padX or 8) + (row._indent or 0) + math.floor((S.icon or 14) / 2) - 1
  t:ClearAllPoints()
  t:SetPoint("TOPLEFT", row, "TOPLEFT", x, kind == "first" and -6 or 0)
  t:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", x, kind == "last" and 6 or 0)
  t:SetWidth(2)
  local c, a = GOLD, 0.85
  if kind == "next" or kind == "last" then c, a = { 1, 1, 1 }, 0.18 end
  t:SetVertexColor(c[1], c[2], c[3], a)
  t:Show()
  return row
end

-- (Daniel 12.10.: "the current 'Do: ...' bigger and more striking") the step you are on: larger, light gold
function W.Now(row)
  if not (row and row.text) then return row end
  local ok, path = pcall(row.text.GetFont, row.text)
  if ok and path then pcall(row.text.SetFont, row.text, path, 15, "") end
  pcall(row.text.SetTextColor, row.text, GOLD_L[1], GOLD_L[2], GOLD_L[3], 1)
  row._lvdNow = true
  return row
end

function W.Done(panel, text, icon)
  local row = Style.Row(panel):SetText(text, HINT)
  if icon then row:SetIcon(icon) end
  if row.icon and row.icon.SetDesaturated then pcall(row.icon.SetDesaturated, row.icon, true) end
  W.Line(row, "done")
  return row
end

function W.Milestone(panel, level)
  local row = Style.Row(panel):SetText(L["Level %d"]:format(level), GOLD_L)
  row:SetIcon(WHITE)
  if row.icon then
    if row.icon.SetVertexColor then row.icon:SetVertexColor(GOLD_L[1], GOLD_L[2], GOLD_L[3], 1) end
    if row.icon.SetRotation then pcall(row.icon.SetRotation, row.icon, math.pi / 4) end
    if row.icon.SetSize then row.icon:SetSize(9, 9) end
    row._lvdDiamond = true
  end
  W.Line(row, "next")
  return row
end

---------------------------------------------------------------------------
-- The current station: objectives as blocks, the place, the compass
---------------------------------------------------------------------------
local station
local function StationFrame()
  if station then return station end
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetSize(300, COMPASS + 20)
  f.bg = Tex(f, "BACKGROUND", { 0.35, 0.66, 0.94 }, 0.07)
  f.bg:SetAllPoints()
  local a = API()
  f.compass = a and a.NewCompass and a.NewCompass(f, COMPASS) or nil
  if f.compass then f.compass:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -2) end
  f.dist = Font(f, 12, GOLD_L, "CENTER")
  if f.compass then f.dist:SetPoint("TOP", f.compass, "BOTTOM", 0, 0) else f.dist:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -4) end
  f.dist:SetWidth(COMPASS + 20)
  f.lines, f.pips = {}, {}
  local elapsed = 0
  f:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + (tonumber(dt) or 0)
    if elapsed < 0.05 then return end
    elapsed = 0
    pcall(W.CompassTick)
  end)
  station = f
  return f
end

function W.CompassTick()
  local f = station
  if not (f and f.compass) then return end
  local a = API()
  local st = a and a.ArrowState and a.ArrowState() or {}
  local facing = GetPlayerFacing and GetPlayerFacing() or nil
  if type(facing) ~= "number" then facing = nil end
  f.compass:Arrived(st.seal)
  if st.needle and type(st.angle) == "number" and facing then
    -- (Daniel 12.10.: "the arrow towards the quest target, the minimap shows where to walk") the target itself
    local bearing = type(st.bearing) == "number" and st.bearing or (-st.angle - facing)
    f.compass:Point(bearing, facing, st.nearness)
  else
    f.compass:Point(nil, facing)
  end
  local text = type(st.distText) == "string" and st.distText or ""
  -- (Questdon review 5) Questdon's own parts ("240 yards" / "the way around") like on its card; a text that does
  -- not start with the distance ("In the objective area, nearest spot 52 yards") goes whole to the hint line under the
  -- compass (it was empty: the narrow distance line has no room for it)
  local short, way = st.distShort, st.distWay
  if type(short) ~= "string" then
    short = text:match("^[%d%.,]+%s*[^%s,]*") -- (12.10.) "39 yards" without the comma before the way hint
    way = text:match("^[%d%.,]+%s*%S*,%s*(.+)$")
    if not short then short, way = "", text end
  end
  f.dist:SetText(short or "")
  if f.way then f.way:SetText(type(way) == "string" and way or "") end
end

local function Line(f, i)
  local fs = f.lines[i]
  if not fs then fs = Font(f, 11, SECOND, "LEFT") f.lines[i] = fs end
  fs:Show()
  return fs
end

-- objs: { { text, done, have, need } }, where: "Mulgore · 45.8, 57.2"; returns the height
-- along: { title, objs } a quest to do along here (Daniel 12.10.: "it gets lost, written so small")
function W.Station(panel, objs, where, width, along)
  local f = StationFrame()
  for _, fs in ipairs(f.lines) do fs:Hide() end
  for _, t in ipairs(f.pips) do t:Hide() end
  local textW = (width or 300) - (f.compass and COMPASS + 26 or 16)
  -- (Daniel 12.10.: "the middle part with the count could sit more in the middle") the block centred on the
  -- compass: its height first, then the top
  local need = 12 + (where and 14 or 0)
  local cnt = 0
  for _, o in ipairs(objs or {}) do
    if cnt >= 4 then break end
    cnt = cnt + 1
    need = need + 14 + ((o.need and o.need > 1 and not o.done) and 8 or 0)
  end
  local alongN = 0
  if along then
    need = need + 18
    for _, o in ipairs(along.objs or {}) do
      if alongN < 3 and not o.done then
        alongN = alongN + 1
        need = need + 14 + ((o.need and o.need > 1) and 8 or 0)
      end
    end
  end
  local full = math.max(need + 6, f.compass and COMPASS + 18 or 20)
  local y, n, np = math.max(4, math.floor((full - need) / 2)), 0, 0
  local function Pip()
    np = np + 1
    local t = f.pips[np]
    if not t then t = Tex(f, "ARTWORK", GOLD_L, 1) f.pips[np] = t end
    t:Show()
    return t
  end
  local function Objective(o, color)
    n = n + 1
    local fs = Line(f, n)
    fs:SetWidth(textW)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -y)
    fs:SetText(o.text or "")
    Color(fs, o.done and GREEN or (color or SECOND))
    if Style.FitText then Style.FitText(fs, textW - 18) end
    y = y + 14
    if o.need and o.need > 1 and not o.done then
      local have = math.max(0, math.min(o.need, o.have or 0))
      local bw = textW - 18
      if o.need <= 12 then
        local gap = 2
        local w = (bw - gap * (o.need - 1)) / o.need
        for k = 1, o.need do
          local t = Pip()
          t:ClearAllPoints()
          t:SetPoint("TOPLEFT", f, "TOPLEFT", 26 + (k - 1) * (w + gap), -y)
          t:SetSize(math.max(1, w), 5)
          if k <= have then t:SetVertexColor(0.62, 0.81, 1, 1) else t:SetVertexColor(1, 1, 1, 0.12) end
        end
      else
        local back = Pip()
        back:ClearAllPoints() back:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -y) back:SetSize(bw, 5) back:SetVertexColor(1, 1, 1, 0.12)
        if have > 0 then
          local fill = Pip()
          fill:ClearAllPoints() fill:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -y) fill:SetSize(math.max(1, bw * have / o.need), 5)
          fill:SetVertexColor(0.62, 0.81, 1, 1)
        end
      end
      y = y + 8
    end
  end
  local shown = 0
  for _, o in ipairs(objs or {}) do
    if shown >= 4 then break end
    shown = shown + 1
    Objective(o)
  end
  -- the quest to do along here: a gold line, then its open objectives with their blocks
  if along then
    if not f.along then f.along = Font(f, 12, GOLD, "LEFT") end
    f.along:SetWidth(textW)
    f.along:ClearAllPoints()
    f.along:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -(y + 4))
    f.along:SetText((L["Along here: %s"]):format(along.title or "?"))
    if Style.FitText then Style.FitText(f.along, textW) end
    f.along:Show()
    y = y + 18
    local k = 0
    for _, o in ipairs(along.objs or {}) do
      if k >= alongN then break end
      if not o.done then k = k + 1 Objective(o, CREAM) end
    end
  elseif f.along then
    f.along:Hide()
  end
  if where then
    n = n + 1
    local fs = Line(f, n)
    fs:SetWidth(textW)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -y)
    fs:SetText(where)
    Color(fs, HINT)
    y = y + 14
  end
  if not f.way then f.way = Font(f, 10, { 0.96, 0.84, 0.48 }, "LEFT") end
  f.way:SetWidth(textW)
  f.way:ClearAllPoints()
  f.way:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -y)
  y = y + 12
  local h = math.max(y + 2, f.compass and COMPASS + 18 or 20)
  Style.Content(panel, f, h, { inset = false })
  W.CompassTick()
  return h
end

---------------------------------------------------------------------------
-- After a build: Questdon's arrow steps aside while our compass shows the way
---------------------------------------------------------------------------
function W.Finish(panel)
  local a = API()
  local on = panel and panel:IsShown() and not (panel.IsCollapsed and panel:IsCollapsed()) and DB().compass ~= false
    and station ~= nil and station.compass ~= nil
  if a and a.SetGuideCompass and W._guide ~= on then
    W._guide = on
    a.SetGuideCompass(on)
  end
  -- (0.1.8, Daniel 12.10.: both windows open, "dock it") Questdon's quest list hangs under this window
  local frame = panel and panel:IsShown() and panel or nil
  if a and a.SetGuideFrame and W._dock ~= frame then
    W._dock = frame
    a.SetGuideFrame(frame)
  end
end

-- Shift + mouse wheel over the title bar: the background's opacity (down to nothing, frame included)
function W.WheelAlpha(panel, delta)
  if not (IsShiftKeyDown and IsShiftKeyDown()) or not panel then return false end
  local a = panel._bgAlpha or Style.DEFAULT_ALPHA
  a = math.max(0, math.min(1, a + (delta > 0 and 0.1 or -0.1)))
  panel:SetBackgroundAlpha(a)
  return true
end
