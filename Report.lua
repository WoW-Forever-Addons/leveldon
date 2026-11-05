local _, ns = ...
local L = ns.L

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
  { key = "note", text = L["Note"] }, -- (11.10., Daniel: ideas and improvements; the step stays)
}
local Kit = ns.Kit

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
    local a = ns.QD()
    title = title or (a and a.QuestTitle and a.QuestTitle(c.quest)) or (L["quest "] .. c.quest)
  else
    title = title or (ns.LeveldonStepText and ns.LeveldonStepText(cur)) or "-"
  end
  return { step = cur, obj = s, ri = s and s._i or nil, k = s and s.k or nil, q = q, title = title, fromBook = c.quest ~= nil }
end

local function Save()
  if not (dlg and ctx and reason) then return end
  LeveldonDB = LeveldonDB or {}
  LeveldonDB.reports = type(LeveldonDB.reports) == "table" and LeveldonDB.reports or {}
  local text = dlg.box:GetText() or ""
  text = text:gsub("[\r\n]+", " "):sub(1, 400)
  local m, x, y = Pos()
  local name, realm
  if UnitFullName then name, realm = UnitFullName("player") end -- (05.11.2026) both
  if ns.Surnames and ns.Surnames() then name, realm = ns.UnitNameRealm("player"), ns.MyRealmKey() end -- Forever (QD.lua)
  local r = LeveldonDB.reports
  r[#r + 1] = { t = time and time() or 0, c = (name or "?") .. "-" .. (realm or ""), lv = UnitLevel and UnitLevel("player") or 0,
    m = m, x = x and math.floor(x * 100 + 0.5) / 100, y = y and math.floor(y * 100 + 0.5) / 100,
    step = ctx.step, ri = ctx.ri, k = ctx.k, q = ctx.q, title = ctx.title, book = ctx.fromBook or nil,
    reason = reason, text = text ~= "" and text or nil,
    route = ns.LeveldonRouteKey and ns.LeveldonRouteKey() or nil, ver = ns.LeveldonVersion,
    rid = ns.LeveldonRouteId and ns.LeveldonRouteId() or nil } -- (13.10.) the exact route bands
  while #r > MAX do table.remove(r, 1) end
  if ns.RecEvent then ns.RecEvent("Q", reason, ctx.step or 0, ctx.q or 0) end
  if ns.ShareReport then pcall(ns.ShareReport, ctx.ri, ctx.k, ctx.q, reason) end -- (0.2.0) the reason only
  dlg:Hide()
  -- (Daniel 11.10.: "after reporting, Leveldon should go to the next step") a report of the current step
  -- (from Leveldon's window, not from a quest card) moves on; a note does not ("a button for notes, I write
  -- improvements there, the quest must not move on")
  if not ctx.fromBook and reason ~= "note" and ns.LeveldonSkip then
    -- (15.10., review round 2) the reported step, not whatever came in meanwhile
    if ns.LeveldonSkipStep and ctx.obj then ns.LeveldonSkipStep(ctx.obj) else ns.LeveldonSkip(1) end
    print(L["|cff3fa9f5Level|rdon: report saved ("] .. #r .. L[" in all), on to the next step. Thank you!"])
  else
    print("|cff3fa9f5Level|rdon: " .. (reason == "note" and L["note"] or L["report"]) .. L[" saved ("] .. #r .. L[" in all). Thank you!"])
  end
end

-- a reason: one of the three (a second click on the picked one takes it back)
local function Pick(key)
  reason = key
  for _, r in ipairs(dlg.rows) do r.toggle:SetValue(r.key == key) end
  dlg.save:SetDisabled(reason == nil)
end

-- (02.11.2026, StyleKit 2 step 4, docs/layout_2026-11-02/leveldon/) DonCore's dialog (Kit.Dialog): the step, a switch per
-- reason (Kit.OptionRow with Kit.Toggle), a note (Kit.TextBox), Cancel and Save; Esc closes, the head drags it
local ROW, BOX = 36, 64
local function Create()
  local f = Kit.Dialog("LeveldonReport", { width = 400, height = 300, onLayout = function(self, w, h)
    if not self.rows then return end
    self.what:ClearAllPoints()
    self.what:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, 0)
    Kit.Fit(self.what, w)
    for i, r in ipairs(self.rows) do
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, -(24 + (i - 1) * ROW))
      r:SetHeight(ROW)
      r:Layout(w)
    end
    self.box:ClearAllPoints()
    self.box:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, -(24 + #self.rows * ROW + 8))
    self.box:Layout(w, math.max(40, h - (24 + #self.rows * ROW + 8)))
  end })
  f:SetTitle(L["Report this step"], "Interface\\Icons\\INV_Misc_Book_09")
  f.what = Kit.Text(f.body, "row", Kit.C.hero)
  f.rows = {}
  for _, r in ipairs(REASONS) do
    local key = r.key
    local t = Kit.Toggle(f.body, { set = function(on) Pick(on and key or nil) end })
    local row = Kit.OptionRow(f.body, { label = r.text, control = t })
    row.key, row.toggle = key, t
    f.rows[#f.rows + 1] = row
  end
  f.box = Kit.TextBox(f.body, { placeholder = L["What happened? (optional)"], maxLetters = 400 })
  f.edit = f.box.edit
  f:SetButtons({ { text = L["Cancel"], onClick = function(d) d:Hide() end }, { text = L["Save"], kind = "primary", onClick = function() Save() end } })
  f.save = f.buttons[2]
  f:SetBodySize(376, 24 + #REASONS * ROW + 8 + BOX)
  return f
end

-- Open the report window. c: nil (the current step) or { quest = id, title = text } (from the quest book).
function ns.OpenReport(c)
  dlg = dlg or Create()
  ctx = Context(c)
  reason = nil
  Pick(nil)
  dlg.box:SetText("")
  dlg.what:SetText((ctx.fromBook and L["Quest: "] or (L["Step "] .. (ctx.step or 0) .. ": ")) .. (ctx.title or "-"))
  dlg:Show()
end
ns.ReportSave = Save -- (tests)
ns.ReportPick = function(key) if dlg then Pick(key) end end -- (tests)
ns.ReportDialog = function() return dlg end -- (tests)

-- For Questdon's quest book (a "Report" chip on the quest card when Leveldon is there).
LeveldonAPI = LeveldonAPI or {}
LeveldonAPI.Report = function(c) ns.OpenReport(c) end
