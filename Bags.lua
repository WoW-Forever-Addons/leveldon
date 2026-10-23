local _, ns = ...

---------------------------------------------------------------------------
-- (0.2.5, Daniel 21.10.: "items in the bags that later quests of the route still need and that could be sold: mark
-- them with a coloured frame or a button on the item")
-- Leveldon has known these items for a while (ROUTE.keep, ns.KeepFor: the chat line when you loot one, the tooltip
-- line, the list at the vendor). This file puts a mark on the item in the bag: a blue frame and a small blue square
-- in the corner of the item button. The tooltip says for which quest (the tooltip line of Leveldon.lua).
-- No hooks: the marks are our own frames, children of the game's item buttons (they do not take clicks). They are
-- put on when
--   * the bags change (BAG_UPDATE_DELAYED), a quest is taken, handed in or abandoned, a vendor opens, you log in
--   * a bag window opens or closes or shows another bag: a light check twice a second whether the bag windows
--     are the same as the last time (no allocations), and an own check when a mark is shown again
-- Which buttons: the game's bag windows (ContainerFrame1 to 13 with their item buttons, the combined bag window
-- when the client has one) and the bank (BankFrameItem1 to 28). Other bag addons draw their own buttons: only the
-- ones named in BG.Prefixes are found (guesses by their button names, they cannot be tested without the addon);
-- for the others a hook on the addon's item update, or an adapter by its author, would be needed.
-- Off with /lvd options (Route, "Mark items the route needs later").
---------------------------------------------------------------------------
local BG = {}
ns.LvdBags = BG

local BLUE = { 0.25, 0.66, 0.96 } -- the blue of the tooltip line "Leveldon: needed later for ..."
local WHITE = "Interface\\Buttons\\WHITE8x8"
local POLL = 0.5                  -- seconds between two looks at the bag windows
local FRAMES = 13                 -- NUM_CONTAINER_FRAMES
local BANK_SLOTS = 28
local EDGE = 2
local MOD = 2147483629
local FIRST_ADDON_BUTTON -- name of the first button of the first bag addon, built below

-- bag addons: button names, "<prefix><number>" (names guessed from the addons, not tested: see above)
BG.Prefixes = { "BagnonContainerItem", "BagnonItemSlot" }
FIRST_ADDON_BUTTON = BG.Prefixes[1] .. "1"

local S = { shown = {}, n = 0, sig = nil, pending = false, updates = 0, price = {}, need = {} }
BG.S = S -- (tests)

local function DB() return LeveldonCharDB or {} end
function BG.Enabled() return DB().bagMarks ~= false end

-- names built once (a poll twice a second must not build strings)
local FRAME_NAMES, ITEM_NAMES, BANK_NAMES, PREFIX_NAMES = {}, {}, {}, {}
for i = 1, FRAMES do FRAME_NAMES[i] = "ContainerFrame" .. i end
for j = 1, BANK_SLOTS do BANK_NAMES[j] = "BankFrameItem" .. j end
local function ItemName(i, j)
  local row = ITEM_NAMES[i]
  if not row then row = {} ITEM_NAMES[i] = row end
  local n = row[j]
  if not n then n = FRAME_NAMES[i] .. "Item" .. j row[j] = n end
  return n
end

local function ItemID(bag, slot)
  local C = C_Container
  local f = (C and C.GetContainerItemID) or GetContainerItemID
  if not f then return nil end
  return f(bag, slot)
end

