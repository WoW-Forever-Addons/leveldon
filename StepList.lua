local _, ns = ...
local L = ns.L
local Style = ns.Style

---------------------------------------------------------------------------
-- (0.2.5, Daniel 21.10.: "make the step list scrollable with a slider at the side", "two parts: the step you are
-- on and what else is to do in this area at the top, the coming steps below as one block")
-- Refresh (Leveldon.lua) calls Build once per rebuild; this file puts the coming steps together:
--   Area   the steps right after the current one that are in the same area (within AREA_YD yards, steps without
--          a place pass through, a place elsewhere ends the stretch), and the steps of quests in your log that are
--          in this area, wherever they stand ahead: up to AREA_MAX rows, "Also here". They are not repeated below.
--   Block  all other coming steps as ONE block in a frame of its own: as many rows as the window shows (the
--          handle at the bottom right, Resize.lua), the rest scrolls: mouse wheel, a slider at the right
--          (Questdon's kit has no scroll template, the slider is built here), a click on its track pages.
--          The next step is on top again whenever the step you are on changes.
-- Done steps are not listed: they leave the block as they did in the old list (Daniel 12.10.: "the done steps
-- from before are too much"); the footer and the chapter bar say how far you are.
-- No hooks: the rows are our own frames, the content is rebuilt by Refresh.
---------------------------------------------------------------------------
local SL = {}
ns.LvdList = SL
-- (22.10., Daniel: "Also here is doppelt gemoppelt: on top what I do here now, below the further steps, scrollable")
-- the area rows are off: the station on top shows the step and the quests to do along here, every coming step is
-- in the block. SL.AREA = true brings the old "Also here" rows back (tests).
SL.AREA = false

local B = Style.BOOK or {}
local WHITE = "Interface\\Buttons\\WHITE8x8"
local GOLD = B.gold or { 0.86, 0.71, 0.42 }
local GOLD_L = B.goldLight or { 0.97, 0.87, 0.60 }
local HINT = B.textHint or { 0.58, 0.57, 0.66 }
local SECOND = B.textSecondary or { 0.80, 0.76, 0.68 }

local ROW = 18          -- one coming step, in window units (Resize.lua: dragging down by this adds one)
local PAD = 2
local BAR_W = 6         -- the slider
local BAR_GAP = 4
local ICON = 14
local TEXT_X = 28
local TAG_W = 56        -- room for the level tag ("Level 12") at the right
local AREA_YD = 150     -- yards around the current place that count as "here"
local AREA_MAX = 4
local LOOK = 60         -- steps looked at ahead for the area
local LIST_MAX = 80     -- coming steps in the block
local MAX_ROWS = 12     -- Resize.lua: at most 12 coming steps
local IDLE_RESET = 60   -- seconds after the last scroll until a rebuild puts the next step on top again

-- collected state, reused from build to build (no new tables per rebuild)
local S = { idx = {}, lvl = {}, n = 0, area = {}, na = 0, mark = {}, seen = {}, skv = {}, gen = 0, here = {} }
SL.S = S -- (tests)

---------------------------------------------------------------------------
-- Collecting
---------------------------------------------------------------------------
-- done, outgrown, or a buy that waits for money: not a coming step (cached per build, a step is asked once)
local function Skipped(ctx, j, t)
  if S.seen[j] == S.gen then return S.skv[j] end
  local v = ctx.done(j) or ctx.outgrown(t) or (t.k == "buy" and ctx.buyWaits(j)) or false
  S.seen[j], S.skv[j] = S.gen, v
  return v
end

local function AddArea(j)
  S.na = S.na + 1
  S.area[S.na] = j
  S.mark[j] = S.gen
end

-- a quest whose open objectives the station lists already ("Along here", Leveldon.lua AlongHere): its do step is
-- not a row of the area as well
local function InStation(q)
  if not q then return false end
  if q == ns._alongQ then return true end
  for _, q2 in ipairs(ns._alongMore or {}) do if q2 == q then return true end end
  return false
end

-- how many area rows the window has room for: the coming steps the window shows (the handle at the bottom
-- right), at most AREA_MAX
local function AreaCap()
  return math.max(1, math.min(AREA_MAX, tonumber(ns.nextShown) or 3))
end

function SL.Collect(ctx)
  local steps, cur = ctx.state()
  SL.active = false
  S.gen = S.gen + 1
  S.n, S.na = 0, 0
  local total = #steps
  local s0 = steps[cur]
  local here = S.here
  here.m, here.x, here.y = ctx.place(cur)
  local cap = AreaCap()
  if SL.AREA and here.m and here.x then
    local last = math.min(total, cur + LOOK)
    -- 1) the stretch after this step that stays in the area
    for j = cur + 1, last do
      local t = steps[j]
      if t.k == "chapter" then break end
      if t.m and t.x and not Skipped(ctx, j, t) then
        if not ns.Within(t, here, AREA_YD) then break end
        if not (t.k == "do" and InStation(t.q)) then
          AddArea(j)
          if S.na >= cap then break end
        end
      end
    end
    -- 2) steps of quests in your log that are in this area, wherever they stand ahead
    if S.na < cap then
      for j = cur + 1, last do
        local t = steps[j]
        if t.k == "chapter" then break end
        if S.mark[j] ~= S.gen and t.q and (t.k == "do" or t.k == "turnin") and t.m and t.x and ctx.inLog(t.q)
            and not (t.k == "do" and InStation(t.q)) and not Skipped(ctx, j, t) and ns.Within(t, here, AREA_YD) then
          AddArea(j)
          if S.na >= cap then break end
        end
      end
      for a = 2, S.na do -- route order (at most four)
        local v, b = S.area[a], a - 1
        while b >= 1 and S.area[b] > v do S.area[b + 1] = S.area[b] b = b - 1 end
        S.area[b + 1] = v
      end
    end
  end
  -- the block: everything else that is still to come; a gold diamond where the plan reaches the next level
  local nextLv = ctx.level() + 1
  local lastEl = s0 and s0.el
  local n = 0
  for j = cur + 1, total do
    local t = steps[j]
    if S.mark[j] ~= S.gen and (t.k == "chapter" or not Skipped(ctx, j, t)) then
      n = n + 1
      S.idx[n] = j
      local lv = false
      if lastEl and lastEl >= nextLv then lv = nextLv nextLv = math.floor(lastEl) + 1 end
      S.lvl[n] = lv
      if n >= LIST_MAX then break end
    end
    if t.el then lastEl = t.el end
  end
  S.n = n
  return S.n, S.na
end

---------------------------------------------------------------------------
-- The block's frame: rows, rail, slider
---------------------------------------------------------------------------
local function CursorY(f)
  local _, y = GetCursorPosition()
  local s = f.GetEffectiveScale and f:GetEffectiveScale() or 1
  if type(s) ~= "number" or s <= 0 then s = 1 end
  return (tonumber(y) or 0) / s
end

local Draw

function SL.SetOffset(f, o)
  f = f or SL.f
  if not (f and f.count) then return false end
  local max = math.max(0, f.count - f.visible)
  o = math.max(0, math.min(max, math.floor((tonumber(o) or 0) + 0.5)))
  if o == f.offset then return false end
  f.offset = o
  Draw(f)
  return true
end

local function Now() return GetTime and GetTime() or 0 end

local function OnWheel(self, delta)
  local f = self.owner or self
  -- Shift (background opacity) and Ctrl (text size) keep working over the list as over the title bar
  if (IsShiftKeyDown and IsShiftKeyDown()) or (IsControlKeyDown and IsControlKeyDown()) then
    if ns.LeveldonWheel then ns.LeveldonWheel(self, delta) end
    return
  end
  f.touched = Now()
  SL.SetOffset(f, f.offset + ((tonumber(delta) or 0) > 0 and -1 or 1))
end

-- the wheel over the window's body (not only over the list) scrolls the list too
local function PanelWheel(_, delta)
  local f = SL.f
  if f and SL.active then OnWheel(f, delta) end
end

local function DragUpdate(self)
  local f = self.owner
  if not (f and f.dragY) then return end
  local max = f.count - f.visible
  if max <= 0 or not f.range or f.range <= 0 then return end
  SL.SetOffset(f, f.dragOff + (f.dragY - CursorY(f)) / f.range * max)
end

local function ThumbDown(self, button)
  if button and button ~= "LeftButton" then return end
  local f = self.owner
  f.dragY, f.dragOff, f.touched = CursorY(f), f.offset, Now()
  self:SetScript("OnUpdate", DragUpdate)
  if self.tex then self.tex:SetVertexColor(GOLD_L[1], GOLD_L[2], GOLD_L[3], 0.9) end
end

local function ThumbUp(self)
  local f = self.owner
  if f then f.dragY = nil end
  self:SetScript("OnUpdate", nil)
  if self.tex then self.tex:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.55) end
