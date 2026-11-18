local _, ns = ...
---------------------------------------------------------------------------
-- (16.11.2026, Daniel: "bei allen addons soll der diag befehl ein fenster zum kopieren aufmachen. das ewige Screenshot
-- machen des chats ist nicht sehr produktiv") /lvd diag: the facts for a bug report in a window to copy (all marked).
-- Daniel 16.11.: "Gleich im neuen Stil": the window in the game's look (DonCore Blizz, its ShowCopy) when the client has
-- the templates, else DonCore Kit's copy box; should both fail, the lines go to the chat. /lvd diag chat prints them.
-- Only this window takes the game's look; Leveldon's other windows stay as they are (no option for it).
---------------------------------------------------------------------------
local L = ns.L
local DC = LibStub and LibStub("DonCore-1.0", true)
local Bz = DC and DC:Get("Blizz", 5)

local function Call(f, ...)
  if type(f) ~= "function" then return nil end
  local r = { pcall(f, ...) }
  if not r[1] then return nil end
  return unpack(r, 2)
end
local function OnOff(v) return v and "on" or "off" end
local function Loaded(name)
  local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or rawget(_G, "IsAddOnLoaded")
  return Call(f, name) and "loaded" or "not loaded"
end

-- which window /lvd diag opens: "blizzard", or "kit (missing: <what>)"
function ns.DiagLook()
  if not Bz then return "kit (missing: DonCore Blizz)" end
  local K, miss = Call(Bz.Kit)
  if K and type(K.ShowCopy) == "function" then return "blizzard", K end
  return "kit (missing: " .. tostring(miss or "Blizz kit") .. ")"
end

function ns.DiagLines()
  local out = {}
  local function Add(s) out[#out + 1] = s end
  Add("Leveldon " .. tostring(ns.LeveldonVersion or "?") .. " diag")
  local v, build, date, toc = Call(GetBuildInfo)
  Add(("Client: %s build %s (%s), interface %s, locale %s"):format(tostring(v or "?"), tostring(build or "?"),
    tostring(date or "?"), tostring(toc or "?"), tostring(Call(GetLocale) or ns.LOCALE or "?")))
  local race = select(2, Call(UnitRace, "player"))
  local cls = select(2, Call(UnitClass, "player"))
  Add(("Character: %s %s, level %s"):format(tostring(race or "?"), tostring(cls or "?"), tostring(Call(UnitLevel, "player") or "?")))
  -- the route and the step you are on
  Add("Route: " .. tostring(Call(ns.RouteInfo) or "?"))
  Add(("Route key: %s, id %s, start area %s"):format(tostring(Call(ns.LeveldonRouteKey) or "-"),
    tostring(Call(ns.LeveldonRouteId) or "-"), tostring(type(LeveldonCharDB) == "table" and LeveldonCharDB.line or "own")))
  local steps = Call(ns.LeveldonSteps)
  local cur = Call(ns.LeveldonCur)
  local n = type(steps) == "table" and #steps or 0
  local step = type(steps) == "table" and cur and steps[cur] or nil
  local text = cur and Call(ns.LeveldonStepText, cur)
  Add(("Step: %s of %d%s%s"):format(tostring(cur or "?"), n,
    step and step.k and (", " .. tostring(step.k) .. (step.q and (" quest " .. tostring(step.q)) or "")) or "",
    text and (": " .. tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[\r\n]", " ")) or ""))
  -- the recorder (/lvd rec)
  local r = Call(ns.RecState)
  if type(r) == "table" then
    Add(("Recorder: %s, %s, %d sessions, %d events, %d walking points, %d reports"):format(OnOff(r.on),
      r.active and "writing" or "not writing", r.sessions or 0, r.events or 0, r.points or 0, r.reports or 0))
  end
  -- the options (Options.lua), sorted by name
  local O = ns.LVD_OPTIONS
  if type(O) == "table" then
    local keys = {}
    for k in pairs(O) do keys[#keys + 1] = k end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
      local o = O[k]
      local val
      if type(o) == "table" and type(o.get) == "function" then val = Call(o.get) end
      if type(val) == "number" then val = ("%.2f"):format(val) end
      parts[#parts + 1] = k .. "=" .. tostring(val)
    end
    Add("Options: " .. table.concat(parts, ", "))
  end
  Add(("Window: %s, record only %s, Questdon %s, DonMap %s"):format(Call(ns.WindowShown) and "shown" or "hidden",
    OnOff(Call(ns.RecordOnly)), Loaded("Questdon"), Loaded("DonMap")))
  Add("Diag window: " .. (ns.DiagLook()))
  return out
end

local function Print(lines)
  for _, l in ipairs(lines) do print(l) end
end
ns.DiagPrint = Print -- (tests)

-- /lvd diag (window), /lvd diag chat (the chat as before)
function ns.ShowDiag(chat)
  local ok, lines = pcall(ns.DiagLines)
  if not ok then lines = { "Leveldon diag failed: " .. tostring(lines) } end
  if chat then Print(lines) return "chat" end
  local text = table.concat(lines, "\n")
  local hint = L["Ctrl+A selects all, Ctrl+C copies."]
  local words = { selectAll = L["Select all"], close = L["Close"] }
  local _, K = ns.DiagLook()
  if K and pcall(K.ShowCopy, "Leveldon diag", hint, text, words) then return "blizzard" end
  local Kit = ns.Kit
  if Kit and type(Kit.ShowCopy) == "function" and pcall(Kit.ShowCopy, "Leveldon diag", hint, text, words) then return "kit" end
  Print(lines)
  return "chat"
end
