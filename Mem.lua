local addonName, ns = ...

---------------------------------------------------------------------------
-- (23.10.2026, Daniel: "/lvd mem") Leveldon's memory by part, like Questdon's /qd mem. For 30 seconds the total
-- of Leveldon (and Questdon) is sampled once a second, and every timer, ticker and frame script of Leveldon counts
-- the Lua memory it took (collectgarbage("count") before and after; the game runs one thing at a time). A call
-- inside another counts again under its own name (inner). Questdon's API, called by Leveldon, is counted as
-- "Questdon <function>" so Leveldon's own part can be told apart. Outside the measurement the wrappers only check
-- one variable.
--   ns.CreateFrame(...)  CreateFrame that remembers the frame (its OnEvent and OnUpdate are counted while measuring)
--   ns.NewTicker(iv, fn) C_Timer.NewTicker, counted as "ticker <file:line>"
--   ns.After(delay, fn)  C_Timer.After, counted as "timer <file:line>" while measuring
---------------------------------------------------------------------------
local prof          -- { top = {}, inner = {}, calls = {} } while measuring
local depth = 0

-- "Leveldon.lua:123" of the code that called into this file
-- (23.10., Daniel's first /lvd mem: one "ticker Leveldon.lua:4300" at 3.5 calls a second) the game writes a stack line
-- as [Interface/AddOns/Leveldon/Leveldon.lua]:4358: in function <Interface/AddOns/Leveldon/Leveldon.lua:4300>: the
-- bracket after ".lua" hid the calling line, so the first place found was the start of the function around it, and
-- the three tickers of PLAYER_LOGIN shared one name. The bracket (and the quote of the older form) is allowed now.
local function Where()
  if type(debugstack) ~= "function" then return "?" end
  local ok, s = pcall(debugstack, 1, 8, 0)
  if not ok or type(s) ~= "string" then return "?" end
  s = s:gsub("\\", "/")
  for file, line in s:gmatch('([%w_]+%.lua)["%]]*:(%d+)') do
    if file ~= "Mem.lua" then return file .. ":" .. line end
  end
  return "?"
end
ns.MemWhere = Where

local function Done(label, kb, d0, ...)
  depth = d0
  local p = prof
  if p then
    local d = collectgarbage("count") - kb
    local key = d0 == 0 and label or (label .. " (inner)")
    p.calls[key] = (p.calls[key] or 0) + 1
    if d > 0 then
      local t = d0 == 0 and p.top or p.inner
      t[label] = (t[label] or 0) + d
    end
  end
  return ...
end

-- fn, counted under label while /lvd mem runs
function ns.Track(label, fn)
  if type(fn) ~= "function" then return fn end
  return function(...)
    if not prof then return fn(...) end
    local d0 = depth
    depth = d0 + 1
    return Done(label, collectgarbage("count"), d0, fn(...))
  end
end

function ns.NewTicker(interval, fn, iterations)
  if not (C_Timer and C_Timer.NewTicker) then return nil end
  return C_Timer.NewTicker(interval, ns.Track("ticker " .. Where(), fn), iterations)
end

function ns.After(delay, fn)
  if not (C_Timer and C_Timer.After) then return end
  if prof then fn = ns.Track("timer " .. Where(), fn) end -- (the place is only looked up while measuring)
  C_Timer.After(delay, fn)
end

-- frames made by Leveldon (weak: frames are never freed in the game, the tests make many)
local frames = setmetatable({}, { __mode = "k" })
function ns.CreateFrame(...)
  local f = CreateFrame(...)
  if f then frames[f] = Where() end
  return f
end

-- While measuring: each remembered frame's OnEvent (by event) and OnUpdate counted; afterwards the scripts are
-- given back, unless something set another script meanwhile
local wrapped = {}
local function WrapFrames()
  for f, at in pairs(frames) do
    local name = (f.GetName and f:GetName()) or at
    local ev = f.GetScript and f:GetScript("OnEvent")
    if type(ev) == "function" then
      local label = "event " .. tostring(name) .. " "
      local w = function(self, event, ...)
        local d0 = depth
        depth = d0 + 1
        return Done(label .. tostring(event), collectgarbage("count"), d0, ev(self, event, ...))
      end
      f:SetScript("OnEvent", w)
      wrapped[#wrapped + 1] = { f, "OnEvent", ev, w }
    end
    local up = f.GetScript and f:GetScript("OnUpdate")
    if type(up) == "function" then
      local w = ns.Track("update " .. tostring(name), up)
      f:SetScript("OnUpdate", w)
      wrapped[#wrapped + 1] = { f, "OnUpdate", up, w }
    end
  end
end
local function UnwrapFrames()
  for _, e in ipairs(wrapped) do
    local f, script, orig, w = e[1], e[2], e[3], e[4]
    if f:GetScript(script) == w then f:SetScript(script, orig) end
  end
  wrapped = {}
end

-- Questdon's API as Leveldon calls it
local apiSaved
local function WrapAPI()
  local api = ns.QD()
  if type(api) ~= "table" or apiSaved then return end
  apiSaved = {}
  for k, f in pairs(api) do
    if type(f) == "function" then
      apiSaved[k] = f
      api[k] = ns.Track("Questdon " .. tostring(k), f)
    end
  end
end
local function UnwrapAPI()
  local api = ns.QD()
  if type(api) == "table" and apiSaved then
    for k, f in pairs(apiSaved) do api[k] = f end
  end
  apiSaved = nil
end

function ns.MemProfile(on)
  if on then
    prof, depth = { top = {}, inner = {}, calls = {} }, 0
    WrapAPI()
    WrapFrames()
    return prof
  end
  UnwrapFrames()
  UnwrapAPI()
  local was = prof
  prof = nil
  return was
end
function ns.MemProfiling() return prof ~= nil end

local function Print(s) print("|cff3fa9f5Level|rdon: " .. s) end
local run
function ns.MemCheck(seconds)
  local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })
  seconds = math.max(5, math.min(120, tonumber(seconds) or 30))
  if run then return end
  if type(UpdateAddOnMemoryUsage) ~= "function" or type(GetAddOnMemoryUsage) ~= "function" then
    Print(L["The game does not tell the memory of addons here."]) return
  end
  local list = { { name = addonName, grown = 0 } }
  if rawget(_G, "QuestdonAPI") then list[2] = { name = "Questdon", grown = 0 } end
  run = { left = seconds, seconds = seconds }
  Print(L["Measuring Leveldon's memory for %d seconds (stay out of fights)..."]:format(seconds))
  local function Sample()
    if InCombatLockdown and InCombatLockdown() then return end
    pcall(UpdateAddOnMemoryUsage)
    for _, e in ipairs(list) do
      local ok, kb = pcall(GetAddOnMemoryUsage, e.name)
      kb = ok and tonumber(kb) or nil
      if kb then
        if e.last and kb > e.last then e.grown = e.grown + (kb - e.last) end
        e.last = kb
      end
    end
  end
  -- the collector pauses while measuring (as in /qd mem): else a part's "before and after" counts what it freed
  run.gcStopped = pcall(collectgarbage, "stop")
  Sample()
  ns.MemProfile(true)
  local ticker
  ticker = C_Timer.NewTicker(1, function()
    Sample()
    run.left = run.left - 1
    if run.left > 0 then return end
    ticker:Cancel()
    local p = ns.MemProfile(false)
    if run.gcStopped then pcall(collectgarbage, "restart") end
    for _, e in ipairs(list) do
      if e.last then
        Print(L["%s: %.1f MB, about %d KB new memory a second"]:format(e.name, e.last / 1024, math.floor(e.grown / run.seconds + 0.5)))
      end
    end
    local top = {}
    for k, v in pairs(p.top) do top[#top + 1] = { k, v } end
    for k, v in pairs(p.inner) do top[#top + 1] = { k .. " (inner)", v } end
    table.sort(top, function(a, b) return a[2] > b[2] end)
    local shown = 0
    for _, e in ipairs(top) do
      local kbs = e[2] / run.seconds
      if shown >= 18 or kbs < 1 then break end
      if shown == 0 then Print(L["Leveldon's new memory by part:"]) end
      shown = shown + 1
      local n = p.calls[e[1]]
      Print(("  %s: %d KB a second%s"):format(e[1], math.floor(kbs + 0.5), n and (" (%.1f/s)"):format(n / run.seconds) or ""))
    end
    if shown == 0 then Print(L["No part of Leveldon made 1 KB a second or more."]) end
    run = nil
  end)
end