end

local function TrackDown(self, button)
  if button and button ~= "LeftButton" then return end
  local f = self.owner
  local y = CursorY(f)
  local top, bottom = f.thumb:GetTop(), f.thumb:GetBottom()
  if type(top) == "number" and y > top then SL.SetOffset(f, f.offset - f.visible)
  elseif type(bottom) == "number" and y < bottom then SL.SetOffset(f, f.offset + f.visible) end
end

local function BarTip(self)
  if self.tex and not (self.owner and self.owner.dragY) then self.tex:SetVertexColor(GOLD_L[1], GOLD_L[2], GOLD_L[3], 0.8) end
  if Style.Tooltip then
    Style.Tooltip(self, L["Coming steps"], { L["Mouse wheel or drag the slider: scroll the coming steps."] })
  end
end

local function BarLeave(self)
  if self.tex and not (self.owner and self.owner.dragY) then self.tex:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.55) end
  if Style.HideTooltip then Style.HideTooltip(self) end
end

local function RowClick(self, button)
  local t, ctx = self.step, SL.ctx
  if t and t.q and ctx and ctx.open and button ~= "RightButton" then ctx.open(t) end
end

local function RowEnter(self)
  if self.hl then self.hl:Show() end
  local full = self.text and Style.FullText and Style.FullText(self.text)
  if full and Style.Tooltip then Style.Tooltip(self, full) end