-- vendor price: an item that cannot be sold needs no mark; unknown (not in the client's cache yet) counts as sellable
local function Sellable(id)
  local p = S.price[id]
  if p == nil then
    local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if info then
      local _, _, _, _, _, _, _, _, _, _, price = info(id)
      if type(price) == "number" then S.price[id] = price p = price end
    end
  end
  return p == nil or p > 0
end

-- Is the quest still one the route will play? Not when its steps are outgrown (grey for your level, not in your log):
-- the route skips it, nobody needs its item. A quest that has no step in the route at all counts as needed (the keep
-- list knows more than the steps do). Remembered per quest until the level or the route changes.
function BG.Needed(q)
  local ctx = ns.LvdListCtx
  if not (ctx and q) then return true end
  local steps = ctx.state()
  local lv = ctx.level()
  local c = S.need[q]
  if c and c.steps == steps and c.lv == lv and c.n == #steps then return c.v end
  local v = true
  for _, t in ipairs(steps) do
    if t.q == q and (t.k == "accept" or t.k == "do" or t.k == "turnin") then
      if ctx.outgrown(t) then v = false end
      break
    end
  end
  if not c then c = {} S.need[q] = c end
  c.steps, c.lv, c.n, c.v = steps, lv, #steps, v
  return v
end

local function KeepOf(btn, bag)
  local slot = btn.GetID and btn:GetID()
  if type(slot) ~= "number" or type(bag) ~= "number" then return nil end
  local id = ItemID(bag, slot)
  if not id then return nil end
  local k = ns.KeepFor and ns.KeepFor(id)
  if k and Sellable(id) then return k end
  return nil
end

-- the bag of a button: the button knows (retail style), else its window's id (the game's bag windows)
local function BagOf(btn)
  local bag = btn.GetBagID and btn:GetBagID()
  if type(bag) == "number" then return bag end
  local fr = btn.GetParent and btn:GetParent()
  bag = fr and fr.GetID and fr:GetID()
  if type(bag) == "number" then return bag end
  return nil
end

---------------------------------------------------------------------------
-- The mark
---------------------------------------------------------------------------
local function Edge(o, p1, p2, w, h)
  local t = o:CreateTexture(nil, "OVERLAY")
  t:SetColorTexture(BLUE[1], BLUE[2], BLUE[3], 0.95)
  t:SetPoint(p1, o, p1, 0, 0)
  t:SetPoint(p2, o, p2, 0, 0)
  if w then t:SetWidth(w) end
  if h then t:SetHeight(h) end
  return t
end

-- the mark shown again (its bag window opened): is the item still one to keep?
local function Revalidate(o)
  local btn = o.btn
  if not btn then return end
  if not KeepOf(btn, BagOf(btn)) then o:Hide() end
end

local function Overlay(btn)
  local o = btn._lvdKeep
  if o then return o end
  o = CreateFrame("Frame", nil, btn)
  o.btn = btn
  o:SetAllPoints(btn)
  if o.SetFrameLevel and btn.GetFrameLevel then o:SetFrameLevel((tonumber(btn:GetFrameLevel()) or 1) + 4) end
  if o.EnableMouse then o:EnableMouse(false) end -- clicks and the tooltip go to the item
  o.top = Edge(o, "TOPLEFT", "TOPRIGHT", nil, EDGE)
  o.bottom = Edge(o, "BOTTOMLEFT", "BOTTOMRIGHT", nil, EDGE)
  o.left = Edge(o, "TOPLEFT", "BOTTOMLEFT", EDGE, nil)
  o.right = Edge(o, "TOPRIGHT", "BOTTOMRIGHT", EDGE, nil)
  o.mark = o:CreateTexture(nil, "OVERLAY")
  o.mark:SetColorTexture(BLUE[1], BLUE[2], BLUE[3], 1)
  o.mark:SetSize(8, 8)
  o.mark:SetPoint("TOPRIGHT", o, "TOPRIGHT", 0, 0)
  o:SetScript("OnShow", Revalidate)
  btn._lvdKeep = o
  return o
end

local function Mark(btn, bag)
  if not btn or (btn.IsShown and not btn:IsShown()) then return end
  local k = KeepOf(btn, bag)
  if not k then return end
  local o = Overlay(btn)
  o.q = k.q
  o:Show()
  S.n = S.n + 1
  S.shown[S.n] = o
end

