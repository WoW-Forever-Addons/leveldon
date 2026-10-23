-- (22.10.2026, Leveldon Plan V3, Daniel: "eine Basis" je Rasse, Dungeons als Zusatz auswählbar) One base route per race
-- (and per start area of the route picker) and what a class adds to it, as an overlay; the dungeons are an overlay too.
--   LeveldonRoutes[race] = { base = { "<1 to 30>", "<30 to 50>", "<50 to 60>", dg = "<dungeon overlay>" },
--                            ovl = { <class> = "<overlay>", <class>_dg = "<overlay on the dungeon route>" } }
--   LeveldonLines[race][line] = { base = "<1 to 30>", dg = "<dungeon overlay>", ovl = { ... } }
-- An overlay (each a Lua table as text, leveldon-build/export_v3.py) says how the steps of the route it lies on are taken:
--   seq = { a, b, {step}, c, d, ... }   the base's steps a to b, then a step of its own, then c to d ...
--   el, t = { ... }                     the planned level and time of every resulting step (false: none)
--   xp = { [n] = xp }                   a turn-in's experience where it differs (the grey factor at another level)
--   any other field (hours, id, vendors, keep, dungeons, bonus, ...) replaces the base's
-- Leveldon.lua stays at Lua's limit of 200 locals: this lives in ns.
local _, ns = ...

local function unpackText(text)
  if type(text) ~= "string" then return nil end
  local fn = (loadstring or load)("return " .. text)
  local ok, t = pcall(fn or error)
  return ok and type(t) == "table" and t or nil
end
ns.UnpackRoute = unpackText

local SKIP = { seq = true, el = true, t = true, xp = true, on = true }

-- the base table with the overlay laid on (a new table; the base's step tables are taken over, not copied)
function ns.ApplyOverlay(base, ov)
  if type(base) ~= "table" or type(ov) ~= "table" or type(ov.seq) ~= "table" then return base end
  local src, steps, seq = base.steps or {}, {}, ov.seq
  local i, n = 1, #seq
  while i <= n do
    local v = seq[i]
    if type(v) == "number" then
      local b = tonumber(seq[i + 1]) or v
      for j = v, b do
        if src[j] then steps[#steps + 1] = src[j] end
      end
      i = i + 2
    else
      if type(v) == "table" then steps[#steps + 1] = v end
      i = i + 1
    end
  end
  local el, tt = ov.el, ov.t
  for k, st in ipairs(steps) do
    if el then local e = el[k] if e ~= nil then st.el = e or nil end end
    if tt then local x = tt[k] if x ~= nil then st.t = x or nil end end
  end
  for k, xp in pairs(ov.xp or {}) do
    if steps[k] then steps[k].xp = xp end
  end
  local out = {}
  for k, v in pairs(base) do out[k] = v end
  for k, v in pairs(ov) do
    if not SKIP[k] then
      if v == false then out[k] = nil else out[k] = v end   -- false: the base's field is not there (hubopt)
    end
  end
  out.steps = steps
  return out
end

-- the first band (1 to 30) of a base source for a class: the base, with dungeons its dungeon overlay, then the class's
-- overlay (the one made for the dungeon route when dungeons are on). Returns the table and whether dungeons are in it.
function ns.BaseBand(src, cls, useDg)
  if type(src) ~= "table" then return nil end
  local text = src.base
  if type(text) == "table" then text = text[1] end
  local t = unpackText(text)
  if not t then return nil end
  local ovl = src.ovl or {}
  local key = cls or ""
  -- a class overlay is made for one route: the dungeon one only with the class's own overlay for it, else the plain route
  -- with the class (its class quests and trainers matter more than the dungeons)
  local dg = useDg and type(src.dg) == "string" and (ovl[key .. "_dg"] or not ovl[key]) and unpackText(src.dg) or nil
  if dg then t = ns.ApplyOverlay(t, dg) end
  local o = unpackText(dg and ovl[key .. "_dg"] or (not dg and ovl[key]) or nil)
  if o then t = ns.ApplyOverlay(t, o) end
  return t, dg ~= nil
end

-- the source of a route in the new form, nil for the old form (LeveldonRoutes[race][class] = { band texts })
function ns.RouteSource(raceTable)
  if type(raceTable) == "table" and type(raceTable.base) == "table" then
    return { base = raceTable.base[1], dg = raceTable.base.dg, ovl = raceTable.ovl, bands = raceTable.base }
  end
  return nil
end