end

local function RowLeave(self)
  if self.hl then self.hl:Hide() end
  if Style.HideTooltip then Style.HideTooltip(self) end
end

local function Tex(parent, layer)
  local t = parent:CreateTexture(nil, layer)
  t:SetTexture(WHITE)
  return t
end

local function NewRow(f, i)
  local r = CreateFrame("Button", nil, f)
  r.owner = f
  r:SetHeight(ROW)
  if r.RegisterForClicks then r:RegisterForClicks("AnyUp") end
  if r.EnableMouseWheel then r:EnableMouseWheel(true) end
  r:SetScript("OnMouseWheel", OnWheel)
  r:SetScript("OnClick", RowClick)
  r:SetScript("OnEnter", RowEnter)
  r:SetScript("OnLeave", RowLeave)
  r.hl = Tex(r, "BACKGROUND")
  r.hl:SetVertexColor(1, 1, 1, 0.07)
  r.hl:SetAllPoints(r)
  r.hl:Hide()
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(ICON, ICON)
  r.icon:SetPoint("LEFT", r, "LEFT", 8, 0)
  r.dia = Tex(r, "OVERLAY")
  r.dia:SetSize(9, 9)
  r.dia:SetVertexColor(GOLD_L[1], GOLD_L[2], GOLD_L[3], 1)
  r.dia:SetPoint("CENTER", r, "TOPLEFT", 8 + math.floor(ICON / 2), 0)
  if r.dia.SetRotation then pcall(r.dia.SetRotation, r.dia, math.pi / 4) end
  r.dia:Hide()
  r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.text:SetPoint("LEFT", r, "LEFT", TEXT_X, 0)
  if r.text.SetJustifyH then r.text:SetJustifyH("LEFT") end
  if r.text.SetWordWrap then r.text:SetWordWrap(false) end
  r.tag = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.tag:SetPoint("RIGHT", r, "RIGHT", -4, 0)
  if r.tag.SetJustifyH then r.tag:SetJustifyH("RIGHT") end
  r.tag:SetTextColor(GOLD_L[1], GOLD_L[2], GOLD_L[3], 1)
  r.tag:Hide()
  r.pos, r.room = i, nil
  f.rows[i] = r
  return r
