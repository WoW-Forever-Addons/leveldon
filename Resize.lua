local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- (0.1.7, Daniel 11.10.: "the Leveldon window is very small; variable, a handle at the bottom right to
-- change width and height, like a Windows window; and the text is very small for my eyes")
-- The handle at the bottom right: dragging right and left sets the width (260 to 800), down and up how
-- many coming steps the window shows (1 to 12), so the window grows with what it shows. Ctrl + mouse
-- wheel over the window's title bar or the handle: text size (the whole window, 60 to 160 %);
-- /lvd text 1.3 sets it, /lvd text reset goes back. Saved per character (LeveldonCharDB.panel).
-- Default text size 120 % (Daniel: too small at 100 %).
---------------------------------------------------------------------------
local MIN_W, MAX_W = 260, 800
local MIN_LINES, MAX_LINES = 1, 12
local ROW = 18          -- window units per coming step when dragging down
local DEFAULT_SCALE = 1.2
local DEFAULT_LINES = 3
local DEFAULT_W = 360

local function Store()
  LeveldonCharDB = LeveldonCharDB or {}
  LeveldonCharDB.panel = LeveldonCharDB.panel or {}
  return LeveldonCharDB.panel
end

local function Panel() return ns.LeveldonPanelFrame and ns.LeveldonPanelFrame() end

-- width and coming steps, applied and saved
local function Apply(w, lines, save)
  local p = Panel()
  if not p then return end
  w = math.max(MIN_W, math.min(MAX_W, math.floor((tonumber(w) or DEFAULT_W) + 0.5)))
  lines = math.max(MIN_LINES, math.min(MAX_LINES, math.floor(tonumber(lines) or DEFAULT_LINES)))
  ns.nextShown = lines
  if p._width ~= w then p:SetPanelWidth(w) end
  if ns.LeveldonRefresh then ns.LeveldonRefresh() end
  if save then
    local st = Store()
    st.w, st.lines = w, lines
  end
end
ns.LeveldonApplySize = Apply -- (tests)

local function SetText(scale)
  local p = Panel()
  if not p then return end
  p:SetPanelScale(scale) -- saved as panel.scale (Style)
end

-- keep the top left corner where it is while the size changes (else a window anchored at the right or
-- the centre would grow in the other direction)
local function PinTopLeft(p)
  local l, t = p:GetLeft(), p:GetTop()
  if not (l and t) then return end
  p:ClearAllPoints()
  p:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
  Store().pos = { "TOPLEFT", "BOTTOMLEFT", math.floor(l + 0.5), math.floor(t + 0.5) }
end

local function Cursor(p)
  local x, y = GetCursorPosition()
  local s = (p.GetEffectiveScale and p:GetEffectiveScale()) or 1
  return x / s, y / s
end

local function Wheel(_, delta)
  -- (0.1.8, Daniel 12.10.) Shift + mouse wheel: the background's opacity, down to no background and no frame
  if IsShiftKeyDown and IsShiftKeyDown() then
    if ns.LvdWin and ns.LvdWin.WheelAlpha then ns.LvdWin.WheelAlpha(Panel(), delta) end
    return
  end
  if not (IsControlKeyDown and IsControlKeyDown()) then return end
  local p = Panel()
  if not p then return end
  SetText((p._scale or 1) + (delta > 0 and 0.05 or -0.05))
end

local grip
local function Attach()
  local p = Panel()
  if not p or grip then return end
  local st = Store()
  if st.scale == nil then SetText(DEFAULT_SCALE) end
  Apply(st.w or DEFAULT_W, st.lines or DEFAULT_LINES, false)
  grip = CreateFrame("Button", "LeveldonResizeGrip", p)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -3, 3)
  if grip.SetFrameLevel and p.GetFrameLevel then grip:SetFrameLevel((p:GetFrameLevel() or 60) + 30) end
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:EnableMouse(true)
  if grip.EnableMouseWheel then grip:EnableMouseWheel(true) end
  grip:SetScript("OnMouseWheel", Wheel)
  grip:SetScript("OnEnter", function(self)
    if ns.Style and ns.Style.Tooltip then
      ns.Style.Tooltip(self, L["Window size"], { L["Drag: width (right, left) and how many coming steps (down, up)."],
        L["Ctrl + mouse wheel: text size."], L["Shift + mouse wheel: background opacity."] }, "/lvd text 1.3")
    end
  end)
  grip:SetScript("OnLeave", function(self) if ns.Style and ns.Style.HideTooltip then ns.Style.HideTooltip(self) end end)
  grip:SetScript("OnMouseDown", function(self)
    if p._locked then return end
    PinTopLeft(p)
    local x, y = Cursor(p)
    self._drag = { x = x, y = y, w = p._width or DEFAULT_W, lines = ns.nextShown or DEFAULT_LINES }
    self:SetScript("OnUpdate", function()
      local d = self._drag
      if not d then return end
      local cx, cy = Cursor(p)
      local w = d.w + (cx - d.x)
      local lines = d.lines + math.floor((d.y - cy) / ROW + 0.5)
      if math.floor(w + 0.5) ~= p._width or lines ~= ns.nextShown then Apply(w, lines, false) end
    end)
  end)
  grip:SetScript("OnMouseUp", function(self)
    self:SetScript("OnUpdate", nil)
    if self._drag then Apply(p._width, ns.nextShown, true) end
    self._drag = nil
  end)
  -- Ctrl + mouse wheel over the title bar as well
  local header = p._header or p.header
  if header and header.EnableMouseWheel then
    header:EnableMouseWheel(true)
    header:SetScript("OnMouseWheel", Wheel)
  end
end
ns.LeveldonAttachResize = Attach -- (tests)

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function() if C_Timer and C_Timer.After then C_Timer.After(0, Attach) else Attach() end end)
f:RegisterEvent("PLAYER_LOGIN")

-- /lvd text <size>, /lvd text reset
function ns.TextCommand(arg)
  local p = Panel()
  if not p then return end
  if arg == "reset" then SetText(DEFAULT_SCALE)
  elseif tonumber(arg) then SetText(tonumber(arg)) end
  print((L["|cff3fa9f5Level|rdon: text size %d %% (Ctrl + mouse wheel over the title bar, /lvd text 1.3)."]):format(math.floor((p._scale or 1) * 100 + 0.5)))
end
