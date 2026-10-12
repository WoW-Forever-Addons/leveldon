local _, ns = ...
local L = ns.L
local Style = ns.Style

---------------------------------------------------------------------------
-- (0.1.7, Daniel 11.10.: "a way to report, with a choice like quest giver not there, route makes no
-- sense, or general remarks, so you can evaluate all the data afterwards") Report.
--
-- The button in Leveldon's window reports the current step, the one on a quest's card in Questdon's
-- quest book (LeveldonAPI.Report) that quest. A reason, a text if you like, saved with the place, the
-- level, the step and the route in LeveldonDB.reports (at most MAX, the oldest go first) and as a "Q"
-- line in the recorder's session (Recorder.lua).
---------------------------------------------------------------------------
local MAX = 500
local REASONS = {
  { key = "giver", text = L["Quest giver not there"] },
  { key = "route", text = L["Route makes no sense"] },
  { key = "note", text = "Note" }, -- (11.10., Daniel: ideas and improvements; the step stays)
}
local BK = Style.BOOK or {}
local function C(c, fallback) c = c or fallback return c[1], c[2], c[3] end

local dlg, ctx, reason

local function Pos()
  local m = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not m then return nil end
  local p = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(m, "player")
  if not p then return m end
  local x, y = p:GetXY()
  return m, x * 100, y * 100
end

local function Context(c)
  c = c or {}
  local cur = ns.LeveldonCur and ns.LeveldonCur() or 0
  local steps = ns.LeveldonSteps and ns.LeveldonSteps() or {}
  local s = steps[cur]
  local q = c.quest or (s and s.q) or nil
  local title = c.title
  if c.quest then
    local a = QuestdonAPI
    title = title or (a and a.QuestTitle and a.QuestTitle(c.quest)) or (L["quest "] .. c.quest)
  else
    title = title or (ns.LeveldonStepText and ns.LeveldonStepText(cur)) or "-"
  end
  return { step = cur, ri = s and s._i or nil, k = s and s.k or nil, q = q, title = title, fromBook = c.quest ~= nil }
end

local function Button(parent, text, w, onClick)
  local b = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  b:SetSize(w, 22)
  if b.SetBackdrop then
    pcall(b.SetBackdrop, b, { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  end
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.label:SetPoint("CENTER")
  b.label:SetText(text)
  function b:SetOn(on)
    self.on = on
    if self.SetBackdropColor then
      local r, g, bl = C(on and BK.gold or BK.header, on and { 0.86, 0.71, 0.42 } or { 0.07, 0.08, 0.17 })
      pcall(self.SetBackdropColor, self, r, g, bl, on and 0.35 or 0.95)
      local gr, gg, gb = C(BK.gold, { 0.86, 0.71, 0.42 })
      pcall(self.SetBackdropBorderColor, self, gr, gg, gb, on and 1 or 0.5)
    end
  end
  b:SetOn(false)
  b:SetScript("OnClick", onClick)
  return b
end

local function Save()
  if not (dlg and ctx and reason) then return end
  LeveldonDB = LeveldonDB or {}
  LeveldonDB.reports = type(LeveldonDB.reports) == "table" and LeveldonDB.reports or {}
  local text = dlg.edit:GetText() or ""
  text = text:gsub("[\r\n]+", " "):sub(1, 400)
  local m, x, y = Pos()
  local name, realm = UnitFullName and UnitFullName("player")
  local r = LeveldonDB.reports
  r[#r + 1] = { t = time and time() or 0, c = (name or "?") .. "-" .. (realm or ""), lv = UnitLevel and UnitLevel("player") or 0,
    m = m, x = x and math.floor(x * 100 + 0.5) / 100, y = y and math.floor(y * 100 + 0.5) / 100,
    step = ctx.step, ri = ctx.ri, k = ctx.k, q = ctx.q, title = ctx.title, book = ctx.fromBook or nil,
    reason = reason, text = text ~= "" and text or nil,
    route = ns.LeveldonRouteKey and ns.LeveldonRouteKey() or nil, ver = ns.LeveldonVersion }
  while #r > MAX do table.remove(r, 1) end
  if ns.RecEvent then ns.RecEvent("Q", reason, ctx.step or 0, ctx.q or 0) end
  if ns.ShareReport then pcall(ns.ShareReport, ctx.ri, ctx.k, ctx.q, reason) end -- (0.2.0) the reason only
  dlg:Hide()
  -- (Daniel 11.10.: "after reporting, Leveldon should go to the next step") a report of the current step
  -- (from Leveldon's window, not from a quest card) moves on; a note does not ("a button for notes, I write
  -- improvements there, the quest must not move on")
  if not ctx.fromBook and reason ~= "note" and ns.LeveldonSkip then
    ns.LeveldonSkip(1)
    print(L["|cff3fa9f5Level|rdon: report saved ("] .. #r .. L[" in all), on to the next step. Thank you!"])
  else
    print("|cff3fa9f5Level|rdon: " .. (reason == "note" and "note" or "report") .. L[" saved ("] .. #r .. L[" in all). Thank you!"])
  end
end

local function Pick(key)
  reason = key
  for _, b in ipairs(dlg.reasons) do b:SetOn(b.key == key) end
  dlg.save:SetAlpha(1)
end

local function Create()
  local f = CreateFrame("Frame", "LeveldonReport", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  f:SetSize(400, 250)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
  f:SetFrameStrata("DIALOG")
  if f.SetBackdrop then
    pcall(f.SetBackdrop, f, { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    local r, g, b = C(BK.bg or BK.header, { 0.06, 0.07, 0.12 })
    pcall(f.SetBackdropColor, f, r, g, b, 0.97)
    local gr, gg, gb = C(BK.gold, { 0.86, 0.71, 0.42 })
    pcall(f.SetBackdropBorderColor, f, gr, gg, gb, 0.8)
  end
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.title:SetPoint("TOPLEFT", 12, -10)
  f.title:SetText(Style.Wordmark("Level", "don") .. L["  report"])
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  f.what = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.what:SetPoint("TOPLEFT", 12, -32)
  f.what:SetPoint("RIGHT", f, "RIGHT", -12, 0)
  f.what:SetJustifyH("LEFT")
  f.what:SetWordWrap(true)
  f.reasons = {}
  local prev
  for _, r in ipairs(REASONS) do
    local b = Button(f, r.text, 122, function(self) Pick(self.key) end)
    b.key = r.key
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -66) end
    f.reasons[#f.reasons + 1] = b
    prev = b
  end
  local box = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
  box:SetPoint("TOPLEFT", 12, -98)
  box:SetPoint("BOTTOMRIGHT", -12, 42)
  if box.SetBackdrop then
    pcall(box.SetBackdrop, box, { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    pcall(box.SetBackdropColor, box, 0, 0, 0, 0.35)
    pcall(box.SetBackdropBorderColor, box, 1, 1, 1, 0.12)
  end
  local eb = CreateFrame("EditBox", nil, box)
  eb:SetMultiLine(true)
  eb:SetMaxLetters(400)
  eb:SetFontObject(ChatFontNormal or "ChatFontNormal")
  eb:SetPoint("TOPLEFT", 6, -6)
  eb:SetPoint("BOTTOMRIGHT", -6, 6)
  eb:SetAutoFocus(false)
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  f.hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.hint:SetPoint("TOPLEFT", 8, -8)
  f.hint:SetText(L["What happened? (optional)"])
  eb:SetScript("OnTextChanged", function(self) f.hint:SetShown((self:GetText() or "") == "") end)
  box:EnableMouse(true)
  box:SetScript("OnMouseDown", function() eb:SetFocus() end)
  f.edit = eb
  f.save = Button(f, "Save", 90, Save)
  f.save:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)
  local cancel = Button(f, "Cancel", 90, function() f:Hide() end)
  cancel:SetPoint("RIGHT", f.save, "LEFT", -6, 0)
  if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "LeveldonReport") end
  f:Hide()
  return f
end

-- Open the report window. c: nil (the current step) or { quest = id, title = text } (from the quest book).
function ns.OpenReport(c)
  dlg = dlg or Create()
  ctx = Context(c)
  reason = nil
  for _, b in ipairs(dlg.reasons) do b:SetOn(false) end
  dlg.save:SetAlpha(0.5)
  dlg.edit:SetText("")
  dlg.what:SetText((ctx.fromBook and L["Quest: "] or (L["Step "] .. (ctx.step or 0) .. ": ")) .. (ctx.title or "-"))
  dlg:Show()
end
ns.ReportSave = Save -- (tests)
ns.ReportPick = function(key) if dlg then Pick(key) end end -- (tests)
ns.ReportDialog = function() return dlg end -- (tests)

-- For Questdon's quest book (a "Report" chip on the quest card when Leveldon is there).
LeveldonAPI = LeveldonAPI or {}
LeveldonAPI.Report = function(c) ns.OpenReport(c) end