end

local function ListFrame()
  local f = SL.f
  if f then return f end
  f = CreateFrame("Frame", nil, UIParent)
  f:SetSize(300, ROW * 3 + PAD * 2)
  f.owner = f
  f.rows = {}
  f.offset, f.count, f.visible = 0, 0, 0
  f.bg = Tex(f, "BACKGROUND")
  f.bg:SetVertexColor(0, 0, 0, 0.16)
  f.bg:SetAllPoints()
  -- the path: one thin line through the icons, grey like the coming steps of the old list
  f.rail = Tex(f, "BORDER")
  f.rail:SetVertexColor(1, 1, 1, 0.18)
  f.rail:SetWidth(2)
  f.rail:SetPoint("TOPLEFT", f, "TOPLEFT", 8 + math.floor(ICON / 2) - 1, -PAD)
  f.rail:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8 + math.floor(ICON / 2) - 1, PAD)
  if f.EnableMouseWheel then f:EnableMouseWheel(true) end
  f:SetScript("OnMouseWheel", OnWheel)
  -- the slider: a track and a thumb to drag
  f.track = CreateFrame("Button", nil, f)
  f.track.owner = f
  f.track:SetWidth(BAR_W)
  f.track:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -PAD)
  if f.track.EnableMouseWheel then f.track:EnableMouseWheel(true) end
  f.track:SetScript("OnMouseWheel", OnWheel)
  f.track:SetScript("OnMouseDown", TrackDown)
  f.track.bg = Tex(f.track, "BACKGROUND")
  f.track.bg:SetVertexColor(1, 1, 1, 0.10)
  f.track.bg:SetAllPoints()
  f.thumb = CreateFrame("Button", nil, f)
  f.thumb.owner = f
  f.thumb:SetWidth(BAR_W)
  if f.thumb.SetFrameLevel and f.GetFrameLevel then f.thumb:SetFrameLevel((tonumber(f:GetFrameLevel()) or 1) + 3) end
  if f.thumb.EnableMouseWheel then f.thumb:EnableMouseWheel(true) end
  f.thumb:SetScript("OnMouseWheel", OnWheel)
  f.thumb:SetScript("OnMouseDown", ThumbDown)
  f.thumb:SetScript("OnMouseUp", ThumbUp)
  f.thumb:SetScript("OnHide", ThumbUp)
  f.thumb:SetScript("OnEnter", BarTip)
  f.thumb:SetScript("OnLeave", BarLeave)
  f.thumb.tex = Tex(f.thumb, "ARTWORK")
  f.thumb.tex:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.55)
  f.thumb.tex:SetAllPoints()
  SL.f = f
  return f
end

local function Bar(f, scroll)
  if not scroll then
    f.track:Hide()
    f.thumb:Hide()
    f.range, f.thumbH, f.thumbPos = 0, 0, 0
    return
  end
  local trackH = f.visible * ROW
  local max = f.count - f.visible
  local th = math.min(trackH, math.max(14, math.floor(trackH * f.visible / f.count + 0.5)))
  local range = trackH - th
  local pos = max > 0 and math.floor(range * f.offset / max + 0.5) or 0
  f.track:SetHeight(trackH)
  f.track:Show()
  f.thumb:SetHeight(th)
  f.thumb:ClearAllPoints()
  f.thumb:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -(PAD + pos))
  f.thumb:Show()
  f.range, f.thumbH, f.thumbPos = range, th, pos
end