---------------------------------------------------------------------------
-- Looking through the bag windows
---------------------------------------------------------------------------
local function ScanWindow(fr, i)
  -- the retail style window: its buttons by iterator or list
  if fr.EnumerateValidItems then
    local it, t, s = fr:EnumerateValidItems()
    if type(it) == "function" then
      for _, btn in it, t, s do Mark(btn, BagOf(btn)) end
      return
    end
  end
  if type(fr.Items) == "table" then
    for _, btn in ipairs(fr.Items) do Mark(btn, BagOf(btn)) end
    return
  end
  -- the game's bag windows: ContainerFrameN with the buttons ContainerFrameNItemM, the window's id is the bag
  local id = fr.GetID and fr:GetID()
  if type(id) ~= "number" or not i then return end
  local size = tonumber(fr.size)
  if not size then
    local C = C_Container
    local n = (C and C.GetContainerNumSlots) or GetContainerNumSlots
    size = n and tonumber(n(id)) or 0
  end
  for j = 1, size do Mark(_G[ItemName(i, j)], id) end
end

local function Open(fr) return fr ~= nil and fr.IsShown ~= nil and fr:IsShown() end

function BG.Update()
  S.updates = S.updates + 1
  for k = S.n, 1, -1 do S.shown[k]:Hide() S.shown[k] = nil end
  S.n = 0
  if not BG.Enabled() then return 0 end
  for i = 1, FRAMES do
    local fr = _G[FRAME_NAMES[i]]
    if Open(fr) then ScanWindow(fr, i) end
  end
  local comb = _G.ContainerFrameCombinedBags
  if Open(comb) then ScanWindow(comb, nil) end
  if Open(_G.BankFrame) then
    for j = 1, BANK_SLOTS do
      local b = _G[BANK_NAMES[j]]
      if b then Mark(b, -1) end -- the bank's own slots: bag -1
    end
  end
  for p = 1, #BG.Prefixes do
    local row = PREFIX_NAMES[p]
    if not row then row = {} PREFIX_NAMES[p] = row end
    for j = 1, 200 do
      local name = row[j]
      if not name then name = BG.Prefixes[p] .. j row[j] = name end
      local b = _G[name]
      if not b then break end
      Mark(b, BagOf(b))
    end
  end
  return S.n
end

-- a number for "which bag windows are open, showing which bags": changes when a window opens, closes or shows another bag
local function Signature()
  local sig = 0
  for i = 1, FRAMES do
    local fr = _G[FRAME_NAMES[i]]
    if Open(fr) then
      local id = fr.GetID and fr:GetID()
      sig = (sig * 31 + i * 64 + (type(id) == "number" and id or 0) + 1) % MOD
    end
  end
  if Open(_G.ContainerFrameCombinedBags) then sig = (sig * 31 + 977) % MOD end
  if Open(_G.BankFrame) then sig = (sig * 31 + 991) % MOD end
  if _G[FIRST_ADDON_BUTTON] then sig = (sig * 31 + 997) % MOD end
  return sig
end

function BG.Poll()
  if not BG.Enabled() and S.n == 0 then return end
  local sig = Signature()
  if sig ~= S.sig then
    S.sig = sig
    BG.Update()
  end
end

function BG.Later()
  S.pending = false
  BG.Update()
end

function BG.Soon()
  if S.pending then return end
  S.pending = true
  if C_Timer and C_Timer.After then C_Timer.After(0.2, BG.Later) else BG.Later() end
end

---------------------------------------------------------------------------
-- Events and the light look at the windows
---------------------------------------------------------------------------
local ef = CreateFrame("Frame")
local elapsed = 0
ef:SetScript("OnUpdate", function(_, dt)
  elapsed = elapsed + (tonumber(dt) or 0)
  if elapsed < POLL then return end
  elapsed = 0
  BG.Poll()
end)
ef:SetScript("OnEvent", function() BG.Soon() end)
-- (BAG_OPEN and BAG_CLOSED: where the client has them; an unknown event is an error, hence pcall)
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "MERCHANT_SHOW",
    "PLAYER_ENTERING_WORLD", "BAG_OPEN", "BAG_CLOSED" }) do
  pcall(ef.RegisterEvent, ef, e)
end
BG.frame = ef -- (tests)
