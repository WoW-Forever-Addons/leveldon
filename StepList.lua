local _, ns = ...
local L = ns.L
local Style = ns.Style

---------------------------------------------------------------------------
-- (0.2.5, Daniel 21.10.: "make the step list scrollable", "two parts: the step you are on at the top, the coming steps
-- below as one block") Refresh (Leveldon.lua) calls Build once per rebuild; this file lists the coming steps: every
-- step still to come (done, outgrown and buys that wait for money left out) as ONE block that scrolls, the next step on
-- top again whenever the step you are on changes. (22.10., Daniel: "Also here is doppelt gemoppelt") the quests to do
-- along here stand in the card on top (Window.lua), not as rows here.
-- No hooks: the rows are DonCore's (Kit.List), the content is rebuilt by Refresh.
---------------------------------------------------------------------------
local SL = {}
ns.LvdList = SL

local LIST_MAX = 80     -- coming steps in the block
local ROW_H = 22        -- a coming step: one line (Kit ListRow compact)
local IDLE_RESET = 60   -- seconds after the last scroll until a rebuild puts the next step on top again

-- collected state, reused from build to build (no new tables per rebuild)
local S = { idx = {}, lvl = {}, n = 0, seen = {}, skv = {}, gen = 0 }
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

function SL.Collect(ctx)
  local steps, cur = ctx.state()
  SL.active = false
  S.gen = S.gen + 1
  S.n = 0
  local total = #steps
  local s0 = steps[cur]
  -- every step still to come; where the plan reaches the next level a divider (S.lvl)
  local nextLv = ctx.level() + 1
  local lastEl = s0 and s0.el
  local n = 0
  for j = cur + 1, total do
    local t = steps[j]
    if t.k == "chapter" or not Skipped(ctx, j, t) then
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
  return S.n
end

---------------------------------------------------------------------------
-- (02.11.2026, StyleKit 2 step 4) The block: Kit.List (only the visible rows exist, the mouse wheel scrolls, a thin gold
-- thumb at the right), as tall as the window leaves it (Style.Content fill: the window's height is the player's, Resize.lua).
-- A step: the symbol of its kind, "Accept: ..." and below it where and at whom, its quest's level on the right in Blizzard's
-- quest colours (blue mark on the next step, the later ones grey; the yards stand only in the card). Where the plan reaches the next level a
-- Kit.Divider ("LEVEL 8 · Plan 1:16"); a chapter as a row of its own. Left click: the quest in Questdon's quest book; Shift:
-- the whole quest to read; right click: the step menu (skip it, skip its quest, report, read).
---------------------------------------------------------------------------
local Kit = LibStub("DonCore-1.0"):Get("Kit", 7)
local MUTED = "|c" .. (Kit.C.muted.hex or "ff8792a8") -- where and at whom, grey behind a step
-- (03.11.2026, Daniel: "es muss ohne [Schleier] lesbar sein") without background a light grey, the dark one vanished in grass
local MUTED_PLAIN = "|cffc4c9d4"
local function Muted() return (ns.LvdWin and ns.LvdWin.Plain and ns.LvdWin.Plain()) and MUTED_PLAIN or MUTED end
local LEVEL_TAG = {}
local items, pool, divs = {}, {}, {}

local function Now() return GetTime and GetTime() or 0 end

local function PlanText(steps, lv)
  local W = ns.LvdWin
  local t = W and W.PlanLevel and W.PlanLevel(steps, lv)
  if type(t) ~= "number" then return nil end
  t = math.floor(t / 60 + 0.5)
  return (L["Plan %s"]):format(("%d:%02d"):format(math.floor(t / 60), t % 60))
end

local function OnClick(it, button)
  local t, ctx = it and it.step, SL.ctx
  if not (t and ctx) then return end
  if button == "RightButton" then
    if ctx.menu then ctx.menu(t) end
  elseif IsShiftKeyDown and IsShiftKeyDown() and t.q and ctx.read then
    ctx.read(t)
  elseif t.q and ctx.open then
    ctx.open(t)
  end
end

local function Wheel(self, delta)
  -- Shift (background opacity) and Ctrl (text size) keep working over the list as over the title bar
  if (IsShiftKeyDown and IsShiftKeyDown()) or (IsControlKeyDown and IsControlKeyDown()) then
    if ns.LeveldonWheel then ns.LeveldonWheel(self, delta) end
    return
  end
  SL.touched = Now()
  self:Scroll(-(tonumber(delta) or 0) * ROW_H)
end

local function ListFrame()
  if SL.f then return SL.f end
  local f = ns.CreateFrame("Frame", nil, UIParent)
  f:SetSize(300, 40)
  local l = Kit.List(f, { onClick = OnClick, zebra = false, plain = true })
  l:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  l:SetScript("OnMouseWheel", Wheel)
  f.list = l
  SL.f, SL.list = f, l
  return f
end
SL.ListFrame = ListFrame -- (tests)

-- the room the window gives the list (Style.Content fill)
local function OnFill(f, w, h)
  f.list:Resize(math.max(1, w - 2 * (ns.LvdWin and ns.LvdWin.INSET or 0)), math.max(1, h))
end

-- one function for every row (no closure per row and build): the whole text, where, what the clicks do
local tipLines = {}
local function RowTip(row)
  local it, ctx = row and row.item, SL.ctx
  local t = it and it.step
  if not (t and ctx) then return nil end
  tipLines[1] = it.tipSub ~= "" and it.tipSub or nil
  local title = t.k == "chapter" and it.title or ctx.text(t, true)
  return title, tipLines, L["Click: the quest  ·  Shift-click: read it  ·  Right-click: more"]
end

local function Item(n)
  local it = pool[n]
  if not it then it = {} pool[n] = it end
  for k in pairs(it) do it[k] = nil end
  return it
end

local function Divider(n, lv, steps)
  local d = divs[n]
  if not d then d = { kind = "divider" } divs[n] = d end
  local tag = LEVEL_TAG[lv]
  if not tag then tag = (L["Level %d"]):format(lv) LEVEL_TAG[lv] = tag end
  d.text, d.right = tag, PlanText(steps, lv)
  return d
end

function SL.Items(ctx)
  local steps = ctx.state()
  for k = #items, 1, -1 do items[k] = nil end
  local nd = 0
  -- (Daniel 02.11.: "die zone unter den nächsten punkten nur, wenn es woanders hin geht") the zone only where the place changes
  local _, cur = ctx.state()
  local lastMap = ctx.place(cur)
  for e = 1, S.n do
    local t = steps[S.idx[e]]
    if t then
      local lv = S.lvl[e]
      if lv then nd = nd + 1 items[#items + 1] = Divider(nd, lv, steps) end
      local it = Item(e)
      it.kind, it.step = "row", t
      if t.k == "chapter" then
        it.title = L["Chapter: "] .. ctx.chapterName(t)
        it.sub = (t.lo and t.hi) and (L["Level %d to %d"]):format(t.lo, t.hi) or nil
        if it.sub then it.title = it.title .. "  " .. Muted() .. it.sub .. "|r" end
        it.titleColor = Kit.C.txGold
        it.iconKind, it.iconPlain = ctx.icon.chapter, true
        lastMap = nil
      else
        -- (03.11.2026, Daniel: "brauchen wir hier wirklich, bei wem wir das als nächstes annehmen abgeben müssen?", chose
        -- "nur Quest") only "Accept: <quest>"; where, at whom and the hints in the tooltip
        it.title = ctx.text(t, true, true, true)
        local full, who = ctx.sub(t)
        local where = (t.m and t.m ~= lastMap) and full or who
        it.sub = where
        if t.m then lastMap = t.m end
        -- (Daniel 02.11.: "die ? ! und schwerter in der leiste ohne hintergrund und kleiner")
        it.iconKind, it.iconPlain = ctx.icon[ctx.kind(t, true)] or ctx.icon.chapter, true
        -- the quest's level on the right; none where the client does not know it (0)
        if (t.k == "accept" or t.k == "do" or t.k == "turnin") and (tonumber(t.lv) or 0) > 0 then
          it.level, it.badgeRight = t.lv, true
        end
      end
      -- (Daniel 02.11.: "gerne kleiner, das wirkt fast so als könnte man es auswählen oder jetzt machen") small quiet rows
      -- without a colour mark: only the card is the step to do now
      it.compact, it.h = true, ROW_H
      it.tipSub, it.sub = it.sub, nil
      -- (Daniel 02.11.: "yards angaben brauchen wir doch nur bei dem aktuellen punkt", "quests werden sehr früh abgeschnitten")
      -- no yards here (the card has them), the right column only as wide as the level: the title gets the rest
      it.rightWidth = it.level and 34 or 0
      it.tooltipFn = RowTip
      items[#items + 1] = it
    end
  end
  return items
end

-- the block under the card; it fills the window's height
function SL.Block(panel, ctx, width)
  local f = ListFrame()
  local steps, cur = ctx.state()
  SL.ctx = ctx
  local key = steps[cur]
  local reset = SL.key ~= key -- a new step: the next one is on top again
  -- scrolled ahead and left alone for a minute (the mouse not over the list): back to the next step
  if not reset and SL.touched and Now() - SL.touched > IDLE_RESET and not (MouseIsOver and MouseIsOver(f)) then
    reset, SL.touched = true, nil
  end
  SL.key = key
  f.list:SetPlain(ns.LvdWin and ns.LvdWin.Plain() or false)
  f.list:SetEmpty(L["Route finished"])
  f.list:SetItems(SL.Items(ctx), reset)
  ns.LvdWin.Put(panel, f, 1, { fill = true, onFill = OnFill })
  SL.active = true
  return true
end

-- the titles the block shows now (tests)
function SL.Texts()
  local out = {}
  local l = SL.list
  if SL.active and l then
    for _, r in ipairs(l:Rows()) do
      local it = r.item
      if it and it.step then out[#out + 1] = it.title or "" end
    end
  end
  return out
end

-- Refresh's call: collect and the block
function SL.Build(panel, ctx, width)
  SL.Collect(ctx)
  SL.Block(panel, ctx, width)
  return true
end

-- (23.10., /lvd mem) the list's parts by name (inner within "window build")
if ns.Track then
  SL.Collect = ns.Track("list collect", SL.Collect)
  SL.Block = ns.Track("list block", SL.Block)
end