local LEVEL_TAG = {}
function Draw(f)
  local ctx = f.ctx
  local steps = ctx.state()
  local scroll = f.count > f.visible
  local room = scroll and (BAR_W + BAR_GAP) or 0
  local budget = math.max(40, (f.width or 300) - TEXT_X - room - 6)
  for i = 1, MAX_ROWS do
    local r = f.rows[i]
    if i <= f.visible then
      r = r or NewRow(f, i)
      if r.room ~= room then
        r.room = room
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(PAD + (i - 1) * ROW))
        r:SetPoint("TOPRIGHT", f, "TOPRIGHT", -room, -(PAD + (i - 1) * ROW))
      end
      local e = f.offset + i
      local t = steps[S.idx[e]]
      if t then
        local isCh = t.k == "chapter"
        local text = isCh and (L["Chapter: "] .. ctx.chapterName(t)) or ctx.text(t, true)
        local lv = S.lvl[e]
        local tagW = lv and TAG_W or 0
        r.step = t
        r.text:SetText(text)
        local c = isCh and GOLD or (e == 1 and SECOND or HINT)
        r.text:SetTextColor(c[1], c[2], c[3], 1)
        if Style.FitText then Style.FitText(r.text, budget - tagW) end
        r.icon:SetTexture(ctx.icon[isCh and "chapter" or ctx.kind(t, true)] or ctx.icon.chapter)
        if t.k == "accept" or t.k == "turnin" then r.icon:SetTexCoord(0, 1, 0, 1) else r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        if lv then
          local tag = LEVEL_TAG[lv]
          if not tag then tag = (L["Level %d"]):format(lv) LEVEL_TAG[lv] = tag end
          r.tag:SetText(tag)
          r.tag:Show()
          -- (22.10., Daniel: "the level up slipped in between") no diamond on the row border, the tag says it
          r.dia:Hide()
        else
          r.tag:Hide()
          r.dia:Hide()
        end
        r:Show()
      else
        r.step = nil
        r:Hide()
      end
    elseif r then
      r.step = nil
      r:Hide()
    end
  end
  Bar(f, scroll)
end
SL.Draw = Draw -- (tests)

-- the block under the area rows; returns its height (0: nothing coming)
function SL.Block(panel, ctx, width)
  if S.n == 0 then
    if SL.f then SL.f.count, SL.f.visible = 0, 0 end
    return 0
  end
  local f = ListFrame()
  local steps, cur = ctx.state()
  local vis = math.max(1, math.min(MAX_ROWS, tonumber(ns.nextShown) or 3, S.n))
  local key = steps[cur]
  if f.key ~= key then f.key, f.offset = key, 0 end -- a new step: the next one is on top again
  -- scrolled ahead and left alone for a minute (the mouse not over the list): back to the next step
  if f.offset > 0 and f.touched and Now() - f.touched > IDLE_RESET and not (MouseIsOver and MouseIsOver(f)) then f.offset = 0 end
  if not panel._lvdWheel and panel.EnableMouseWheel then
    panel._lvdWheel = true
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", PanelWheel)
  end
  f.ctx, f.count, f.visible, f.width = ctx, S.n, vis, width
  SL.ctx = ctx
  f.offset = math.max(0, math.min(f.count - vis, f.offset))
  local h = vis * ROW + PAD * 2
  f:SetHeight(h)
  Draw(f)
  Style.Content(panel, f, h, { inset = false, gapBefore = 4 })
  SL.active = true
  return h
end

-- the texts the block shows now (tests)
function SL.Texts()
  local out = {}
  local f = SL.f
  if SL.active and f then
    for i = 1, f.visible do
      local r = f.rows[i]
      if r and r.step and r.text then out[#out + 1] = r.text:GetText() or "" end
    end
  end
  return out
end

-- the rows "Also here" under the current step
function SL.AreaRows(panel, ctx)
  if S.na == 0 then return 0 end
  local steps = ctx.state()
  Style.Row(panel):SetText(L["Also here"], B.gold or "textSecondary"):SetGapBefore(6)
  for k = 1, S.na do
    local t = steps[S.area[k]]
    local row = Style.Row(panel):SetText(ctx.text(t, true), B.textSecondary or "textSecondary")
      :SetIcon(ctx.icon[ctx.kind(t, true)] or ctx.icon.chapter, false, not (t.k == "accept" or t.k == "turnin") or nil)
      :SetOnClick(t.q and function() ctx.open(t) end or nil)
    if ns.LvdWin then ns.LvdWin.Line(row, "next") end
  end
  return S.na
end

-- Refresh's call: collect, the area rows, the block (an error before the rows are built: the old list is the fallback)
function SL.Build(panel, ctx, width)
  SL.Collect(ctx)
  SL.AreaRows(panel, ctx)
  SL.Block(panel, ctx, width)
  return true
end
