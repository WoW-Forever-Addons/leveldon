local addonName, ns = ...
local L = ns.L -- (12.10.) Locales.lua: the texts in the client's language (English is the key)
local Style = ns.Style

---------------------------------------------------------------------------
-- Leveldon 0.1 test build (Daniel 09.10.: "eine Route testen, wie das Feeling ist").
-- One computed route (Route.lua, from leveldon-build), a small window with the
-- current step and the next three, Questdon's arrow pointing at the step.
-- Steps move on by themselves: accept (quest in the log), do (objectives
-- complete), turn in (quest done), level (grind), map reached (travel), flight
-- master opened (fp), trainer opened (train), hearthstone used, new home inn.
-- Skip and back by hand: buttons in the title bar or /lvd next, /lvd back.
-- On login it starts at the first chapter that is not below the character's
-- level and skips everything already done.
-- (0.1.6, Daniel 10.10.) buys where the route passes the vendor anyway, Fishing
-- and Cooking together, the map pin on service stops (/lvd marks), Blizzard's
-- quest tracker hidden (/lvd tracker, button in the quest log), the profession
-- choice in the book look with "No professions", shown after the first quest.
-- (0.1.6 playtest 1, Daniel 10.10.) no "behind the plan" below level 6; buys only
-- at stops by a vendor that sells the item and only with the money (else they
-- wait); the arrow follows the step at once; a hub of NPCs walked once (by NPC,
-- in and out of a building once); the book chain with the route's own kobolds and
-- turn-ins; a far trainer or Camping turn-in waits for the next visit there.
---------------------------------------------------------------------------
local ROUTE = ns.ROUTE or { steps = {} }
local STEPS = ROUTE.steps -- (0.1.1) composed from ROUTE.steps and the chosen professions, see Compose()
local DUNGEON_BY_ID = {}
local function IndexRoute()
  for i, s in ipairs(ROUTE.steps) do s._i = i end
  for k in pairs(DUNGEON_BY_ID) do DUNGEON_BY_ID[k] = nil end
  for _, d in ipairs(ROUTE.dungeons or {}) do DUNGEON_BY_ID[d.id] = d end
end
IndexRoute()

-- (0.1.5, Daniel 10.10.: every race and class) the routes live in one load-on-demand addon per race
-- (Leveldon_Human, ...): LeveldonRoutes[race][class] = { "<1 to 30>", "<30 to 50>", "<50 to 60>" }, each
-- a Lua table as text, unpacked only for your race and class; the bands follow one another
local RACE_KEY = { [1] = "human", [2] = "orc", [3] = "dwarf", [4] = "nightelf", [5] = "undead", [6] = "tauren",
  [7] = "gnome", [8] = "troll", [95] = "skyborne", [96] = "skyborne_h" }
local RACE_FILE = { Human = "human", Orc = "orc", Dwarf = "dwarf", NightElf = "nightelf", Scourge = "undead",
  Tauren = "tauren", Gnome = "gnome", Troll = "troll" }
local DATA_ADDON = { human = "Leveldon_Human", orc = "Leveldon_Orc", dwarf = "Leveldon_Dwarf", nightelf = "Leveldon_NightElf",
  undead = "Leveldon_Undead", tauren = "Leveldon_Tauren", gnome = "Leveldon_Gnome", troll = "Leveldon_Troll",
  skyborne = "Leveldon_Skyborne", skyborne_h = "Leveldon_SkyborneH" }
-- (22.10., Daniel: "every race for every start area, the Horde alike") the 1 to 30 routes through the other start
-- areas of the faction: LeveldonLines[race][line][class] = { "<1 to 30>", dg = "<with dungeons>" } in Leveldon_<Race>Lines
-- (load on demand, only when a line is picked); ns.LINES (LinesData.lua) has hours, quests and reputation for the picker
ns.DATA_LINES = {}   -- (a field, not a local: this file is at Lua's limit of 200 locals)
for race, addon in pairs(DATA_ADDON) do ns.DATA_LINES[race] = addon .. "Lines" end
-- the key under which moves of accepts are kept: route, dungeons and (only when picked) the line
function ns.LaterKeyOf(d)
  return tostring(d.route) .. ":" .. tostring(d.dungeons) .. (d.line and (":" .. tostring(d.line)) or "")
end
function ns.LineTitle(key)   -- "Elwynn Forest (Human)" in the client's language
  local t = ns.LINE_TITLES and ns.LINE_TITLES[key]
  return t and L[t] or tostring(key)
end
local routeInfo = "built-in test route"
local function PlayerRaceKey()
  local file, id
  if UnitRace then local _ _, file, id = UnitRace("player") end
  return RACE_KEY[tonumber(id) or -1] or RACE_FILE[file or ""]
end
local function Unpack(text)
  local fn = text and (loadstring or load)("return " .. text)
  local ok, t = pcall(fn or error)
  return ok and type(t) == "table" and t or nil
end
local function LoadRoute()
  ns._acceptSkipped = nil -- (11.10.) skipped accepts belong to the route they were skipped on
  -- (review round 4) moves of accepts kept in the saved variables (a /reload put them back); another route has others
  local ldb = LeveldonCharDB
  if ldb and ldb.laterKey ~= ns.LaterKeyOf(ldb) then ldb.laterMoves, ldb.pullMoves = nil, nil end
  -- (15.10., review round 2) those skipped by hand stay (/lvd dungeons on|off loads the route again)
  local cdb = LeveldonCharDB   -- ("db" is declared further down)
  if cdb and cdb.skipAcc then ns._acceptSkipped = {} for q in pairs(cdb.skipAcc) do ns._acceptSkipped[q] = true end end
  local race = PlayerRaceKey()
  local _, cls = UnitClass("player")
  cls = cls and cls:lower()
  if not race or not cls then return false end
  local addon = DATA_ADDON[race]
  local loader = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
  if addon and loader and not (LeveldonRoutes and LeveldonRoutes[race]) then pcall(loader, addon) end
  -- (22.10., Plan V3) the new form: the race's base route and the class's overlay (Merge.lua); the old form (one route per
  -- class) still loads
  local rt = LeveldonRoutes and LeveldonRoutes[race]
  local src = ns.RouteSource and ns.RouteSource(rt)
  local bands = src and src.bands or (rt and (rt[cls] or rt.warrior))
  if type(bands) ~= "table" then return false end
  -- (22.10.) a start area picked besides the race's own (/lvd line, options, Route): the race's own start chapter, then the
  -- second stage of that line; levels 30 to 60 stay the race's. Without the data it is the race's own route.
  local lineKey
  local pick = cdb and cdb.line
  if pick and ns.LINES and ns.LINES[race] and pick ~= ns.LINES[race].own then
    if loader and ns.DATA_LINES[race] and not (LeveldonLines and LeveldonLines[race]) then pcall(loader, ns.DATA_LINES[race]) end
    local alt = LeveldonLines and LeveldonLines[race] and LeveldonLines[race][pick]
    if type(alt) == "table" and type(alt.base) == "string" then
      src = { base = alt.base, dg = alt.dg, ovl = alt.ovl }   -- (22.10., Plan V3) the line's base and its overlays
      bands = { false, bands[2], bands[3] }
      lineKey = pick
    else
      alt = type(alt) == "table" and (alt[cls] or alt.warrior) or nil
      if type(alt) == "table" and type(alt[1]) == "string" then
        src = nil
        bands = { alt[1], bands[2], bands[3], dg = alt.dg or alt[1] }
        lineKey = pick
      end
    end
  end
  local merged = { race = race, cls = cls, steps = {}, early = {}, profOptions = {}, vendors = {}, keep = {}, dungeons = {}, links = {}, bonus = {}, ids = {}, line = lineKey }
  local seenD, hours = {}, 0
  local tOffset = 0 -- (0.1.8) the planned times (t) of a band count from its start: the next band's go on
  -- (12.10., Daniel: dungeons as optional blocks) /lvd dungeons on: the 1 to 30 band the builder planned with the
  -- dungeons of this faction (their quests before, the run at its level, the turn-ins after), where there is one
  local useDg = LeveldonCharDB and LeveldonCharDB.dungeons and type((src or bands).dg) == "string"
  merged.withDungeons = useDg or nil
  for bi, text in ipairs(bands) do
    local t
    if bi == 1 and src then
      local gotDg
      t, gotDg = ns.BaseBand(src, cls, useDg)
      useDg = gotDg or nil   -- (Merge.lua) without the class's dungeon overlay the plain route
      merged.withDungeons = useDg
    else
      if bi == 1 and useDg then text = bands.dg end
      t = Unpack(text)
    end
    if t then
      -- (13.10., data plan: route id in every recording) the id of each band you play (export_route.route_id)
      if type(t.id) == "string" then merged.ids[#merged.ids + 1] = t.id end
      hours = hours + (tonumber(t.hours) or 0)
      local bandMax = 0
      for k, st in ipairs(t.steps or {}) do
        if type(st.t) == "number" then
          if st.t > bandMax then bandMax = st.t end
          st.t = st.t + tOffset
        end
        merged.steps[#merged.steps + 1] = st
        if t.hubopt then st._ho = true end
        -- (13.10., Daniel: levels 30 to 60 ship at launch as a preview) the bands after 1 to 30 are not played yet
        if bi > 1 then st._pv = true end -- (11.10.) its hubs already ordered by the builder (hubopt.py)
        -- the next band starts where the last one ended in another zone: travel to its first chapter
        if bi > 1 and k == 1 and st.k == "chapter" and not (t.steps[2] and t.steps[2].k == "travel") then
          merged.steps[#merged.steps + 1] = { k = "travel", n = st.n, ne = st.ne, el = st.el }
        end
      end
      tOffset = tOffset + bandMax
      if bi == 1 then merged.early, merged.profOptions = t.early or {}, t.profOptions or {} end
      for _, v in ipairs(t.vendors or {}) do merged.vendors[#merged.vendors + 1] = v end
      for k, v in pairs(t.keep or {}) do merged.keep[k] = merged.keep[k] or v end
      for _, d in ipairs(t.dungeons or {}) do if not seenD[d.id] then seenD[d.id] = true merged.dungeons[#merged.dungeons + 1] = d end end
      if bi == 1 then merged.links = t.links or {} end
      for k, v in pairs(t.bonus or {}) do merged.bonus[k] = merged.bonus[k] or v end
    end
  end
  if #merged.steps == 0 then return false end
  ROUTE = merged
  IndexRoute()
  routeInfo = (L["%s %s%s, %d steps, about %.0f h"]):format(race, cls,
    (lineKey and L[" via %s"]:format(ns.LineTitle(lineKey)) or "") .. (useDg and L[" with dungeons"] or ""), #merged.steps, hours)
  return true
end
ns.LoadRoute = LoadRoute
ns.RouteInfo = function() return routeInfo end
local NEXT_SHOWN = 3
local GRAY = 8 -- a quest this many levels below the character is skipped

local db
local panel
local cur = 1
-- (13.10., Daniel's mage Zip: logged out at "turn in Lost Necklace", after the login Leveldon sent him to the mine,
-- Billy still stood there with his quest) the step number alone counts the steps Leveldon put in while you played
-- (trainer and vendor visits); after a login the route is composed without them and the same number is three steps
-- further. So the route step itself is saved too (its index in the route, or the next route step's for a step
-- that was put in) and found again after the login.
-- (15.10., review round 3) what a step is, for steps Compose builds anew and for saving: kind, quest, item, skill, name,
-- level, route index
function ns.StepKey(t)
  return table.concat({ t.k or "", t.q or "", t.i or "", t.sk or "", t.n or "", t.lvl or "", t._i or "" }, "|")
end
function ns.LaterMove(q, after)
  if not db then return end
  db.laterMoves = db.laterMoves or {}
  db.laterMoves[q] = after
  db.laterKey = ns.LaterKeyOf(db)
end
function ns.SaveStep()
  if not db then return end
  db.step = cur
  local ri
  -- (15.10., review round 3) not a step moved or copied here (a retaken accept, a pulled class quest): its route index
  -- is somewhere else
  local function Own(t)
    return t._i and not t._retake and t._pulled ~= ns._composeId and t._nearPulled ~= ns._composeId and t._movedLater ~= ns._composeId
  end
  for j = cur, #STEPS do if STEPS[j] and Own(STEPS[j]) then ri = STEPS[j]._i break end end
  db.stepRi = ri
  -- and what the step is (a buy or a hub trainer stop has no route index: found again first)
  local c = STEPS[cur]
  -- (review round 4) not for a retaken copy or a later buy: their key is the original's, which lies behind
  db.stepKey = c and not c._retake and not c._later and c._nearPulled ~= ns._composeId and ns.StepKey(c) or nil
  -- (15.10., review round 3) and the route steps not done from here on: a step moved to here (ClassNow,
  -- FinishNearbyFirst) has its own index from further on, and the login went past 20 open steps; it goes back to
  -- the first of them in the route as composed after the login
  local ris = {}
  for j = cur, math.min(#STEPS, cur + 40) do
    local t = STEPS[j]
    if t and Own(t) and (j == cur or not (ns.LeveldonStepDone and ns.LeveldonStepDone(j))) then ris[#ris + 1] = t._i end
  end
  db.stepRis = ris
  -- (13.10.) and the next quest step itself: after a new build of the route (other step numbers) it is found again
  db.stepK, db.stepQ = nil, nil
  for j = cur, #STEPS do
    local t = STEPS[j]
    if t and t._i and t.q and (t.k == "accept" or t.k == "do" or t.k == "turnin") then db.stepK, db.stepQ = t.k, t.q break end
  end
end
function ns.RestoreStep()
  if not db or not db.step then return nil end
  if type(db.stepRi) ~= "number" then return db.step end
  local best
  for j = 1, #STEPS do
    if STEPS[j]._i == db.stepRi and (not best or math.abs(j - db.step) < math.abs(best - db.step)) then best = j end
  end
  if best and type(db.stepRis) == "table" and #db.stepRis > 0 then
    local want = {}
    for _, r in ipairs(db.stepRis) do want[r] = true end
    for j = 1, #STEPS do
      if want[STEPS[j]._i] and j < best and best - j <= 60 then best = j break end
    end
  end
  -- (15.10., review round 3) the step itself near there (a buy, a hub trainer stop)
  if best and type(db.stepKey) == "string" then
    for d = 0, 25 do
      for _, j in ipairs(d == 0 and { best } or { best - d, best + d }) do
        local t = STEPS[j]
        if t and ns.StepKey(t) == db.stepKey then return j end
      end
    end
  end
  return best or db.step
end
-- (15.10., review round 1) keyed by the step itself, not its number: steps put in or taken out (a sell or trainer
-- stop, a recompose) no longer hand a mark to the wrong step (a hunter's flight-point mark skipped the sell step)
local marks = setmetatable({}, { __mode = "k" }) -- non-quest steps done this session: [step] = true
ns.LeveldonMarks = function() return marks end -- (tests)
local bindAtStep
local Update -- below (forward declaration)

-- (0.1.3) the Forever client has the modern API in places: spell names, auras and item counts both ways
local function SpellName(id)
  if not id then return nil end
  if C_Spell and C_Spell.GetSpellName then local ok, n = pcall(C_Spell.GetSpellName, id) if ok and n then return n end end
  if GetSpellInfo then local ok, n = pcall(GetSpellInfo, id) if ok then return n end end
  return nil
end
local function Buff(unit, i)
  if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
    local ok, d = pcall(C_UnitAuras.GetBuffDataByIndex, unit, i)
    if not ok or type(d) ~= "table" then return nil end
    return d.name, d.expirationTime
  end
  local f = UnitBuff or (UnitAura and function(u, n) return UnitAura(u, n, "HELPFUL") end)
  if not f then return nil end
  local name, _, _, _, _, expires = f(unit, i)
  return name, expires
end
local function ItemCount(id)
  if C_Item and C_Item.GetItemCount then local ok, n = pcall(C_Item.GetItemCount, id) if ok and n then return n end end
  if GetItemCount then local ok, n = pcall(GetItemCount, id) if ok and n then return n end end
  return 0
end

-- (0.1.6, Daniel 10.10.) secret values (Midnight rules) count as missing: they never reach a comparison
local function Usable(v)
  if v == nil then return false end
  if canaccessvalue then local ok, r = pcall(canaccessvalue, v) return ok and r and true or false end
  if issecretvalue then local ok, r = pcall(issecretvalue, v) return ok and not r end
  return true
end
-- the first result of fn(...): nil when fn is missing, fails or answers with a secret value
local function Val(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if ok and Usable(v) then return v end
  return nil
end
local function InCombat() return Val(InCombatLockdown) == true end
-- the item's name in the client's language when the game knows it, else the English one
local function ItemName(id, fallback)
  local n = C_Item and Val(C_Item.GetItemNameByID, id)
  if type(n) == "string" and n ~= "" then return n end
  return fallback
end


-- (13.10., Daniel's hunter Don at Applejack Still: "path starts at 28, 59 ... should be mentioned, otherwise you do
-- not find it"; "too hard in parts, 3 Defias in front of it") hints players gave for a quest, per step kind
ns.STEP_NOTES = {
  [91736] = {
    accept = L["  (the way up starts at 28, 59; Defias stand around the still)"],
    ["do"] = L["  (4 Shiny Red Apples make a Thunder Applejack: keep it for Sergeant De Vries in Westbrook Garrison, in the building on the left; it starts An Apple Treat)"],
  },
}

local VERB = {
  accept = L["Accept"], ["do"] = L["Do"], turnin = L["Turn in"], fp = L["Flight point"], bind = L["Make this inn your home"],
  hearth = L["Use your hearthstone"], train = L["Visit your trainer"], travel = L["Travel to"], grind = L["Grind"],
  profs = L["Choose your professions"], learn = L["Learn"], skillup = L["Raise"], buy = L["Buy"], use = L["Use"], farm = L["Farm"],
  sell = L["Sell your loot"], die = L["Let yourself die"],
}
local VERSION = "0.2.7"
do -- (23.10., 0.2.5 showed "beta 0.2.4") the toc's version wins, so the two cannot drift apart again
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  local ok, v = false, nil
  if get then ok, v = pcall(get, "Leveldon", "Version") end
  v = ok and type(v) == "string" and v:match("^(%d+[%d%.]*)") or nil
  if v then VERSION = v end
end
ns.LeveldonVersion = VERSION

-- (0.1.6, Daniel 10.10.) the texts of this version in one place (for the translations later)
local T = {
  fishCook = L["catch about %d fish and keep every %s: you cook them for Cooking"],
  cookFish = L["cook about %d %s with %s at a cooking fire (Basic Campfire: Simple Wood and Flint and Tinder, or a town's fire)"],
  eitherFish = L["%s or %s"],
  marksOn = L["stops on the map: on (trainer, vendor, flight master and inn of the current step get the map pin)"],
  marksOff = L["stops on the map: off"],
  trackerOn = L["Blizzard's quest tracker: hidden"],
  trackerOff = L["Blizzard's quest tracker: shown"],
  trackerButtonShow = L["Quest tracker: show"],
  trackerButtonHide = L["Quest tracker: hide"],
  trackerTip = L["Leveldon hides Blizzard's quest tracker (Leveldon's window guides you). Click to switch."],
  profsTitle = L["  professions"],
  profsPrimary = L["Primary professions: %d of 2"],
  profsSecondary = L["Secondary professions"],
  profsPicked = L["picked"],
  profsKnown = L["learned, %d"],
  profsHave = L["Already learned: %s"],
  profsHaveNone = L["No profession learned yet."],
  profsFound = L["professions found: %s. Nothing missing, no choice needed (/lvd profs to change)."],
  profsKindPrimary = L["Primary"],
  profsKindSecondary = L["Secondary"],
  profsNeeds = L["Needs: %s"],
  profsTrainer = L["Trainer: %s"],
  profsTrainerNone = L["Trainer: not on this route"],
  profsDone = L["Done: take me to the trainers"],
  profsNone = L["No professions"],
  profsFoot = L["Point at a profession: what it needs and where its trainer is."],
  profsClickHint = L["Click: pick or drop it"],
  profsFullHint = L["Two primary professions picked: drop one first"],
  profsNoneSaid = L["no professions: the route leaves all profession steps out (/lvd profs to choose again)."],
  bookChoose = L["  (choose %s as your reward: it teaches %s)"],
  bookUse = L["Use %s from your bags: you learn %s (+2 skill)"],
  bookOther = L["  (took another reward? skip this step)"],
  farmBook = L["Keep killing %s until the %s drops: it starts the quest with the profession book"],
  buyLater = L["%s: buy later, you need %s"],
  buyNear = L["%s sells %s: buy it now"],
}

-- (0.1.6, Daniel 10.10.) the start areas' reward books for a gathering profession (ATT, MIT: rewards of the
-- start areas' quests; Leveldon counts a book as learning its profession). Each start area has one quest
-- offering the three as a choice. Only used when the player chose a
-- gathering profession; otherwise the quest stays an ordinary quest.
local GATHER_BOOK = {
  [186] = { i = 247840, n = "Mining for Dummies" },
  [393] = { i = 247846, n = "Pelt Collecting for Beginners" },
  [182] = { i = 247841, n = "Wild Harvest" },
}
local GATHER_ORDER = { 182, 186, 393 }
ns.GATHER_REMIND = { [182] = L["Pick herbs on the way: Herbalism %d of %d"], [186] = L["Mine ore veins on the way: Mining %d of %d"],
  [393] = L["Skin what you kill on the way: Skinning %d of %d"] }
-- Rascally Rodents (Northshire), Coldridge Valley Mail Delivery, The Woodland Protector, A Humble Task,
-- Galgar's Cactus Apple Surprise, Marla's Last Wish, Harvesting Windstones (Zephras Isle)
-- (0.1.6, Daniel 10.10.: "Brother Paxton does not offer it without the book; it dropped within the first
-- 10 kobolds every time") Northshire's book quest only comes through the Nibbled-On Book: with a gathering
-- profession chosen, the route keeps you on the Kobold Vermin of Kobold Camp Cleanup until it drops and
-- takes the book chain along (otherwise it comes in by itself when the book drops, as before)
-- (12.10., Daniel's mage without professions: "the kobolds were done before the book dropped, I went on killing
-- until it dropped 4 to 6 mobs later") the chain is worth it for everyone (about 1,500 XP up to Goldshire):
-- all = true keeps every character on the kobolds until the book drops
local FARM_BOOK = { [91741] = { after = 7, i = 247834, n = "Nibbled-On Book", mob = "Kobold Vermin", all = true } }
local BOOK_QUESTS = { [91743] = true, [234] = true, [458] = true, [752] = true, [4402] = true, [6395] = true, [93552] = true }

-- (0.1.6, Daniel 10.10.: "the route sends you to raise Fishing anyway") the faction's first fish and its
-- recipe (CMaNGOS classic-db, GPL v3: both recipes need Cooking 1; the Forever client's SkillLineAbility via
-- ATT, MIT: skill-ups up to Cooking 85, green from 45)
local FIRST_FISH = {
  Alliance = { fish = 6291, fishN = "Raw Brilliant Smallfish", recipe = 6325, recipeN = "Recipe: Brilliant Smallfish", spell = 7751 },
  Horde = { fish = 6303, fishN = "Raw Slitherskin Mackerel", recipe = 6326, recipeN = "Recipe: Slitherskin Mackerel", spell = 7752 },
}
local FISH_CATCH, FISH_COOK = 25, 20
local HORDE_RACE = { orc = true, undead = true, tauren = true, troll = true, skyborne_h = true }
local function Faction()
  local f = Val(UnitFactionGroup, "player")
  if f == "Alliance" or f == "Horde" then return f end
  local r = ROUTE.race or PlayerRaceKey()
  if r then return HORDE_RACE[r] and "Horde" or "Alliance" end
  return nil
end
-- the fish to keep and the recipe to cook it with (both factions' when the faction is unknown)
local function FirstFish()
  local ff = FIRST_FISH[Faction() or ""]
  if ff then return ItemName(ff.fish, ff.fishN), ItemName(ff.recipe, ff.recipeN) end
  local a, h = FIRST_FISH.Alliance, FIRST_FISH.Horde
  return T.eitherFish:format(ItemName(a.fish, a.fishN), ItemName(h.fish, h.fishN)),
    T.eitherFish:format(ItemName(a.recipe, a.recipeN), ItemName(h.recipe, h.recipeN))
end

---------------------------------------------------------------------------
-- (0.1.1, Daniel 09.10.) Professions: at most two primary ones, every secondary
-- one. The route stops at the first profession quest ("Camping 101" at the
-- campfire) and asks; steps of professions you did not pick are left out,
-- picked ones the route was not computed with are put in (learn and accept
-- after the stop, raise to 20 and turn in at the end of that chapter).
---------------------------------------------------------------------------
local PRIMARY = { 171, 164, 333, 202, 182, 165, 186, 393, 197 }
local SECONDARY = { 129, 185, 356 }
local SKILL_EN = { [171] = "Alchemy", [164] = "Blacksmithing", [333] = "Enchanting", [202] = "Engineering", [182] = "Herbalism",
  [165] = "Leatherworking", [186] = "Mining", [393] = "Skinning", [197] = "Tailoring", [129] = "First Aid", [185] = "Cooking", [356] = "Fishing" }
-- the profession's own spell: its name is the skill line's name in the client's language
local PROF_SPELL = { [171] = 2259, [164] = 2018, [333] = 7411, [202] = 4036, [182] = 2366, [165] = 2108, [186] = 2575,
  [393] = 8613, [197] = 3908, [129] = 3273, [185] = 2550, [356] = 7620 }
-- Herbalism's spell is "Herb Gathering": the skill line's own names
local HERB = { "Herbalism", "Kräuterkunde", "Herboristerie", "Herboristería", "Herborismo", "Травничество", "약초 채집", "草藥學", "草药学" }

-- Your rank in a profession, nil when you do not have it.
-- (0.1.4, Daniel 09.10.: First Aid learned, the step did not go on) the skill window only lists the lines
-- of open sections: with "Secondary Skills" collapsed, First Aid is not there. Then the profession's spell
-- tells that it is learned, and the rank comes from the chat ("Your skill in First Aid has increased to 21")
-- (12.10.) names in the client's language: a profession by its spell, a quest by Questdon (the game's title), a
-- chapter by the locale (the routes carry the German name n and the English one ne)
function ns.PName(sk) return (sk and SpellName(PROF_SPELL[sk])) or SKILL_EN[sk] or "?" end
function ns.QName(s)
  local a = s and s.q and QuestdonAPI
  local t = a and a.QuestTitle and a.QuestTitle(s.q)
  if type(t) == "string" and t ~= "" then return t end
  return s and s.n
end
function ns.ChName(s)
  if not s then return "?" end
  if ns.LOCALE == "deDE" then return s.n or s.ne or "?" end
  return s.ne or s.n or "?"
end
-- (17.10., memory) kept per skill once the spell's name is known (read only by the callers)
local SkillNames
do
local skillNames = {}
function SkillNames(sk)
  if skillNames[sk] then return skillNames[sk] end
  local names = {}
  local n = SpellName(PROF_SPELL[sk])
  if n then names[n] = true end
  names[SKILL_EN[sk] or ""] = true
  if sk == 182 then for _, h in ipairs(HERB) do names[h] = true end end
  if n or not PROF_SPELL[sk] then skillNames[sk] = names end
  return names
end
end
local function Knows(spell)
  if not spell then return false end
  -- (17.10., memory) no new table and closure per call
  if IsPlayerSpell then local ok, v = pcall(IsPlayerSpell, spell) if ok and v then return true end end
  if IsSpellKnown then local ok, v = pcall(IsSpellKnown, spell) if ok and v then return true end end
  return false
end
-- (0.1.7, Daniel 11.10.: "skip the trainer when nothing worth learning for leveling comes at that level")
-- Training.lua: the class's trainer spells per level, each worth 2 (worth the trip on its own), 1 (nice) or 0.
-- What waits up to a level: not known yet, not planned at an earlier visit, a talent's rank only with the
-- talent. A visit is worth it with something worth 2, three worth 1, or six levels since the last visit.
ns.TR = {} -- (0.1.7) the trainer helpers (no new main-chunk local: Lua allows 200)
function ns.TR.Data()
  local _, cls = UnitClass("player")
  return ns.TRAINING and cls and ns.TRAINING[cls] or nil
end
-- (15.10., Daniel: "recommend by the talents") the talent tree with the most points (5 or more, ahead of the others):
-- Training.lua's TRAINING_SPEC turns its spells into main spells (add) and others into your choice (drop)
function ns.TR.Spec()
  if not (GetNumTalentTabs and GetTalentTabInfo) then return nil end
  local best, bp, second = nil, 0, 0
  for t = 1, (GetNumTalentTabs() or 0) do
    local r = { GetTalentTabInfo(t) }
    local pts = (type(r[1]) == "string" and r[3]) or r[5]
    if type(pts) ~= "number" and GetNumTalents and GetTalentInfo then
      pts = 0
      for i = 1, (GetNumTalents(t) or 0) do pts = pts + (tonumber((select(5, GetTalentInfo(t, i)))) or 0) end
    end
    pts = tonumber(pts) or 0
    if pts > bp then best, second, bp = t, bp, pts elseif pts > second then second = pts end
  end
  if best and bp >= 5 and bp > second then return best end
  return nil
end
function ns.TR.Imp(e, spec)
  local _, cls = UnitClass("player")
  local sp = spec and ns.TRAINING_SPEC and cls and ns.TRAINING_SPEC[cls] and ns.TRAINING_SPEC[cls][spec]
  if sp then
    for _, n in ipairs(sp.add) do if n == e[5] then return 2 end end
    for _, n in ipairs(sp.drop) do if n == e[5] then return math.min(e[2], 1) end end
  end
  return e[2]
end
function ns.TR.Pending(toLv, planned)
  local data = ns.TR.Data()
  if not data then return nil end
  local list, twos, ones = {}, 0, 0
  local spec = ns.TR.Spec()
  for lv = 1, toLv do
    for _, e in ipairs(data[lv] or {}) do
      local id, imp, prev, tal = e[1], ns.TR.Imp(e, spec), e[3], e[4]
      if not (planned and planned[id]) and not Knows(id) and (tal == 0 or Knows(prev)) then
        list[#list + 1] = e
        if imp == 2 then twos = twos + 1 elseif imp == 1 then ones = ones + 1 end
      end
    end
  end
  return twos, ones, list
end
-- (15.10., Daniel: "the super saving mode, recommend the spells to learn; whether the player learns more he can
-- decide himself") a trainer visit only for the main spells (worth 2): the gold goes to riding at 40
function ns.TR.Worth(twos, ones, gap) return twos > 0 end
ns.LeveldonPendingTraining = ns.TR.Pending -- (tests)
local function SkillRank(sk)
  local names = SkillNames(sk)
  if GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() do
      local name, isHeader, _, rank = GetSkillLineInfo(i)
      if name and not isHeader and names[name] then
        rank = tonumber(rank) or 0
        if LeveldonCharDB then LeveldonCharDB.ranks = LeveldonCharDB.ranks or {} LeveldonCharDB.ranks[sk] = rank end
        return rank
      end
    end
  end
  local saved = LeveldonCharDB and LeveldonCharDB.ranks and LeveldonCharDB.ranks[sk]
  if saved then return saved end
  if Knows(PROF_SPELL[sk]) then return 1 end
  return nil
end
-- "You have learned a new spell: First Aid." (also when the skill window hides the line)
local function OnSystemMessage(msg)
  if not (msg and LeveldonCharDB) then return end
  for _, g in ipairs({ ERR_LEARN_SPELL_S, ERR_LEARN_ABILITY_S, ERR_LEARN_RECIPE_S }) do
    local pat = g and g:gsub("([%.%(%)%-%+%[%]%^%$%?%*])", "%%%1"):gsub("%%s", "(.+)")
    local name = pat and msg:match(pat)
    if name then
      name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("^%[", ""):gsub("%]$", "")
      for sk in pairs(PROF_SPELL) do
        if SkillNames(sk)[name] then
          LeveldonCharDB.ranks = LeveldonCharDB.ranks or {}
          LeveldonCharDB.ranks[sk] = LeveldonCharDB.ranks[sk] or 1
        end
      end
    end
  end
end

-- "Your skill in %s has increased to %d."
local function OnSkillMessage(msg)
  local pat = SKILL_RANK_UP and SKILL_RANK_UP:gsub("([%.%(%)%-%+%[%]%^%$%?%*])", "%%%1"):gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
  if not (pat and msg and LeveldonCharDB) then return end
  local name, rank = msg:match(pat)
  if not name then return end
  for sk in pairs(PROF_SPELL) do
    if SkillNames(sk)[name] then
      LeveldonCharDB.ranks = LeveldonCharDB.ranks or {}
      LeveldonCharDB.ranks[sk] = tonumber(rank)
    end
  end
end
ns.SkillRank = SkillRank -- (tests)

local function API() return QuestdonAPI end
local function Level() return UnitLevel and UnitLevel("player") or 1 end
local function Map() return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil end
-- (11.10.) the player's position on the current map in percent, or nil
-- (23.10., /lvd mem) Questdon's position first (UnitPosition, no table): C_Map.GetPlayerMapPosition makes a new vector
-- with all of Vector2DMixin's functions at every call
function ns.PlayerXY()
  local m = Map()
  local a = QuestdonAPI
  if m and a and a.PlayerPosition then
    local ok, qm, qx, qy = pcall(a.PlayerPosition)
    if ok and qm == m and type(qx) == "number" and type(qy) == "number" then return qx * 100, qy * 100 end
  end
  local p = m and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(m, "player")
  if not (p and p.GetXY) then return nil end
  local x, y = p:GetXY()
  if not (x and y) then return nil end
  return x * 100, y * 100
end


local function QuestDone(q)
  local a = API()
  if a and a.IsQuestDone then return a.IsQuestDone(q) and true or false end
  return C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(q) or false
end
local function InLog(q) local a = API() return a and a.InQuestLog and a.InQuestLog(q) and true or false end
local function Complete(q) local a = API() return a and a.IsQuestComplete and a.IsQuestComplete(q) and true or false end

-- the game's open objectives of a quest in the log ("0/8 Milly's Harvest")
local function OpenObjectives(q)
  local ok, objs = pcall(C_QuestLog and C_QuestLog.GetQuestObjectives or function() end, q)
  local open = {}
  for _, o in ipairs(ok and type(objs) == "table" and objs or {}) do
    if not o.finished and o.text and o.text ~= "" then open[#open + 1] = o.text end
  end
  return open
end

-- (0.1.4, Daniel 09.10.: Milly's Harvest wanted the turn-in right after the accept) a turn-in whose
-- quest still has open objectives is shown and guided as "do" until they are finished
-- (11.10., Daniel: "why salve and belt twice in Next, I'm doing that right now") a turn-in whose quest is not
-- finished reads "Do" only as the current step; in the Next list it stays "Turn in"
local function Kind(s, upcoming)
  if s and not upcoming and s.k == "turnin" and s.q and InLog(s.q) and not Complete(s.q) and #OpenObjectives(s.q) > 0 then return "do" end
  return s and s.k
end

local function MapName(m)
  local info = m and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(m)
  return info and info.name or (m and (L["Map "] .. m)) or "?"
end

-- The place of a step; travel uses the next step that has one.
local function Place(i)
  for j = i, math.min(#STEPS, i + 8) do
    local s = STEPS[j]
    -- (11.10.) Cooking without what a campfire needs: at the fire by the cooking trainer (Fit.lua CookAtFire)
    if s and s.k == "skillup" and s.fireM and ns.NoCampfire and ns.NoCampfire() then return s.fireM, s.fireX, s.fireY end
    if s and s.m then return s.m, s.x, s.y end
  end
end

local function IsQuestStep(s) return s.k == "accept" or s.k == "do" or s.k == "turnin" end

-- (0.1.3, Daniel 09.10.) a quest Questdon says this character cannot get, not even at a higher level
-- (prerequisite not done, faction, race, class, unknown to the server): its accept, do and turn-in
-- steps are skipped instead of waiting for them. Questdon's API 2 (CanTakeQuestLater).
local blocked = {}
local function Blocked(q)
  if not q then return false end
  if blocked[q] ~= nil then return blocked[q] end
  local a = API()
  if not (a and a.CanTakeQuestLater) or QuestDone(q) or InLog(q) then return false end
  local ok, can = pcall(a.CanTakeQuestLater, q)
  if ok and can == false then blocked[q] = true return true end
  return false
end

-- (0.1.6 playtest 1, Daniel 10.10.: "at the vendor I had no money for the pick") what the tools cost, in
-- copper (22.10., tools/open/build_vendor_prices.py): ForeverDB's vendor prices in Forever (GPL v3, ns.sold),
-- the highest among its vendors
local BUY_PRICE = { [2901] = 10, [7005] = 10, [6256] = 23, [6529] = 50, [6325] = 40, [6326] = 40, [5956] = 18 }
-- (playtest 1) who sells them (22.10., the same script): CMaNGOS classic-db (GPL v3, npc_vendor) and ForeverDB,
-- only the vendors that Leveldon's routes know (their places come from the route's vendor list and buy data)
local SELLS = {} -- vendor name -> { [item] = true }
do
local SELLERS_OF = {
  [2901] = "Abigail Shiel;Andrew Hilbert;Banalash;Billibub Cogspinner;Brother Danil;Christoph Jeffcoat;Christopher Hewen;Dalria;Drake Lindgren;Edna Mullby;Elisa Steelhand;Elizabeth Van Talen;Felicia Doan;Felika;Flakk;Gigget Zipcoil;Gina MacGregor;Helenia Olden;Herble Baubbletump;Jandia;Jase Farlane;Keena;Kireena;Kulwia;Lah'Mawhani;Lorelae Wintersong;Loslor Rudge;Micha Yance;Mishta;Narret Shadowgrove;Neal Allen;Nerrist;Qia;Ranik;Samuel Van Brunt;Shadi Mistrunner;Shandrina;Sheendra Tallgrass;Shimra;Syurana;Tai'tasi;Tari'qa;Taur Stonehoof;Tharynn Bouden;Thrawn Boltar;Ullanna;Vivianna;Wunna Darkmane",
  [7005] = "Abigail Shiel;Andrew Hilbert;Banalash;Bombus Finespindle;Brother Danil;Christopher Hewen;Dalria;Drake Lindgren;Duokna;Edna Mullby;Felicia Doan;Felika;Flakk;Gigget Zipcoil;Gina MacGregor;Helenia Olden;Jase Farlane;Keena;Kulwia;Lah'Mawhani;Lorelae Wintersong;Mishta;Narret Shadowgrove;Nerrist;Qia;Ranik;Shadi Mistrunner;Shandrina;Sheendra Tallgrass;Shimra;Syurana;Tai'tasi;Tamar;Tari'qa;Tharynn Bouden;Ullanna;Vivianna;Wunna Darkmane",
  [6256] = "Abigail Shiel;Andrew Hilbert;Banalash;Catherine Leland;Christopher Hewen;Dalria;Drake Lindgren;Edna Mullby;Felicia Doan;Felika;Flakk;Gigget Zipcoil;Gina MacGregor;Gretta Ganter;Harn Longcast;Helenia Olden;Jase Farlane;Keena;Kulwia;Lah'Mawhani;Lorelae Wintersong;Martine Tramblay;Mishta;Narret Shadowgrove;Nerrist;Nessa Shadowsong;Qia;Ranik;Shadi Mistrunner;Shandrina;Sheendra Tallgrass;Shimra;Syurana;Tai'tasi;Tari'qa;Tharynn Bouden;Ullanna;Vivianna;Voloren;Wunna Darkmane;Zansoa",
  [6529] = "Abigail Shiel;Andrew Hilbert;Catherine Leland;Christopher Hewen;Drake Lindgren;Felicia Doan;Felika;Flakk;Gina MacGregor;Gretta Ganter;Harn Longcast;Kulwia;Lah'Mawhani;Martine Tramblay;Narret Shadowgrove;Nessa Shadowsong;Ranik;Shimra;Tai'tasi;Tari'qa;Tharynn Bouden;Ullanna;Voloren;Wunna Darkmane;Zansoa",
  [6325] = "Catherine Leland;Gretta Ganter;Harn Longcast;Martine Tramblay;Tharynn Bouden",
  [6326] = "Martine Tramblay;Nessa Shadowsong;Zansoa",
  [5956] = "Abigail Shiel;Andrew Hilbert;Banalash;Billibub Cogspinner;Christoph Jeffcoat;Christopher Hewen;Dalria;Drake Lindgren;Edna Mullby;Elisa Steelhand;Elizabeth Van Talen;Felicia Doan;Felika;Flakk;Gigget Zipcoil;Gina MacGregor;Helenia Olden;Herble Baubbletump;Jandia;Jase Farlane;Keena;Kireena;Kulwia;Lah'Mawhani;Lorelae Wintersong;Loslor Rudge;Micha Yance;Mishta;Narret Shadowgrove;Neal Allen;Nerrist;Qia;Ranik;Samuel Van Brunt;Shadi Mistrunner;Shandrina;Sheendra Tallgrass;Shimra;Syurana;Tai'tasi;Tari'qa;Taur Stonehoof;Tharynn Bouden;Thrawn Boltar;Ullanna;Vivianna;Wunna Darkmane",
}
for i, list in pairs(SELLERS_OF) do
  for n in list:gmatch("[^;]+") do SELLS[n] = SELLS[n] or {} SELLS[n][i] = true end
end
end
local function MoneyText(c)
  c = math.floor(c or 0)
  local g, sv, cp = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
  local out = {}
  if g > 0 then out[#out + 1] = g .. L[" gold"] end
  if sv > 0 then out[#out + 1] = sv .. L[" silver"] end
  if cp > 0 or #out == 0 then out[#out + 1] = cp .. L[" copper"] end
  return table.concat(out, " ")
end
local function Money() local m = Val(GetMoney) return type(m) == "number" and m or nil end
-- not enough money for this item now (unknown price or money: no)
local function CantAfford(i)
  local p, m = BUY_PRICE[i], Money()
  return p ~= nil and m ~= nil and m < p
end
-- (23.10., Daniel's Skyborne druid Lauranvilis 18.10.: "if fishing is skipped you do not need these", "what for?") the
-- professions whose learning lies behind the current step, skipped (by hand, or gone by at the trainer) and not known:
-- their buys, skill-ups and Camping 101 steps go by. The learn steps of the route are listed once per route.
function ns.LearnPassed(sk)
  local c = ns._lpc
  if not c or c.steps ~= STEPS or c.n ~= #STEPS then
    c = { steps = STEPS, n = #STEPS, at = {} }
    for j, t in ipairs(STEPS) do
      if t.k == "learn" and t.sk then c.at[#c.at + 1] = j end
    end
    ns._lpc = c
  end
  for _, j in ipairs(c.at) do
    local t = STEPS[j]
    if j >= cur then break end
    if t.sk == sk and (marks[t] or (db and db.skipKeys and db.skipKeys[ns.StepKey(t)])) then return true end
  end
  return false
end
local function StepDone(i)
  local s = STEPS[i]
  if not s then return true end
  if s.sk and s.k ~= "learn" and s.k ~= "profs" and s.k ~= "use" and ns.LearnPassed(s.sk) and SkillRank(s.sk) == nil then return true end
  if (s.k == "accept" or s.k == "do" or s.k == "turnin") and s.q and blocked[s.q] then return true end
  -- only for the current step: a later quest's prerequisite may still come before it on the route
  if i == cur and s.k == "accept" and s.q and Blocked(s.q) then
    -- (15.10., review round 3) left out like one too high: its do and turn-in go by, and it comes back once
    -- Questdon allows it (ReturnLeftOut after a turn-in or a level; the cache is cleared then)
    ns._acceptSkipped = ns._acceptSkipped or {}
    ns._acceptSkipped[s.q] = true
    return true
  end
  if s.k == "chapter" then return true end
  if marks[s] then return true end
  -- (15.10., review round 3) a step skipped by hand that Compose builds anew (a tool buy), also after a /reload
  if db and db.skipKeys and db.skipKeys[ns.StepKey(s)] then return true end
  -- (0.2.3) a quest skipped by hand (right-click menu): all its steps go by
  if s.q and db and db.skipQ and db.skipQ[s.q] and (s.k == "accept" or s.k == "do" or s.k == "turnin" or s.k == "buy" or s.k == "farm") then return true end
  -- (0.1.7) a quest left out for now (not offered yet): its do and turn-in steps go by, unless you took it
  if (s.k == "do" or s.k == "turnin") and s.q and ns._acceptSkipped and ns._acceptSkipped[s.q] and not InLog(s.q) then return true end
  -- (13.10., Daniel's hunter Don: "Elmore's Task" at level 7 stayed the step, it needs 9) once left out for its
  -- level it stays left out wherever the route stands, until the level is there
  if s.k == "accept" and s.q and ns._acceptSkipped and ns._acceptSkipped[s.q] and ns.TooLowFor and ns.TooLowFor(s.q) then return true end
  -- (15.10., review round 2) an accept skipped by hand, after a /reload or /lvd reset too (it sat below the return)
  -- (db.skipAcc: skipped by hand or passed by following you; one left out for its level comes back with the level)
  if s.k == "accept" and s.q and db and db.skipAcc and db.skipAcc[s.q] and not InLog(s.q) then return true end
  if s.k == "accept" then return QuestDone(s.q) or InLog(s.q) end
  if s.k == "do" then return QuestDone(s.q) or (InLog(s.q) and Complete(s.q)) end
  if s.k == "turnin" then return QuestDone(s.q) end
  if s.k == "grind" then return Level() >= s.to end
  -- (11.10., Daniel's own Coldridge run) a death on purpose: from level 10 there is resurrection sickness, so the
  -- step goes by; done when you are alive again after dying, or when you walked to the spirit healer anyway
  if s.k == "die" then
    if Level() >= 10 then return true end
    local m = Map()
    local x, y = ns.PlayerXY()
    local healer = { m = s.gm, x = s.gx, y = s.gy }
    -- (12.10., Daniel: "I had not chosen Fishing, so the walk there was left out, but not the death to get back")
    -- the next place of the route is not by the spirit healer (a left-out step was the reason): no death
    local nm, nx, ny = Place(i + 1)
    if nm and not ns.Within({ m = nm, x = nx, y = ny }, healer, 300) then return true end
    -- (12.10.) close to the spirit healer already (Daniel was in Kharanos): walking is as quick, the step goes by
    return m ~= nil and s.gm == m and x ~= nil and ns.Within({ m = m, x = x, y = y }, healer, 250)
  end
  if s.k == "travel" then local m = Place(i + 1) return m ~= nil and Map() == m end
  if s.k == "train" then return Level() < (s.lvl or 0) or (db ~= nil and (db.trained or 0) >= (s.lvl or 0)) end
  if s.k == "profs" then return db ~= nil and db.profs ~= nil end
  if s.k == "dungeon" then
    -- (12.10.) a planned run lists its quests itself (qs); an offer takes them from the dungeon's list
    if s.qs then
      for _, q in ipairs(s.qs) do
        -- (15.10., review round 1) a quest of the run skipped by hand, blocked or left out does not hold the run
        local gone = (db and db.skipQ and db.skipQ[q]) or blocked[q] or (ns._acceptSkipped and ns._acceptSkipped[q] and not InLog(q))
        -- (15.10., review round 2) its accept moved behind the run (too low then): not done in this run
        if not gone and not InLog(q) and not QuestDone(q) then
          gone = true
          for j = 1, i - 1 do if STEPS[j].k == "accept" and STEPS[j].q == q then gone = false break end end
        end
        if not (gone or QuestDone(q) or (InLog(q) and Complete(q))) then return false end
      end
      return true
    end
    local d = DUNGEON_BY_ID[s.id]
    if not d then return true end
    for _, q in ipairs(d.quests) do if not (QuestDone(q.q) or (InLog(q.q) and Complete(q.q))) then return false end end
    return true
  end
  if s.k == "learn" then return SkillRank(s.sk) ~= nil end
  if s.k == "use" then
    if SkillRank(s.sk) ~= nil then return true end
    -- (24.10., Daniel's Skyborne warrior: "he no longer sees that I learned Mining", LeveldonCharDB without ranks) the
    -- book you had in your bags and no longer have counts as used, for every gathering book of every route
    if s.i and LeveldonCharDB then
      local seen = LeveldonCharDB.bookSeen
      if ItemCount(s.i) > 0 then
        if not (seen and seen[s.i]) then seen = seen or {} seen[s.i] = true LeveldonCharDB.bookSeen = seen end
      elseif seen and seen[s.i] then
        return true
      end
    end
    return false
  end
  if s.k == "farm" then return ItemCount(s.i) > 0 or InLog(s.q) or QuestDone(s.q) end
  -- (11.10.) a vendor stop put in when the bags were full or the money short (Fit.lua ns.CheckSell)
  if s.k == "sell" then
    -- (22.10., Daniel: "a fixed step at every hub visit with a vendor near") a stop the route plans (leveldon-build/
    -- pass_sell.py, no t0 yet): its clock starts when it becomes the step, and it goes by when nothing is worth
    -- selling (grey items, full bags, worn gear, ammunition: the check of the hub's own vendor stop)
    if s.t0 == nil and s.why == "hub" then
      if i ~= cur then return false end
      s.t0, s._planned = GetTime and GetTime() or 0, true
    end
    if (ns._merchantAt or -1e9) >= (s.t0 or 0) then return true end
    if s._planned and ns.HubSellWorth and not ns.HubSellWorth() then return true end
    return s.why == "bags" and ns.FreeSlots ~= nil and ns.FreeSlots() >= 4
  end
  -- (13.10., Daniel's hunter Don: Fishin' Time's bait) a quest's hand-in item from a vendor on the way: done with
  -- enough in the bags, or when the quest no longer needs it (done, objectives complete, left out, not offered)
  if s.k == "buy" and s.q then
    if ItemCount(s.i) >= (s.c or 1) or QuestDone(s.q) or (InLog(s.q) and Complete(s.q)) or blocked[s.q] then return true end
    if ns._acceptSkipped and ns._acceptSkipped[s.q] and not InLog(s.q) then return true end
    return ns.SKIP_QUESTS ~= nil and ns.SKIP_QUESTS[s.q] ~= nil
  end
  -- (0.1.5, Daniel 09.10.) the tool is in the bags or worn, the recipe is learned
  if s.k == "buy" then
    return ItemCount(s.i) > 0 or (IsEquippedItem ~= nil and IsEquippedItem(s.i) == true) or (s.sp ~= nil and Knows(s.sp))
  end
  if s.k == "skillup" then return (SkillRank(s.sk) or 0) >= (s.need or 20) end
  if s.k == "mount" then return ns.RidingKnown() end
  -- (15.10., review round 1) standing at the hearth's place already (walked or flew there): nothing to do
  if s.k == "hearth" and i == cur and s.m and s.x and Map() == s.m then
    local x, y = ns.PlayerXY()
    if x and ns.Within({ m = s.m, x = x, y = y }, s, 150) then return true end
  end
  if s.k == "bind" then
    local now = GetBindLocation and GetBindLocation()
    -- (22.10., Daniel: the hearthstone step stays open, but not once it is bound here) Fit.lua ns.BoundHere
    if ns.BoundHere and ns.BoundHere(s) then return true end
    -- (15.10., review round 1) bound a moment before the step came (the inn's turn-in first, the innkeeper on the
    -- way): a home changed in the last minutes close to this inn counts
    local ago = db and db.homeAt and GetTime and GetTime() - db.homeAt
    if ago and ago >= 0 and ago < 600 and s.m and s.x and Map() == s.m then
      local x, y = ns.PlayerXY()
      if x and ns.Within({ m = s.m, x = x, y = y }, s, 200) then return true end
    end
    -- (15.10., review round 1) the home before binding belongs to this bind step (the next inn's step was done at
    -- once: the home had changed since the first inn)
    return bindAtStep ~= nil and bindAtStep.s == s and now ~= nil and now ~= bindAtStep.at
  end
  return false
end
-- (11.10., Daniel: "not even a silver to learn Cooking, the recipe, the pole and the lure cost money") the
-- learning comes first: a buy for a profession not learned yet waits while its price would leave less than
-- the learning still ahead in this chapter (about LEARN_COST each; Daniel paid about a silver)
ns.LEARN_COST = 100
ns.BuyWaits = function(idx)
  local s = STEPS[idx]
  if not (s and s.k == "buy") then return false end
  if s.q then return false end -- (13.10.) a quest's item costs little and the quest needs it: no waiting
  if CantAfford(s.i) then return true end
  local p, m = BUY_PRICE[s.i], Money()
  if not (p and m) then return false end
  local need = (s.ck and SkillRank(s.ck) == nil) or (s.sk and SkillRank(s.sk) == nil)
  if not need then return false end
  local reserve = 0
  for j = idx + 1, math.min(#STEPS, idx + 120) do
    local t = STEPS[j]
    if t.k == "chapter" then break end
    if t.k == "learn" and t.sk and SkillRank(t.sk) == nil and not StepDone(j) then reserve = reserve + ns.LEARN_COST end
  end
  return m - p < reserve
end


-- (15.10., Daniel's mage Zip: "fresh in Goldshire I learned professions and then had no silver for training")
-- the money for your next class training (the main spells Leveldon recommends, Training.lua's TRAIN_COST from
-- open sources, see tools/open/build_training.py) from the last training up to the next even level
-- (15.10., review round 3) a dungeon's name in the client's language (Questdon has the map's own name), else the
-- route's English one
function ns.DgName(id, n)
  if not ns._dgNames then
    ns._dgNames = {}
    local ok, list = pcall(function() return QuestdonAPI and QuestdonAPI.Dungeons and QuestdonAPI.Dungeons() end)
    for _, e in ipairs(ok and type(list) == "table" and list or {}) do if e.inst and e.name then ns._dgNames[e.inst] = e.name end end
  end
  return ns._dgNames[id] or n
end
ns.TrainReserve = function()
  local _, cls = UnitClass("player")
  local t = ns.TRAIN_COST and cls and ns.TRAIN_COST[cls]
  if not t then return 0 end
  local lv = Level()
  local from, to = (db and db.trained) or 1, lv - lv % 2 + 2
  local sum = 0
  -- (15.10., review round 3) the main spells you do not know yet (a character that trained before Leveldon was
  -- installed knows them: no reserve for them), their prices from Training.lua
  local data, spec = ns.TR.Data(), ns.TR.Spec()
  if data then
    for l = from + 1, to do
      for _, e in ipairs(data[l] or {}) do
        if ns.TR.Imp(e, spec) == 2 and not Knows(e[1]) and (e[4] == 0 or Knows(e[3])) then sum = sum + (e[7] or 0) end
      end
    end
    return sum
  end
  for l = from + 1, to do if t[l] then sum = sum + (t[l][3] or t[l][2] or 0) end end
  return sum
end
-- a profession now would leave too little for that training: the money still missing (else nil)
ns.LearnShort = function(s)
  if not (s and s.k == "learn" and s.sk and SkillRank(s.sk) == nil) then return nil end
  local m = Money()
  if not m then return nil end
  local need = ns.LEARN_COST + ns.TrainReserve()
  if m >= need then return nil end
  return need - m
end


-- (15.10., review round 1) the trainer window is your class trainer's, not a hunter's pet trainer: one of its
-- services is a spell of your class (no services to read: yes, as before)
function ns.TR.IsClassTrainer()
  if not (GetNumTrainerServices and GetTrainerServiceInfo) then return true end
  local n = tonumber(GetNumTrainerServices()) or 0
  if n == 0 then return true end
  local data = ns.TR.Data()
  if not data then return true end
  local names = {}
  for _, list in pairs(data) do
    for _, e in ipairs(list) do
      names[e[5]] = true
      local sn = SpellName(e[1])
      if sn then names[sn] = true end
    end
  end
  for i = 1, n do
    local name = GetTrainerServiceInfo(i)
    if name and names[name] then return true end
  end
  return false
end
-- (15.10., the super saving mode) at the class trainer: what Leveldon recommends now, with the price, in the chat
function ns.TR.Recommend()
  local _, _, list = ns.TR.Pending(Level())
  if not list then return nil end
  local names, sum, other = {}, 0, 0
  local spec = ns.TR.Spec()
  for _, e in ipairs(list) do
    if ns.TR.Imp(e, spec) == 2 then
      names[#names + 1] = (SpellName(e[1]) or e[5]) .. ((e[6] or 1) > 1 and (" " .. e[6]) or "")
      sum = sum + (e[7] or 0)
    else
      other = other + 1
    end
  end
  local msg
  if #names > 0 and other == 0 then   -- (15.10., review round 1) no "The other 0 spells"
    msg = (L["|cff3fa9f5Level|rdon recommends: %s (%s)."]):format(table.concat(names, ", "), MoneyText(sum))
  elseif #names > 0 and other == 1 then
    msg = (L["|cff3fa9f5Level|rdon recommends: %s (%s). The other spell is your choice: the gold goes to riding at 40."]):format(
      table.concat(names, ", "), MoneyText(sum))
  elseif #names > 0 then
    msg = (L["|cff3fa9f5Level|rdon recommends: %s (%s). The other %d spells are your choice: the gold goes to riding at 40."]):format(
      table.concat(names, ", "), MoneyText(sum), other)
  elseif other == 1 then
    msg = L["|cff3fa9f5Level|rdon: nothing important here now; the spell is your choice (the gold goes to riding at 40)."]
  elseif other > 0 then
    msg = (L["|cff3fa9f5Level|rdon: nothing important here now; the %d spells are your choice (the gold goes to riding at 40)."]):format(other)
  end
  if msg then print(msg) end
  return msg
end
-- (15.10., Daniel: "stay at 40") riding at 40 costs 100 gold training and 20 gold for the mount (Warcraft Tavern,
-- Forever riding guide); without the money the route goes on and Leveldon says so once you have it
ns.MOUNT_COST = 1200000
-- (15.10., Daniel: "paladin and warlock pay the same for the skill") their mount comes with the class quest
ns.MountCost = function()
  local _, cls = UnitClass("player")
  if cls == "PALADIN" or cls == "WARLOCK" then return 1000000 end
  return ns.MOUNT_COST
end
ns.RidingKnown = function()
  if Knows(33388) or (IsSpellKnown and IsSpellKnown(33388)) then return true end -- Apprentice Riding
  if GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() do
      local name = GetSkillLineInfo(i)
      if name == "Riding" or name == "Reiten" then return true end
    end
  end
  return false
end
ns.MountShort = function()
  local m, cost = Money(), ns.MountCost()
  if not m or m >= cost then return nil end
  return cost - m
end
ns.MountReminder = function()
  if not (db and db.mountLater) or ns._mountTold or ns.RidingKnown() or Level() < 40 then return end
  if ns.MountShort() then return end
  ns._mountTold = true
  print((L["|cff3fa9f5Level|rdon: you have the %s for riding now: visit the riding trainer."]):format(MoneyText(ns.MountCost())))
end


-- Too low by now: a quest far below the character.
local function Outgrown(s)
  if not (IsQuestStep(s) and s.lv and s.lv > 0 and s.lv + GRAY <= Level() and not InLog(s.q)) then return false end
  -- (15.10., review round 3) a class quest is needed however grey (Call of Earth: the totem)
  local a = API()
  local g = a and a.GetQuest and a.GetQuest(s.q)
  if g and g.classes and #g.classes > 0 then return false end
  return true
end

local function ChapterOf(i)
  for j = i, 1, -1 do if STEPS[j].k == "chapter" then return STEPS[j], j end end
end

-- First run on a character: begin at the first chapter that is not below its level.
local function StartIndex()
  local lv = Level()
  for i, s in ipairs(STEPS) do
    if s.k == "chapter" and (s.hi or 0) > lv then return i end
  end
  return 1
end

-- Has the character already done a quest step later in this chapter? Then the
-- service steps before it (flight point, inn, travel) are behind it too.
local function LaterProgress(i)
  for j = i + 1, #STEPS do
    local s = STEPS[j]
    if s.k == "chapter" then return false end
    if IsQuestStep(s) and (QuestDone(s.q) or InLog(s.q)) then return true end
  end
  return false
end

-- (0.1.6 playtest 1) a buy put in for the money that came later is taken out again once it is passed: the
-- saved step number stays that of the composed route (it is not there after a reload)
local function DropLater(i)
  if not (STEPS[i] and STEPS[i]._later) then return false end
  table.remove(STEPS, i)
  return true
end
local function Advance(initial)
  local guard = 0
  while cur <= #STEPS and guard < #STEPS do
    guard = guard + 1
    -- (13.10., Daniel: "when I go a step back it simply jumps forward again, without me wanting it") a step you went
    -- back to stays, even when it counts as done, until you go on yourself or something on it gets done now
    local held = ns._held
    if held and STEPS[cur] == held.s then
      if held.wasDone and StepDone(cur) then break end
      if StepDone(cur) then ns._held = nil end
    end
    local s = STEPS[cur]
    if s._later and (StepDone(cur) or CantAfford(s.i)) then
      DropLater(cur)
    elseif StepDone(cur) or Outgrown(s) or (initial and not IsQuestStep(s) and LaterProgress(cur)
        and not (s.k == "bind" and ns.BindOpenHere and ns.BindOpenHere(s))) then   -- (22.10., Daniel) the hearthstone is not skipped in its hub
      -- (15.10., review round 4) a trainer visit passed below its level: what it was to teach goes to the next visit
      if s.k == "train" and Level() < (s.lvl or 0) and not marks[s] and not (db and (db.trained or 0) >= (s.lvl or 0)) then
        marks[s] = true
        ns._replan = true
      end
      cur = cur + 1
    elseif (s.k == "do" or s.k == "turnin") and s.q and not InLog(s.q) and not QuestDone(s.q) and not s._retake
        and not (ns._acceptSkipped and ns._acceptSkipped[s.q]) and ns.RetakeBefore and ns.RetakeBefore(cur) then
      -- (0.1.7) abandoned (a failed timed quest): its accept again, here (the loop looks at it now)
    elseif s.k == "accept" and ns.TooLowFor and ns.TooLowFor(s.q) then
      -- (0.1.7, Daniel 11.10.: "Break Sharptusk!" at level 2, the quest needs 3) the accept moves to the
      -- route's next visit of that NPC (the loop looks at the step that is here now); no later visit: it
      -- is left out for now, its do and turn-in steps too (StepDone)
      -- (15.10., review round 1: Zip's recording, 13,275 moves in 96 s: Report to Gryan and Elmore's Task, both too
      -- high, kept moving behind each other) each quest moves once per level; the second time it waits like a quest
      -- with no later visit
      ns._movedLvl = ns._movedLvl or {}
      local movedOn = ns._movedLvl[s.q] ~= Level() and ns.MoveAcceptLater and ns.MoveAcceptLater(cur)
      if movedOn then ns._movedLvl[s.q] = Level() end
      -- (13.10.) the recorder notes it: "P q level m" moved behind the next stop there, "P q level s" left out
      if ns.RecEvent then pcall(ns.RecEvent, "P", s.q, select(2, ns.TooLowFor(s.q)) or 0, movedOn and "m" or "s") end
      if not movedOn then
        ns._acceptSkipped = ns._acceptSkipped or {}
        if not ns._acceptSkipped[s.q] then
          local _, min = ns.TooLowFor(s.q)
          print((L["|cff3fa9f5Level|rdon: \"%s\" is not offered yet (level %d). The route goes on without it."]):format(ns.QName(s) or "?", min or 0))
        end
        ns._acceptSkipped[s.q] = true
        cur = cur + 1
      end
    elseif s.k == "mount" and (Level() < 40 or ns.MountShort()) then
      -- (15.10., Daniel: "stay at 40") not enough gold for riding: the route goes on, a word in the chat once you have it
      if db and not db.mountLater and Level() >= 40 then
        db.mountLater = true
        print((L["|cff3fa9f5Level|rdon: riding costs %s, you still need %s. The route goes on on foot; Leveldon tells you when you have it."]):format(
          MoneyText(ns.MountCost()), MoneyText(ns.MountShort())))
      end
      if Level() < 40 and db then db.mountLater = true end   -- (review round 1) reached 40 later: the reminder then
      cur = cur + 1
    elseif s.k == "buy" and ns.BuyWaits(cur) then
      -- (0.1.6 playtest 1, Daniel 10.10.: no money for the pick) the buy waits: a hint says what it costs,
      -- it comes back at the next vendor on the way that sells it once the money is there (never a detour)
      if db then db.buyLater = db.buyLater or {} db.buyLater[s.i] = { n = s.n, sk = s.sk, sp = s.sp, ck = s.ck } end
      cur = cur + 1
    else
      break
    end
  end
  ns.SaveStep()
end

-- (0.1.5) what the bought thing is for
local BUY_HINT = {
  [393] = L["  (keep it in your bags: you need it to skin)"], [186] = L["  (keep it in your bags: you need it to mine)"],
  [356] = L["  (equip it to fish)"], [164] = L["  (you need it in your bags to forge)"], [202] = L["  (you need it in your bags to build)"],
  recipe = L["  (right-click it to learn it, then cook the fish you catch for Cooking)"],
  lure = L["  (use it on your fishing pole: more fishing skill for a while)"], -- (0.1.6) Shiny Bauble 6529
}
local LURES = { [6529] = true }


-- (24.10., reviewer c) a breadcrumb leads to the next zone only when its quest starts there: when every quest it leads
-- to starts in the zone of the step, the hint names the quest. Without data on where it leads: the old text.
function ns.BreadcrumbHint(s)
  local old = L["  (take it along: it leads to the next zone)"]
  local a = QuestdonAPI
  local targets = a and a.BreadcrumbTargets and a.BreadcrumbTargets(s.q)
  if type(targets) ~= "table" or not s.m then return old end
  local same, other
  for _, t in ipairs(targets) do
    local m = a.QuestStart and a.QuestStart(t)
    if m then
      if m == s.m then same = same or t else other = true end
    end
  end
  if other or not same then return old end
  local name = a.QuestTitle and a.QuestTitle(same)
  if type(name) ~= "string" or name == "" then return old end
  return (L["  (take it along: it leads to %s)"]):format(name)
end

local function StepText(s, upcoming, short)
  if not s then return L["Route finished"] end
  if s.k == "chapter" then return ns.ChName(s) end   -- (review round 4) going back onto the first header
  local kind = Kind(s, upcoming)
  local verb = VERB[kind] or s.k
  -- (28.10., Daniel: "Moonglade durch Teleport ersetzen") a spell instead of the hearthstone (sp): Teleport: Moonglade
  -- (28.10.) the English name when the client has no spell data yet (review C walk: "Cast ?")
  if s.k == "hearth" and s.sp then return (L["Cast %s"]):format(SpellName(s.sp) or ({ [18960] = "Teleport: Moonglade" })[s.sp] or "?") end
  if s.k == "accept" or s.k == "do" or s.k == "turnin" then
    local t = verb .. ": " .. (ns.QName(s) or (L["Quest "] .. s.q))
    if kind == "do" and InLog(s.q) then
      -- (0.1.3, Daniel 09.10.) the game's own objectives: "2/10 Kobold Vermin slain" instead of an estimate
      -- (22.10., Daniel: "keep the main goal simple") short: the station under it lists them with their counts
      local open = not short and OpenObjectives(s.q) or {}
      if #open > 0 then t = t .. ":  " .. table.concat(open, ", ") end
    elseif s.k == "do" and s.kills then t = t .. (L["  (about %d mobs)"]):format(s.kills) end
    if s.k == "accept" and s.item then t = t .. L["  (starts from an item: Questdon's quest item button)"] end
    if s.ins then t = t .. L["  (inside the dungeon)"] elseif s.grp then t = t .. L["  (group quest)"] end
    if s.k == "accept" and s.esc then t = t .. L["  (escort: starts at once)"] end
    if s.k == "accept" and s.bc then t = t .. ns.BreadcrumbHint(s) end
    -- (13.10.) a hint players gave for this quest (STEP_NOTES)
    local note = s.q and ns.STEP_NOTES[s.q] and ns.STEP_NOTES[s.q][s.k]
    if note then t = t .. note end
    -- (24.10.) a hint of the correction list (leveldon-build/korrekturen.json, kind note): the step's own text per language
    if s.nt then
      local nt = s.nt[ns.LOCALE] or s.nt.enUS
      if nt then t = t .. "  (" .. nt .. ")" end
    end
    -- (15.10., Daniel's mage Zip: "while doing the murlocs, kill Croaky: he drops a quest head item"; then "there
    -- must be something on the web for that") a mob here drops the start of a quest (CMaNGOS, ATT; the builder
    -- puts it on the kill step): kill it too, until you have that quest or did it
    if s.k == "do" and s.dq and s.dn and not QuestDone(s.dq) and not InLog(s.dq) then
      -- (15.10., Daniel: "Croaky was an elite too, mark it like the group quest")
      t = t .. (s.de and L["  (kill %s too, an elite: best with help; it drops the start of \"%s\")"]
        or L["  (kill %s too: it drops the start of \"%s\")"]):format(s.dn, ns.QName({ q = s.dq, n = s.di }) or s.di or "?")
    end
    if s.k == "turnin" and s._book then
      t = t .. T.bookChoose:format(ItemName(s._book.i, GATHER_BOOK[s._book.sk].n), ns.PName(s._book.sk))
    end
    return t
  elseif s.k == "grind" then
    return (L["Grind to level %d (about %d mobs)"]):format(s.to, s.kills or 0)
  elseif s.k == "die" then
    -- (23.10., player Dorandy) not there yet: walk to the place first (the compass shows it)
    if ns.DieWalkFirst(s) then
      return (L["Shortcut: walk to the marked place, then let yourself die there. You come back at the spirit healer by %s, where the route goes on (no resurrection sickness below level 10)"]):format(s.n or "?")
    end
    -- (Daniel 12.10.: "misleading: die here, or walk there first?") wherever you are now; the compass shows the
    -- spirit healer where you come back and the route goes on
    return (L["Shortcut: let yourself die where you are now. You come back at the spirit healer by %s, where the route goes on (no resurrection sickness below level 10)"]):format(s.n or "?")
  elseif s.k == "travel" then
    return verb .. " " .. ns.ChName(s) .. (s.via and ("  (" .. s.via .. ")") or "")
  elseif s.k == "fp" or s.k == "bind" then
    return verb .. ": " .. (s.n or "")
  elseif s.k == "train" then
    return (L["Learn your new skills at the trainer: %s (level %s)"]):format(s.n or "?", s.lvl or "?")
  elseif s.k == "dungeon" then
    local d = DUNGEON_BY_ID[s.id]
    local n = s.qs and #s.qs or (d and #d.quests or 0)
    local dn = ns.DgName(s.id, s.n) or "?"   -- (review round 3) the client's name of the dungeon
    if s.min then return (L["Run %s with a group (%d quests, about %d min)"]):format(dn, n, s.min) end
    return (L["Run %s with a group (%d quests)"]):format(dn, n)
  elseif s.k == "profs" then
    return verb .. L[" (up to 2 primary, all secondary; click here)"]
  elseif s.k == "mount" then
    local _, cls = UnitClass("player")
    if cls == "PALADIN" or cls == "WARLOCK" then
      return (L["Learn riding at the riding trainer (%s); your mount comes with your class quest"]):format(MoneyText(ns.MountCost()))
    end
    return (L["Learn riding at the riding trainer and buy your mount (%s)"]):format(MoneyText(ns.MountCost()))
  elseif s.k == "learn" then
    local txt = (L["Learn %s at the trainer"]):format(s.sk and ns.PName(s.sk) or s.n or "?")
    local short = ns.LearnShort and ns.LearnShort(s)
    local reserve = short and ns.TrainReserve()
    if short and reserve == 0 then   -- (15.10., review round 1) no "keep 0 copper for your class training"
      txt = txt .. (L["  (not enough money to learn it yet: %s missing; right-click: skip)"]):format(MoneyText(short))
    elseif short then
      txt = txt .. (L["  (better later: keep %s for your class training, %s still missing; right-click: skip)"]):format(
        MoneyText(reserve), MoneyText(short))
    end
    return txt
  elseif s.k == "farm" then
    if s.chain then return (L["Keep killing %s until the %s drops: it starts a quest chain worth the time"]):format(s.mob or "?", s.n or "?") end
    return T.farmBook:format(s.mob or "?", s.n or "?")
  elseif s.k == "sell" then
    local why = (s.why == "bags" and L["your bags are full"]) or (s.why == "hub" and L["grey items, repairs"])
      or (s.why == "ammo" and L["almost out of arrows or bullets"]) or L["you need the money for learning"]
    if s.why == "hub" and s.ammo and ns.IsHunter and ns.IsHunter() and ns.AmmoCount() < ns.HUB.ammo then why = why .. L[", buy ammunition"] end -- (12.10. error 710: both are defined further down)
    return (L["%s at %s  (%s)"]):format(verb, s.n or "?", why)
  elseif s.k == "use" then
    return T.bookUse:format(s.n or "?", ns.PName(s.sk)) .. T.bookOther
  elseif s.k == "buy" and s.q then
    -- (13.10.) "Buy 3 Nightcrawlers from Catherine Leland  (for Fishin' Time)"
    local item = ItemName(s.i, s.n) or "?"
    if (s.c or 1) > 1 then item = (s.c or 1) .. " " .. item end
    return (L["Buy %s from %s%s"]):format(item, s.v or "?", (L["  (for %s)"]):format(ns.QName(s) or "?"))
  elseif s.k == "buy" then
    -- (11.10., Daniel: "bought the fishing pole, should equip it, but I have not learned Fishing"; "bought the
    -- recipe, cannot learn it, not sent to Cooking yet") before the profession is learned the hint says so
    local need = (s.ck and SkillRank(s.ck) == nil and s.ck) or (s.sk and SkillRank(s.sk) == nil and s.sk) or nil
    if need then
      return (L["Buy %s from %s%s"]):format(s.n or "?", s.v or "?", (L["  (keep it: you learn %s on the way)"]):format(need and ns.PName(need) or L["the profession"]))
    end
    return (L["Buy %s from %s%s"]):format(s.n or "?", s.v or "?", (s.sp and BUY_HINT.recipe) or (LURES[s.i] and BUY_HINT.lure) or BUY_HINT[s.sk] or "")
  elseif s.k == "skillup" then
    local r = SkillRank(s.sk)
    local how = s.mats or ""
    -- (0.1.6, Daniel 10.10.) Fishing and Cooking together: keep the first fish, cook it right after
    if s._fc then
      local fish, recipe = FirstFish()
      if s.sk == 356 then how = T.fishCook:format(FISH_CATCH, fish) else how = T.cookFish:format(FISH_COOK, fish, recipe) end
    end
    return (L["Raise %s to %d%s: %s"]):format(s.sk and ns.PName(s.sk) or s.n or "?", s.need or 20, r and (L[" (now "] .. r .. ")") or "", how)
  end
  return verb
end

-- (0.1.4, Daniel 09.10.: the arrow went back to the kobold track he had just followed) places where the
-- quest's progress went up are used for a while (tracks, crates, mobs respawn after minutes): the arrow
-- takes the next place instead
local usedAt, progressOf = {}, {}
local USED_FOR, USED_RANGE = 300, 35
local function PointKey(p) return p.mapID .. ":" .. math.floor(p.x * 1000) .. ":" .. math.floor(p.y * 1000) end
local function Progress(q)
  local ok, objs = pcall(C_QuestLog and C_QuestLog.GetQuestObjectives or function() end, q)
  local n = 0
  for _, o in ipairs(ok and type(objs) == "table" and objs or {}) do n = n + (tonumber(o.numFulfilled) or 0) end
  return n
end

-- (0.1.3, Daniel 09.10.) the nearest place of the objectives, not the first one in the data
local function NearestObjective(q)
  local a = API()
  if not (a and a.ObjectivePoints and a.DistanceTo) then return nil end
  local used, now = usedAt[q] or {}, (GetTime and GetTime() or 0)
  local best, bd, any, anyd
  local pts = a.ObjectivePoints(q) or {}
  -- (11.10., Daniel: Rite of Vision, "straight to the Well Stones, the Ambercorn on the way") a quest whose
  -- one objective leads (Fit.lua ns.LEAD_OBJECTIVE): its places first while it is open
  local lead = ns.LEAD_OBJECTIVE and ns.LEAD_OBJECTIVE[q]
  if lead then
    local objs = C_QuestLog and C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(q)
    local o = type(objs) == "table" and objs[lead]
    if not (type(o) == "table" and o.finished) then
      local only = {}
      for _, p in ipairs(pts) do if p.index == lead then only[#only + 1] = p end end
      if #only > 0 then pts = only end
    end
  end
  for _, p in ipairs(pts) do
    local d = a.DistanceTo(p.mapID, p.x, p.y)
    if type(d) == "number" then
      if not anyd or d < anyd then any, anyd = p, d end
      local t = next(used) ~= nil and used[PointKey(p)] or nil -- (23.10.) no key string per place when none was used
      if not (t and now - t < USED_FOR) and (not bd or d < bd) then best, bd = p, d end
    end
  end
  if not best then return any, anyd end -- all used: the nearest anyway
  return best, bd
end

-- called every 2 s on a do step: progress went up, so the places around you are done for now
local function MarkUsed(q)
  local a = API()
  if not (q and a and a.ObjectivePoints and a.DistanceTo) then return end
  local n = Progress(q)
  local before = progressOf[q]
  progressOf[q] = n
  if not before or n <= before then return end
  usedAt[q] = usedAt[q] or {}
  local now = GetTime and GetTime() or 0
  for _, p in ipairs(a.ObjectivePoints(q) or {}) do
    local d = a.DistanceTo(p.mapID, p.x, p.y)
    if type(d) == "number" and d < USED_RANGE then usedAt[q][PointKey(p)] = now end
  end
end
local IN_AREA = 60

local function Arrow()
  local a = API()
  if not (a and a.SetArrowTarget) then return end
  -- (16.10., Questdon review 3) the window closed: no step for Questdon's arrow (it followed the step anyway)
  if panel and panel.IsShown and not panel:IsShown() then a.SetArrowTarget(nil) return end
  local s = STEPS[cur]
  if not s then a.SetArrowTarget(nil) return end
  -- (11.10., Daniel: "the step's quest selected in Blizzard's tracker too, so the map marks its ? or its area")
  -- once per quest of a step, so a quest you pick yourself afterwards stays picked
  if s.q and (s.k == "do" or s.k == "turnin") and InLog(s.q) and ns._superQ ~= s.q
      and C_SuperTrack and type(C_SuperTrack.SetSuperTrackedQuestID) == "function" then
    ns._superQ = s.q
    pcall(C_SuperTrack.SetSuperTrackedQuestID, s.q)
  end
  local m, x, y
  -- (12.10.) a death on purpose: the compass shows the spirit healer where you come back, not a place to walk to
  if s.k == "die" and s.gm and s.gx and not ns.DieWalkFirst(s) then
    local t = { mapID = s.gm, x = s.gx / 100, y = s.gy / 100, label = StepText(s) }
    ns._arrowT = t
    a.SetArrowTarget(t)
    return
  end
  if Kind(s) == "do" and InLog(s.q) and a.ObjectivePoints then
    local p, d = NearestObjective(s.q)
    -- (0.1.4, Daniel 09.10.) in the middle of the mobs: the arrow stays on the nearest of them. Releasing it
    -- (nil) handed it back to Questdon, which then pointed at a finished quest's turn-in far away
    if p then m, x, y = p.mapID, p.x, p.y end
  elseif s.k == "turnin" and InLog(s.q) and a.TurnInPoint then
    local tm, tx, ty = a.TurnInPoint(s.q)
    if tm then m, x, y = tm, tx, ty end
  end
  if not m then
    local pm, px, py = Place(cur)
    if pm then m, x, y = pm, px / 100, py / 100 end
  end
  local t = m and { mapID = m, x = x, y = y, label = StepText(s) } or nil
  local old = ns._arrowT
  -- (0.1.7, Daniel 11.10.: "the arrow confuses when you are in the area killing the mobs") a do step brings
  -- its objective places: in their area Questdon shows "In the objective area" instead of the needle
  if t and Kind(s) == "do" and InLog(s.q) and a.ObjectivePoints then
    local src = a.ObjectivePoints(s.q) or {}
    if #src > 0 then
      -- (Daniel 11.10.: standing still it flipped between the needle and "In the objective area") the same
      -- quest's area target stays as it is: Questdon picks the nearest spot in it, a new table every 2 s
      -- with Leveldon's own spot made it jump. (23.10., /lvd mem: the tickers 62 KB a second) asked before the
      -- points are copied: every 2 s a new table for each of the quest's places went straight to the bin
      if old and old.area and old.questID == s.q and old.label == t.label and #old.points == #src then return end
      local pts = {}
      for _, p in ipairs(src) do pts[#pts + 1] = { mapID = p.mapID, x = p.x, y = p.y } end
      t.area, t.questID, t.points = true, s.q, pts
    end
  end
  -- (15.10.) the same place and text again (the turn-in asked every 2 s): nothing to change
  if t and old and not t.area and not old.area and old.mapID == t.mapID and old.x == t.x and old.y == t.y and old.label == t.label then return end
  ns._arrowT = t
  a.SetArrowTarget(t)
end
ns.LeveldonArrow = function() Arrow() end -- (tests)
-- (11.10., Daniel: "a click on the quest in Leveldon's window opens the quest log") a quest in your log: the
-- map's quest log at its details (else the classic quest log at it); not in the log yet: the map at its place
ns.OpenQuest = function(s)
  if not s then return end
  local q = s.q
  -- (0.1.8, Daniel 12.10.: "a way to read the whole quest") Shift-click: Questdon's window with the whole quest
  local a = API()
  if q and IsShiftKeyDown and IsShiftKeyDown() and a and a.ShowQuestText and a.ShowQuestText(q) then return end
  if q and InLog(q) then
    if type(QuestMapFrame_OpenToQuestDetails) == "function" and pcall(QuestMapFrame_OpenToQuestDetails, q) then return end
    local idx = C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(q)
    local qlf = rawget(_G, "QuestLogFrame")
    if idx and qlf and type(QuestLog_SetSelection) == "function" then
      if not qlf:IsShown() and type(ShowUIPanel) == "function" then pcall(ShowUIPanel, qlf) end
      pcall(QuestLog_SetSelection, idx)
      if type(QuestLog_Update) == "function" then pcall(QuestLog_Update) end
      return
    end
  end
  local m = s.m
  if not m then return end
  if type(OpenWorldMap) == "function" then pcall(OpenWorldMap, m) return end
  local wm = rawget(_G, "WorldMapFrame")
  if wm and type(ShowUIPanel) == "function" then
    pcall(ShowUIPanel, wm)
    if type(wm.SetMapID) == "function" then pcall(wm.SetMapID, wm, m) end
  end
end

---------------------------------------------------------------------------
-- (0.1.6, Daniel 10.10.) Stops on the map: a service stop with a place (learn at
-- a trainer, buy at a vendor, the class trainer, a flight point, a new home inn)
-- gets Blizzard's own map pin (the user waypoint). It goes again when the step is
-- done or skipped, the route moves on, you talk to an NPC there (within 20 yd),
-- or you ignored it (came within 40 yd, then went more than 80 yd away).
-- The player's own pin is never replaced or removed: Leveldon sets one only
-- while there is none and clears only the one it set (same place). Option
-- db.markStops (off since 0.1.8: Daniel wants the target markers over the NPC instead, Marks.lua), /lvd marks.
---------------------------------------------------------------------------
local MarkTick, MarkInteract
do
local MARK_KIND = { learn = true, buy = true, train = true, fp = true, bind = true }
local MARK_NEAR, MARK_LEFT, MARK_TALK = 40, 80, 20
local mark -- { s = step, m, x, y (0..1), near } while our pin is on the map
local markOver = setmetatable({}, { __mode = "k" }) -- steps whose pin is over (reached, ignored, taken away)

-- The user waypoint now: "none", "pin" (with its place), "unknown" (unreadable) or "noapi"
local function UserPin()
  if not C_Map then return "noapi" end
  local readable = false
  if C_Map.HasUserWaypoint then
    readable = true
    local h = Val(C_Map.HasUserWaypoint)
    if h == false then return "none" end
  end
  if C_Map.GetUserWaypoint then
    local ok, p = pcall(C_Map.GetUserWaypoint)
    if not ok then return "unknown" end
    if p == nil then return "none" end
    if type(p) ~= "table" or not Usable(p.uiMapID) then return "unknown" end
    local pos = p.position
    local x, y
    if type(pos) == "table" then x, y = pos.x, pos.y end
    if not (Usable(x) and Usable(y)) and type(pos) == "table" and type(pos.GetXY) == "function" then
      local okP, px, py = pcall(pos.GetXY, pos)
      if okP then x, y = px, py end
    end
    local m = p.uiMapID
    if type(m) == "number" and Usable(x) and Usable(y) and type(x) == "number" and type(y) == "number" then return "pin", m, x, y end
    return "unknown"
  end
  return readable and "unknown" or "noapi"
end
local function SamePlace(m, x, y, pm, px, py)
  return m == pm and math.abs(x - px) < 0.002 and math.abs(y - py) < 0.002
end
-- Is the pin on the map still ours? Without a way to read it: yes; unreadable (secret): no (hands off)
local function PinIsOurs(m, x, y)
  local st, pm, px, py = UserPin()
  if st == "noapi" then return true end
  return st == "pin" and SamePlace(m, x, y, pm, px, py)
end
local function RemovePin(m, x, y)
  if C_Map and C_Map.ClearUserWaypoint and PinIsOurs(m, x, y) then pcall(C_Map.ClearUserWaypoint) end
  if db then db.markPin = nil end
end
-- over: the stop's pin is done with (reached, ignored); it does not come back for this step
local function ClearMark(over)
  if not mark then return end
  RemovePin(mark.m, mark.x, mark.y)
  if over then markOver[mark.s] = true end
  mark = nil
end

function MarkTick()
  local s = STEPS[cur]
  local want = db ~= nil and db.markStops == true and s ~= nil and MARK_KIND[s.k] and s.m and s.x and s.y
    and not markOver[s] and not StepDone(cur)
  if mark and (mark.s ~= s or not want) then ClearMark(false) end
  local a = API()
  if mark then
    -- the player took our pin away or put his own there: ours is over, his stays
    local st, pm, px, py = UserPin()
    if st == "none" or (st == "pin" and not SamePlace(mark.m, mark.x, mark.y, pm, px, py)) then
      markOver[mark.s] = true
      mark = nil
      if db then db.markPin = nil end
      return
    end
    local ok, d = pcall(a and a.DistanceTo or error, mark.m, mark.x, mark.y)
    if ok and type(d) == "number" and Usable(d) then
      if d < MARK_NEAR then mark.near = true
      elseif mark.near and d > MARK_LEFT then ClearMark(true) end
    end
    return
  end
  -- a pin of ours from the last session (reload, logout): take it away first
  if db and db.markPin then
    local p = db.markPin
    local st, pm, px, py = UserPin()
    if st == "pin" and SamePlace(p[1], p[2], p[3], pm, px, py) then pcall(C_Map.ClearUserWaypoint) end
    if st ~= "unknown" then db.markPin = nil end
  end
  if not want then return end
  if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then return end
  local st = UserPin()
  if st == "pin" or st == "unknown" then return end -- the player's own pin (or one we cannot read): leave it
  if C_Map.CanSetUserWaypointOnMap and Val(C_Map.CanSetUserWaypointOnMap, s.m) ~= true then markOver[s] = true return end
  local x, y = s.x / 100, s.y / 100
  local ok = pcall(function() C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(s.m, x, y)) end)
  if not ok then markOver[s] = true return end
  mark = { s = s, m = s.m, x = x, y = y }
  db.markPin = { s.m, x, y }
  if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true) end
end

-- talking to the trainer, vendor, flight master or innkeeper at the stop: the pin has done its job
function MarkInteract()
  if not mark then return end
  local a = API()
  local ok, d = pcall(a and a.DistanceTo or error, mark.m, mark.x, mark.y)
  if ok and type(d) == "number" and Usable(d) and d < MARK_TALK then ClearMark(true) end
end
ns.MarkTick = function() return MarkTick() end -- (tests)
ns.MarkState = function() return mark and { s = mark.s, m = mark.m, x = mark.x, y = mark.y, near = mark.near } or nil end -- (tests)
end

-- The steps for this character: the route without the professions you did not
-- pick, with the start area's Camping 101 quests of the ones you picked.
-- (0.1.2) the steps of a planned dungeon: its quests picked up (nearest first from p), the run, the turn-ins
local function DungeonSteps(d, pm, px, py)
  local left, out = {}, {}
  for _, q in ipairs(d.quests) do left[#left + 1] = q end
  local m, x, y = pm, px or 50, py or 50
  while #left > 0 do
    local best, bi
    for i, q in ipairs(left) do
      local dist = (q.a.m == m) and ((q.a.x - x) ^ 2 + (q.a.y - y) ^ 2) or 1e9
      if not best or dist < best then best, bi = dist, i end
    end
    local q = table.remove(left, bi)
    out[#out + 1] = { k = "accept", q = q.q, n = q.n, lv = q.lv, m = q.a.m, x = q.a.x, y = q.a.y, dg = d.id }
    m, x, y = q.a.m, q.a.x, q.a.y
  end
  out[#out + 1] = { k = "dungeon", id = d.id, n = d.n, m = d.e and d.e.m, x = d.e and d.e.x, y = d.e and d.e.y }
  for _, q in ipairs(d.quests) do
    out[#out + 1] = { k = "turnin", q = q.q, n = q.n, lv = q.lv, m = q.t.m, x = q.t.x, y = q.t.y, dg = d.id }
  end
  return out
end

-- (0.1.5, Daniel 09.10.: "lead me to the vendor of the skinning knife, the fishing pole ...") after a
-- learn step: buy the profession's tool at the nearest vendor; with Fishing also the first fishing
-- recipe, when Cooking is learned too (ck)
local function BuySteps(src, sk, cooking)
  local out = {}
  -- (15.10., review round 3) the same object on every Compose (a buy skipped by hand came back after the trainer)
  ns._buyObj = ns._buyObj or setmetatable({}, { __mode = "k" })
  for _, b in ipairs(src and src.b or {}) do
    if not b.ck or cooking then
      -- the n-th use of this item entry in this Compose gets the n-th object of the last one
      local list = ns._buyObj[b] or {}
      ns._buyObj[b] = list
      if list.id ~= ns._composeId then list.id, list.n = ns._composeId, 0 end
      list.n = list.n + 1
      local o = list[list.n]
      if not o or o.sk ~= sk then
        o = { k = "buy", i = b.i, n = b.n, v = b.v, sp = b.sp, ck = b.ck, sk = sk, m = b.m, x = b.x, y = b.y }
        list[list.n] = o
      end
      out[#out + 1] = o
    end
  end
  return out
end

local MERGE_NEAR = 6 -- map percent (about 200 yards in Elwynn Forest)
local function IndexIn(list, obj) for i, s in ipairs(list) do if s == obj then return i end end end
-- (15.10., review round 2) after Compose: the step you were on, or (a vendor or hub stop put in is not in the new
-- list) the first step after it that still is; never past steps not done
ns.RefindCur = function(here, old, at)
  -- (15.10., review round 3, H1: 44 of 56 walks jumped 20 to 150 open steps at a trainer) the first place in the new
  -- list of the steps from here on: a step moved here (ClassNow pulled a class quest from further on) goes back to
  -- its own place, the steps after it count; a step Compose builds anew is found by what it is
  local function Key(t)
    return table.concat({ t.k or "", t.q or "", t.i or "", t.sk or "", t.n or "", t._i or "", t._early and 1 or "", t.lvl or "", t.id or "" }, "|")
  end
  local pos, byKey = {}, {}
  for j, t in ipairs(STEPS) do
    pos[t] = j
    local k = Key(t)
    byKey[k] = byKey[k] or {}
    table.insert(byKey[k], j)
  end
  local function Find(t)
    if pos[t] then return pos[t] end
    if t._retake or t._later then return nil end   -- (review round 4) a copy: never the original by its key
    local best
    for _, j in ipairs(byKey[Key(t)] or {}) do if not best or math.abs(j - at) < math.abs(best - at) then best = j end end
    return best
  end
  -- (review round 4) the step you are on, where it is now, unless it was moved here (pulled, retaken, moved for its
  -- level): /lvd solo at an inn kept sending you back to a trainer visit Compose put earlier
  local cid = ns._composeId or 0
  local best
  if here and pos[here] and not here._retake and here._pulled ~= cid - 1 and here._nearPulled ~= cid - 1 and here._movedLater ~= cid - 1 then
    best = pos[here]
  else
    for k = at, math.min(#old, at + 60) do
      local t = old[k]
      -- (not a step moved further on for its level: its own place is behind)
      local j = t and t._movedLater ~= cid - 1 and Find(t)
      if j and (not best or j < best) then best = j end
    end
  end
  if not best and here then best = Find(here) end
  best = best or math.min(at, #STEPS + 1)
  -- (15.10., review round 3) a stop put in while you play (a hub trainer or vendor stop) that you are on stays the
  -- step: Compose does not build it, and its check does not ask again so soon
  -- (review round 4) and the ones just ahead of it (a vendor and a hub trainer stop together)
  local keep, hereKept = {}, false
  for k = at, math.min(#old, at + 8) do
    local t = old[k]
    if t and (t._hub or t.k == "sell") and not pos[t] and not marks[t] then
      keep[#keep + 1] = t
      if t == here then hereKept = true end
    end
  end
  -- the step you were on in front; stops that were ahead of it behind it (review round 4: /lvd solo at an inn showed a
  -- hub trainer stop that came after it)
  local others = {}
  for _, t in ipairs(keep) do if t ~= here then others[#others + 1] = t end end
  if hereKept then table.insert(STEPS, best, here) end
  for n, t in ipairs(others) do table.insert(STEPS, best + n, t) end
  return best
end

---------------------------------------------------------------------------
-- (0.1.6 playtest 1, Daniel 10.10.) Yards between two places of the route, from
-- the client's own map positions (C_Map.GetWorldPosFromMapPos, three corners per
-- map, cached). Without them: map percent times 30 (roughly Elwynn Forest).
--   NPC_NEAR   a stop at an NPC counts as "at" another NPC (same camp, same building)
--   HUB_R      adjacent stops at NPCs within this of the first one form one hub
--   DO_NEAR    a quest's mob area counts as the same area as another's
--   PASS_NEAR  the route passes a place on its way
--   LEARN_*    a trainer more than LEARN_DETOUR out of the way waits for a step within LEARN_NEAR
---------------------------------------------------------------------------
local NEAR = { npc = 60, hub = 80, mob = 120, pass = 150, learnDetour = 250, learn = 150, sameNpc = 10, percent = 30, door = 60 }
local NPC_KIND = { accept = true, turnin = true, train = true, learn = true, buy = true, bind = true, fp = true, hearth = true, sell = true }
local MOB_KIND = { ["do"] = true, farm = true, grind = true }
local Yards, Within, HubEnd, Sellers, AtSeller, MergeBuys, LearnDetours, HubOrder, FishAndCook, RecordIndoor
do
-- (0.1.6 playtest 1, Daniel 10.10.: Northshire, "into the abbey, out, around, in again") which NPC places are
-- inside a building: Northshire Abbey from Daniel's playtest (Marshal McBride and the warrior trainer inside,
-- Eagan Peltskinner and Deputy Willem outside) and Book Inventory's text (Brother Paxton's assistant "in the
-- library"); more are learned in the game (IsIndoors when you talk to the NPC of a step, LeveldonDB.indoors,
-- in /lvd export for the route builder). Going in or out costs NEAR.door yards on top in a hub's order.
local INDOOR_SEED = {
  { m = 1429, x = 48.8, y = 41.4, inside = true }, { m = 1429, x = 50.2, y = 42.2, inside = true },
  { m = 1429, x = 49.4, y = 40.4, inside = true },
  { m = 1429, x = 48.8, y = 40.2, inside = false }, { m = 1429, x = 48.2, y = 42.8, inside = false },
}
local function PlaceKey(t) return ("%d:%.1f:%.1f"):format(t.m, t.x, t.y) end
local rects = {}
local function MapRect(m)
  local r = rects[m]
  if r ~= nil then return r or nil end
  r = false
  local f = C_Map and C_Map.GetWorldPosFromMapPos
  if f and CreateVector2D then
    local pts = {}
    for i, v in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 } }) do
      local ok, c, p = pcall(f, m, CreateVector2D(v[1], v[2]))
      local x, y
      if ok and type(p) == "table" and type(p.GetXY) == "function" then
        local okP, px, py = pcall(p.GetXY, p)
        if okP then x, y = px, py end
      end
      if not (ok and c ~= nil and Usable(c) and type(x) == "number" and type(y) == "number" and Usable(x) and Usable(y)) then pts = nil break end
      pts[i] = { c, x, y }
    end
    if pts and pts[1][1] == pts[2][1] and pts[1][1] == pts[3][1] then
      r = { c = pts[1][1], x0 = pts[1][2], y0 = pts[1][3], ax = pts[2][2] - pts[1][2], ay = pts[2][3] - pts[1][3],
        bx = pts[3][2] - pts[1][2], by = pts[3][3] - pts[1][3] }
    end
  end
  rects[m] = r
  return r or nil
end
-- yards between two places { m, x, y } (x, y 0-100); nil when they cannot be compared
function Yards(a, b)
  if not (a and b and a.m and b.m and a.x and a.y and b.x and b.y) then return nil end
  local ra, rb = MapRect(a.m), MapRect(b.m)
  if a.m == b.m and not ra then return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) * NEAR.percent end
  if not (ra and rb) or ra.c ~= rb.c then return nil end
  local ax, ay = ra.x0 + ra.ax * a.x / 100 + ra.bx * a.y / 100, ra.y0 + ra.ay * a.x / 100 + ra.by * a.y / 100
  local bx, by = rb.x0 + rb.ax * b.x / 100 + rb.bx * b.y / 100, rb.y0 + rb.ay * b.x / 100 + rb.by * b.y / 100
  return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end
-- within r yards on the same map
function Within(a, b, r)
  if not (a and b and a.m == b.m) then return false end
  local d = Yards(a, b)
  return d ~= nil and d <= r
end
-- inside a building (true), outside (false), unknown (nil)
local function Indoor(t)
  if not (t and t.m and t.x) then return nil end
  local learned = LeveldonDB and LeveldonDB.indoors and LeveldonDB.indoors[PlaceKey(t)]
  if learned ~= nil then return learned end
  local best, bd
  for _, p in ipairs(INDOOR_SEED) do
    local d = p.m == t.m and Yards(t, p)
    if d and d <= NEAR.sameNpc and (not bd or d < bd) then best, bd = p, d end
  end
  return best and best.inside
end
ns.Indoor = Indoor -- (tests)
-- the last stop of the hub around out[j]: the adjacent stops at NPCs close to it
function HubEnd(out, j)
  local k = j
  while out[k + 1] and NPC_KIND[out[k + 1].k] and Within(out[k + 1], out[j], NEAR.hub) do k = k + 1 end
  return k
end

-- (playtest 1) the vendors of the route that sell an item, with their places (the buy data's own vendor first)
local sellerCache = {}
function Sellers(i, first)
  if sellerCache._route ~= ROUTE then sellerCache = { _route = ROUTE } end
  local list = sellerCache[i]
  if list and not first then return list end
  list = {}
  local seen = {}
  local function Add(n, m, x, y)
    if n and m and x and y and not seen[n .. m] then seen[n .. m] = true list[#list + 1] = { n = n, m = m, x = x, y = y } end
  end
  if first then Add(first.v, first.m, first.x, first.y) end
  local function Scan(src) for _, e in ipairs(src and src.b or {}) do if e.i == i or (SELLS[e.v] and SELLS[e.v][i]) then Add(e.v, e.m, e.x, e.y) end end end
  for _, s in ipairs(ROUTE.steps) do if s.b then Scan(s) end end
  for _, e in ipairs(ROUTE.early or {}) do Scan(e) end
  for _, o in ipairs(ROUTE.profOptions or {}) do Scan(o) end
  for _, v in ipairs(ROUTE.vendors or {}) do if SELLS[v.n] and SELLS[v.n][i] then Add(v.n, v.m, v.x, v.y) end end
  if not first then sellerCache[i] = list end
  return list
end
-- a stop at an NPC close to one of these vendors: that vendor
function AtSeller(t, sellers)
  if not (t and NPC_KIND[t.k] and t.m and t.x) then return nil end
  for _, v in ipairs(sellers) do if Within(t, v, NEAR.npc) then return v end end
  return nil
end

-- (0.1.6, Daniel 10.10.: "the route sends you to raise Fishing anyway") with Fishing and Cooking: the
-- Fishing skill-up keeps the faction's first fish, the Cooking skill-up comes right after it and cooks
-- them (a Cooking turn-in that came before goes along behind it)
function FishAndCook(out, chosen)
  local fi, ci, li
  for j, t in ipairs(out) do
    if t.k == "skillup" and t.sk == 356 and not fi then fi = j end
    if t.k == "skillup" and t.sk == 185 and not ci then ci = j end
    if t.k == "learn" and t.sk == 185 and not li then li = j end
  end
  if not fi then return end
  local wanted = ci ~= nil or (chosen and chosen[185]) or (not (chosen and not chosen[185]) and SkillRank(185) ~= nil)
  if not wanted then return end
  local fs = out[fi]
  fs._fc = true
  -- cooked where the fish were caught (a Basic Campfire, or the town's fire on the way): the step takes
  -- the Fishing place, no trip back to the cooking trainer (its turn-in stays where it was)
  local cs = { k = "skillup", sk = 185, n = SKILL_EN[185], need = 20 }
  if ci then
    for k, v in pairs(table.remove(out, ci)) do cs[k] = v end
    if ci < fi then fi = fi - 1 end
    if li and ci < li then li = li - 1 end
  end
  cs.m, cs.x, cs.y, cs._fc = fs.m, fs.x, fs.y, true
  -- never before Cooking is learned
  local at = math.max(fi, li or 0) + 1
  table.insert(out, at, cs)
  local moved, j = {}, 1
  while j < at do
    local t = out[j]
    if t.k == "turnin" and t.sk == 185 then table.remove(out, j) at = at - 1 moved[#moved + 1] = t else j = j + 1 end
  end
  for n, t in ipairs(moved) do table.insert(out, at + n, t) end
  -- (0.1.6 playtest 1, Dun Morogh: cooked at the lake, then to Kharanos and back to the lake for the Fishing
  -- turn-in) the Fishing quest's turn-in at the fishing place comes right after the cooking there
  for j = at + 1, #out do
    local t = out[j]
    if t.k == "turnin" and t.sk == 356 then
      if j > at + 1 and Within(t, fs, NEAR.npc) then table.remove(out, j) table.insert(out, at + 1, t) end
      break
    end
  end
end

-- (0.1.6, Daniel 10.10.: "no extra trip to the vendor when the route passes him anyway") each buy goes
-- to the first stop after the profession choice where the route is at an NPC within NPC_NEAR of a vendor
-- that sells it (its own vendor or another one of the route that has it), in its learn step's chapter or
-- the next one (not an earlier one), and before the steps that need it (the profession's skill-up and
-- quest; the fishing recipe: before Cooking's skill-up). Buying before learning is fine. No such stop: it
-- stays right after its learn step.
-- (playtest 1, Daniel 10.10.: "Buy Mining Pick" pulled him out of the kobolds) a mob area is no stop at a
-- vendor: only accepts, turn-ins, trainers, vendors, inns and flight masters count. A buy without its learn
-- step (the book teaches the profession) is placed the same way from where it was.
function MergeBuys(out)
  local profsAt
  for j, t in ipairs(out) do if t.k == "profs" then profsAt = j break end end
  if not profsAt then return end
  local buys, placed = {}, {}
  for _, t in ipairs(out) do if t.k == "buy" and not t.q and t.m and t.x and t.y then buys[#buys + 1] = t end end
  for _, b in ipairs(buys) do
    local from = IndexIn(out, b)
    table.remove(out, from)
    local learnAt
    for j = math.min(from - 1, #out), 1, -1 do if out[j].k == "learn" and out[j].sk == b.sk then learnAt = j break end end
    local limit = #out + 1
    for j, t in ipairs(out) do
      if (not b.ck and t.sk == b.sk and (t.k == "skillup" or t.k == "do" or t.k == "turnin"))
        or (b.ck and t.k == "skillup" and t.sk == b.ck) then limit = j break end
    end
    local target, seller
    if from > profsAt then
      local sellers = Sellers(b.i, b)
      local baseCh, ch = 0, 0
      for j = 1, math.min(learnAt or (from - 1), #out) do if out[j].k == "chapter" then baseCh = baseCh + 1 end end
      for j = 1, profsAt do if out[j].k == "chapter" then ch = ch + 1 end end
      for j = profsAt + 1, limit - 1 do
        local t = out[j]
        if t.k == "chapter" then ch = ch + 1 if ch > baseCh + 1 then break end end
        if ch >= baseCh and t.k ~= "buy" then
          seller = AtSeller(t, sellers)
          if seller then target = j + 1 break end
        end
      end
      -- after the buys already put at the same stop, in their order
      while target and out[target] and placed[out[target]] do target = target + 1 end
    end
    if seller and seller.n ~= b.v then b.v, b.m, b.x, b.y = seller.n, seller.m, seller.x, seller.y end
    table.insert(out, target or from, b)
    placed[b] = true
  end
  -- the recipe before the cooking (also when it could not move)
  local cookAt
  for j, t in ipairs(out) do if t.k == "skillup" and t.sk == 185 then cookAt = j break end end
  if cookAt then
    local late, j = {}, cookAt + 1
    while j <= #out do
      if out[j].k == "buy" and out[j].ck == 185 then late[#late + 1] = table.remove(out, j) else j = j + 1 end
    end
    for n, t in ipairs(late) do table.insert(out, cookAt + n - 1, t) end
  end
end

-- (0.1.6 playtest 1, Daniel 10.10.: Kharanos, "learn Fishing 700 yards away, then back for Camping 101")
-- a trainer far off the way (more than LEARN_DETOUR beyond the direct way between its neighbours) waits
-- for the first later step of the chapter within LEARN_NEAR of it, before the steps that need the
-- profession (with its buys). With turnins = true the same for a profession's turn-in (Camping 101): it goes
-- with the next hub at its NPC in the chapter (Dun Morogh: Cooking's turn-in waited for the next Kharanos visit). The profession's Camping 101 accept, now before the learn, moves to the next
-- visit of its quest giver after the learn; without one before the turn-in it stays (ATT lists no skill
-- requirement for these quests, only the level: the quest waits in the log until the skill-up).
function LearnDetours(out, turnins)
  local seen, i = {}, 1
  while i <= #out do
    local L = out[i]
    local moved = false
    local mine = (not turnins and L.k == "learn") or (turnins and L.k == "turnin" and L.sk ~= nil)
    if mine and L.m and L.x and not seen[L] then
      seen[L] = true
      local nb = 0
      while not turnins and out[i + nb + 1] and out[i + nb + 1].k == "buy" and out[i + nb + 1].sk == L.sk do nb = nb + 1 end
      local prev, nxt
      -- the neighbours where you walk (buys are not placed yet: they move to their vendors later)
      for j = i - 1, math.max(1, i - 8), -1 do if out[j].k == "chapter" then break end if out[j].m and out[j].x and out[j].k ~= "buy" and out[j].k ~= "profs" then prev = out[j] break end end
      for j = i + nb + 1, math.min(#out, i + nb + 8) do if out[j].k == "chapter" then break end if out[j].m and out[j].x and out[j].k ~= "buy" and out[j].k ~= "profs" then nxt = out[j] break end end
      local d1, d2, d0 = Yards(prev, L), Yards(L, nxt), Yards(prev, nxt)
      -- (11.10., Daniel: "Alchemy only in Thunder Bluff? a very long way, rather wait with the training") a
      -- trainer on another map than both neighbours (a capital) waits for the route's next visit there, also in
      -- a later chapter, before anything needs the profession
      local away = not turnins and prev and nxt and L.m ~= prev.m and L.m ~= nxt.m
      if away or (prev and nxt and prev.m == L.m and nxt.m == L.m and d1 and d2 and d0 and d1 + d2 - d0 > NEAR.learnDetour) then
        local target, before
        local deferred = {}
        local j = i + nb + 1
        while out[j] and (away or out[j].k ~= "chapter") do
          local t = out[j]
          if turnins then
            -- a profession's turn-in: with the route's next hub at its NPC (behind that hub)
            if NPC_KIND[t.k] and Within(t, L, NEAR.npc) then target = HubEnd(out, j) break end
          else
            local needs = t.sk == L.sk and (t.k == "skillup" or t.k == "turnin" or t.k == "do")
            if t.k ~= "buy" and Within(t, L, NEAR.learn) then target, before = j, needs break end
            -- (11.10., Daniel's dwarf: "Tailoring in Ironforge, too long a way") a trainer in a capital: what needs
            -- the profession before the next visit there (the skill-up) goes along behind the learning
            if needs and away then deferred[#deferred + 1] = j
            elseif needs then break end
          end
          j = j + 1
        end
        if target then
          local block, later = {}, {}
          for k = #deferred, 1, -1 do table.insert(later, 1, table.remove(out, deferred[k])) end
          target = target - #deferred
          for _ = 0, nb do block[#block + 1] = table.remove(out, i) end
          target = target - #block
          local at = before and target or target + 1
          for _, t in ipairs(later) do block[#block + 1] = t end
          for n, t in ipairs(block) do table.insert(out, at + n - 1, t) end
          moved = true
          -- the profession's accept before the learn now: to the next visit of its giver after it
          local li = at
          local acc, tin
          for k = 1, #out do
            local t = out[k]
            if not turnins and t.sk == L.sk and t.k == "accept" and k < li and not acc then
              -- (15.10., review round 3) not one handed in before this learn step (the 1-30 band's accept, pulled
              -- behind the 30-60 band's learn step: "turn in Camping 101: Leatherworking" without the quest)
              local handed = false
              for m = k + 1, li - 1 do if out[m].k == "turnin" and out[m].q == t.q then handed = true break end end
              if not handed then acc = k end
            end
            if t.sk == L.sk and t.k == "turnin" and k > li and not tin then tin = k end
          end
          if acc then
            local A = out[acc]
            for k = li + #block, (tin or #out + 1) - 1 do
              local t = out[k]
              if t ~= A and NPC_KIND[t.k] and Within(t, A, NEAR.sameNpc) then
                table.remove(out, acc)
                table.insert(out, k, A) -- k - 1 + 1: right after that visit
                break
              end
            end
          end
        end
      end
    end
    if not moved then i = i + 1 end
  end
end

-- (0.1.6 playtest 1, Daniel 10.10.: Northshire, "into the abbey, out to Eagan, around to Willem, into the
-- abbey again") a hub (adjacent stops at NPCs within HUB_R) is walked once: its stops grouped by NPC (one
-- visit each), the NPCs in the shortest order from where you come to where you go next. Never before a
-- prerequisite (Questdon's data; a quest without data keeps its place after earlier turn-ins), an accept
-- never before the profession's learn, the same quest's steps in their order. Escort accepts, the book's
-- turn-in and the choice end a hub; at most 7 NPCs, else it stays as planned.
local function Prereqs(q)
  local a = API()
  if not (q and a and a.GetQuest) then return nil end
  local ok, info = pcall(a.GetQuest, q)
  if not ok or type(info) ~= "table" then return nil end
  local set = {}
  for _, p in ipairs(type(info.prereqs) == "table" and info.prereqs or {}) do if type(p) == "number" then set[p] = true end end
  return set
end
local function HubBreaks(t) return not NPC_KIND[t.k] or not (t.m and t.x) or t.esc or t._book end
local function BestHubOrder(run, prev, nxt)
  local groups, gOf = {}, {}
  for k, t in ipairs(run) do
    local g
    for gi, G in ipairs(groups) do if Within(run[G[1]], t, NEAR.sameNpc) then g = gi break end end
    if not g then groups[#groups + 1] = {} g = #groups end
    table.insert(groups[g], k)
    gOf[k] = g
  end
  if #groups < 2 or #groups > 7 then return nil end
  local deps = {}
  for k, t in ipairs(run) do
    deps[k] = {}
    local pre = t.k == "accept" and Prereqs(t.q)
    for p = 1, k - 1 do
      local u = run[p]
      local need = (t.q and u.q == t.q)
        or (t.k == "accept" and u.k == "turnin" and (pre == nil or pre[u.q]))
        or (t.sk and u.k == "learn" and u.sk == t.sk)
      if need then deps[k][p] = true end
    end
  end
  local inside = {}
  local function In(t)
    if not t then return nil end
    local v = inside[t]
    if v == nil then v = Indoor(t) if v == nil then v = "?" end inside[t] = v end
    if v == "?" then return nil end
    return v
  end
  local function Cost(a, b)
    local d = (a and b and Yards(a, b)) or 0
    local ia, ib = In(a), In(b)
    if ia ~= nil and ib ~= nil and ia ~= ib then d = d + NEAR.door end
    return d
  end
  local orig, last = 0, prev
  for _, t in ipairs(run) do orig = orig + Cost(last, t) last = t end
  orig = orig + Cost(last, nxt)
  -- the ways between the NPCs, once (index 0: where you come from)
  local n = #groups
  local D, toNext = { [0] = {} }, {}
  for gi = 1, n do
    local a = run[groups[gi][1]]
    D[0][gi] = Cost(prev, a)
    toNext[gi] = Cost(a, nxt)
    D[gi] = {}
    for gj = 1, n do if gi ~= gj then D[gi][gj] = Cost(a, run[groups[gj][1]]) end end
  end
  -- what each NPC needs visited before it
  local needG = {}
  for gi, G in ipairs(groups) do
    needG[gi] = {}
    for _, k in ipairs(G) do for p in pairs(deps[k]) do if gOf[p] ~= gi then needG[gi][gOf[p]] = true end end end
  end
  -- the shortest order over all NPCs (Held-Karp over the visited sets, at most 7 NPCs)
  local needMask = {}
  for gi = 1, n do
    local m = 0
    for g in pairs(needG[gi]) do m = m + 2 ^ (g - 1) end
    needMask[gi] = m
  end
  local function Has(mask, g) return math.floor(mask / 2 ^ (g - 1)) % 2 == 1 end
  local function Covers(mask, need)
    for g = 1, n do if Has(need, g) and not Has(mask, g) then return false end end
    return true
  end
  local full = 2 ^ n - 1
  local cost, from = {}, {}
  for gi = 1, n do
    if needMask[gi] == 0 then local m = 2 ^ (gi - 1) cost[m] = cost[m] or {} cost[m][gi] = D[0][gi] end
  end
  for mask = 1, full do
    local row = cost[mask]
    if row then
      for last, c in pairs(row) do
        for gi = 1, n do
          if not Has(mask, gi) and Covers(mask, needMask[gi]) then
            local m2 = mask + 2 ^ (gi - 1)
            local c2 = c + D[last][gi]
            cost[m2] = cost[m2] or {}
            if not cost[m2][gi] or c2 < cost[m2][gi] then
              cost[m2][gi] = c2
              from[m2] = from[m2] or {}
              from[m2][gi] = last
            end
          end
        end
      end
    end
  end
  local best, bestCost
  for last, c in pairs(cost[full] or {}) do
    local total = c + toNext[last]
    if not bestCost or total < bestCost then bestCost, best = total, last end
  end
  if best then
    local seq, mask, last = {}, full, best
    while last do
      table.insert(seq, 1, last)
      local prevLast = from[mask] and from[mask][last]
      mask = mask - 2 ^ (last - 1)
      last = prevLast
    end
    best = seq
  end
  if not best or bestCost >= orig - 5 then return nil end
  local out = {}
  for _, gi in ipairs(best) do for _, k in ipairs(groups[gi]) do out[#out + 1] = run[k] end end
  return out
end
function HubOrder(out)
  -- the choice step (a prompt, no stop of its own) inside a hub goes in front of it: the hub stays one
  for p = 2, #out - 1 do
    local t = out[p]
    if t.k == "profs" and not HubBreaks(out[p - 1]) and not HubBreaks(out[p + 1]) and Within(out[p - 1], out[p + 1], NEAR.hub) then
      local q = p - 1
      while q > 1 and not HubBreaks(out[q - 1]) and Within(out[q - 1], out[p + 1], NEAR.hub) do q = q - 1 end
      table.remove(out, p)
      table.insert(out, q, t)
    end
  end
  local i = 1
  while i <= #out do
    if not HubBreaks(out[i]) then
      local j = i
      while out[j + 1] and not HubBreaks(out[j + 1]) and Within(out[j + 1], out[i], NEAR.hub) do j = j + 1 end
      if j > i then
        local prev, nxt
        -- where you come from and go to (the choice step has the place of a trainer, not yours)
        for k = i - 1, math.max(1, i - 4), -1 do if out[k].m and out[k].x and out[k].k ~= "profs" then prev = out[k] break end end
        for k = j + 1, math.min(#out, j + 4) do if out[k].m and out[k].x and out[k].k ~= "profs" then nxt = out[k] break end end
        local run, own = {}, true
        for k = i, j do run[#run + 1] = out[k] own = own and out[k]._ho == true end
        -- (11.10.) a band the builder already walked hub by hub (leveldon-build/hubopt.py, hubopt = true) keeps
        -- its order; only runs with steps put in here (bonus chains, moved accepts) are sorted again
        -- (Questdon may know a prerequisite the builder did not: then it is sorted here after all)
        local broken = false
        if own then
          for a2 = 1, #run do
            local pre = run[a2].k == "accept" and Prereqs(run[a2].q)
            if pre then for b2 = a2 + 1, #run do if run[b2].k == "turnin" and pre[run[b2].q] then broken = true end end end
          end
        end
        local better = (not own or broken) and BestHubOrder(run, prev, nxt) or nil
        if better then for k = i, j do out[k] = better[k - i + 1] end end
      end
      i = j + 1
    else
      i = i + 1
    end
  end
end
-- (0.1.6 playtest 1) talking to the NPC of a step (within 20 yd): note whether that place is indoors
function RecordIndoor()
  if type(IsIndoors) ~= "function" then return end
  local okI, v = pcall(IsIndoors)
  if not okI or (v ~= nil and not Usable(v)) then return end
  local a = API()
  if not (a and a.DistanceTo) then return end
  -- the current step first, then the one before and after; the nearest of them within 20 yd
  local best, bd
  for _, j in ipairs({ cur, cur - 1, cur + 1 }) do
    local t = STEPS[j]
    if t and NPC_KIND[t.k] and t.m and t.x then
      local ok, d = pcall(a.DistanceTo, t.m, t.x / 100, t.y / 100)
      if ok and type(d) == "number" and Usable(d) and d < 20 and (not bd or d < bd) then best, bd = t, d end
    end
  end
  if best then
    LeveldonDB = LeveldonDB or {}
    LeveldonDB.indoors = LeveldonDB.indoors or {}
    LeveldonDB.indoors[PlaceKey(best)] = (v and v ~= 0) and true or false
  end
end
ns.RecordIndoor = function() return RecordIndoor() end -- (tests)
end
ns.HubOrder = HubOrder -- (tests)
-- (0.1.6 playtest 1) a profession quest's accept never before a prerequisite's turn-in: the ones put in at the choice
-- (Camping 101 for a profession the route was not built with) came before "The Great Outdoors" they need
local function AfterPrereqs(out)
  local a = API()
  if not (a and a.GetQuest) then return end
  local turninAt = {}
  for j, t in ipairs(out) do if t.k == "turnin" and t.q and not turninAt[t.q] then turninAt[t.q] = j end end
  local j = 1
  while j <= #out do
    local t = out[j]
    local moved = false
    if t.k == "accept" and t.q and t.sk then
      local ok, info = pcall(a.GetQuest, t.q)
      local last
      for _, p in ipairs(ok and type(info) == "table" and type(info.prereqs) == "table" and info.prereqs or {}) do
        local at = type(p) == "number" and turninAt[p]
        if at and at > j and (not last or at > last) then last = at end
      end
      if last then
        table.remove(out, j)
        table.insert(out, last, t) -- right after that turn-in (it moved up by one)
        for q, at in pairs(turninAt) do if at > j and at <= last then turninAt[q] = at - 1 end end
        moved = true
      end
    end
    if not moved then j = j + 1 end
  end
end
ns.Yards = Yards -- (tests)
ns.Within = function(a, b, r) return Within(a, b, r) end -- (0.1.7 Fit.lua)
-- (23.10., player Dorandy 18.10.: "dying right after the quest giver in front of the cave brings you back in the start
-- area, you have to run to 37.3 60.6 and die there, lead there first") a death on purpose counts only where the game
-- sends you to this spirit healer: far from the planned place (m, x, y) and not yet on the healer's side of it, the
-- step leads there first (text and compass), then says to die
ns.DIE_SPOT_YARDS = 50
function ns.DieWalkFirst(s)
  if not (s and s.k == "die" and s.m and s.x and s.y and s.gm and s.gx and s.gy) then return false end
  local m = Map()
  local x, y = ns.PlayerXY()
  if not (m and x and y) or m ~= s.m then return false end
  local here, spot, healer = { m = m, x = x, y = y }, { m = s.m, x = s.x, y = s.y }, { m = s.gm, x = s.gx, y = s.gy }
  local dSpot = Yards(here, spot)
  if not dSpot or dSpot <= ns.DIE_SPOT_YARDS then return false end
  local dHere, dPlace = Yards(here, healer), Yards(spot, healer)
  if dHere and dPlace and dHere < dPlace then return false end
  return true
end
ns.HubEnd = function(out, j) return HubEnd(out, j) end -- (0.1.7 Fit.lua)

-- (0.1.6, Daniel 10.10.) the start area's book quest: with a gathering profession chosen, its turn-in says which
-- book to pick, a "use" step follows, and the start-area trainer for that profession is left out (the book
-- teaches it; its tool stays on the way)
local function WantsBook(chosen)
  if not chosen or (db and db.noProfs) then return false end
  for _, k in ipairs(GATHER_ORDER) do if chosen[k] and SkillRank(k) == nil then return true end end
  return false
end

local function GatherBook(out, chosen)
  if not chosen or (db and db.noProfs) then return end
  local sk
  for _, k in ipairs(GATHER_ORDER) do
    if chosen[k] and SkillRank(k) == nil then sk = k break end
  end
  if not sk then return end
  local j
  for i, t in ipairs(out) do if t.k == "turnin" and t.q and BOOK_QUESTS[t.q] then j = i break end end
  if not j then return end
  local book = GATHER_BOOK[sk]
  local t = out[j]
  -- (15.10., review round 3) the book quest handed in and that book not in your bags: the book went to another
  -- profession, this one's trainer stays (a recompose took Mining's learn step away after the Skinning book)
  if t.q and QuestDone(t.q) and ItemCount(book.i) == 0 then return end
  t._book = { i = book.i, sk = sk }
  table.insert(out, j + 1, { k = "use", i = book.i, sk = sk, q = nil, bq = t.q, n = ItemName(book.i, book.n), m = t.m, x = t.x, y = t.y })
  local i = 1
  while i <= #out do
    local u = out[i]
    if u.k == "learn" and u._early and u.sk == sk then table.remove(out, i) else i = i + 1 end
  end
end

local laterPlaced = {} -- (playtest 1) item -> the buy step put in for a waiting buy (until the next Compose)
-- (0.1.7) the quest of the step at i is gone from the log (abandoned): a copy of its accept step goes in
-- at i (once per quest and session); false when the route has no accept for it before i
ns.RetakeBefore = function(i)
  local s = STEPS[i]
  ns._retaken = ns._retaken or {}
  if not s or ns._retaken[s.q] then return false end
  for j = i - 1, 1, -1 do
    local t = STEPS[j]
    if t.k == "accept" and t.q == s.q then
      local c = {}
      for k, v in pairs(t) do c[k] = v end
      c._retake = true
      table.insert(STEPS, i, c)
      ns._retaken[s.q] = true
      return true
    end
  end
  return false
end

-- (0.1.7) a quest above your level now: Questdon's minimum level
ns.TooLowFor = function(q)
  local a = API()
  if not q or not a or QuestDone(q) or InLog(q) then return false end
  local g = a.GetQuest and a.GetQuest(q)
  local min = g and tonumber(g.minLevel)
  if min ~= nil and Level() < min then return true, min end
  -- (Daniel 11.10.: "The Adventurer" not there either) the quest giver did not offer it at this level
  -- (Questdon read it from the NPC's dialog, until the next level up): later, too
  if a.NotOfferedLevel and a.NotOfferedLevel(q) then return true, min or (Level() + 1) end
  return false, min
end
-- (0.1.7) the accept at step i to the route's next stop at the same NPC or hub (where you are more likely
-- at the level by then; the planned level "el" helps), its do and turn-in steps behind it; false: no visit
ns.MoveAcceptLater = function(i)
  local s = STEPS[i]
  if not (s and s.m and s.x) then return false end
  local _, min = ns.TooLowFor(s.q)
  local first, best, chapters = nil, nil, 0
  for j = i + 1, math.min(#STEPS, i + 250) do
    local t = STEPS[j]
    if t.k == "chapter" then chapters = chapters + 1 if chapters > 1 then break end end
    if NPC_KIND[t.k] and t.q ~= s.q and Within(t, s, NEAR.hub) then
      first = first or j
      if min and (t.el or 0) >= min then best = j break end
    end
  end
  local to = best or first
  if not to then return false end
  table.remove(STEPS, i)
  to = to - 1
  local at = HubEnd(STEPS, to)
  table.insert(STEPS, at + 1, s)
  s._movedLater = ns._composeId   -- (review round 3) moved in this composition: for RefindCur and SaveStep
  -- (15.10., review round 3) and kept when the steps are built again (a trainer, a talent point): behind the same
  -- route step
  for j = at, 1, -1 do
    if STEPS[j]._i then ns.LaterMove(s.q, STEPS[j]._i) break end
  end
  -- its own do and turn-in steps that now stand before it go behind it, in their order
  local moved, j = {}, i
  while j <= at do
    local t = STEPS[j]
    if t.q == s.q and (t.k == "do" or t.k == "turnin") then
      table.insert(moved, table.remove(STEPS, j))
      at = at - 1
    else
      j = j + 1
    end
  end
  for k, t in ipairs(moved) do table.insert(STEPS, at + 1 + k, t) end
  ns._movedLater = ns._movedLater or {}
  if not ns._movedLater[s.q] then
    ns._movedLater[s.q] = true
    print((L["|cff3fa9f5Level|rdon: \"%s\" needs level %d. It comes back when the route passes this place again."]):format(ns.QName(s) or "?", min or 0))
  end
  return true
end

local function Compose()
  laterPlaced = {}
  ns._composeId = (ns._composeId or 0) + 1
  local chosen = db and db.profs
  for _, s in ipairs(ROUTE.steps) do s._fc = nil end
  local out, pending = {}, nil
  local planned = {} -- original step index -> dungeon ids planned after it
  for _, p in ipairs(db and db.dPlans or {}) do planned[p.at] = planned[p.at] or {} table.insert(planned[p.at], p.id) end
  local bonusAt, merges = {}, {}
  for _, b in ipairs(db and db.bonusPlans or {}) do bonusAt[b.at] = bonusAt[b.at] or {} table.insert(bonusAt[b.at], b.q) end
  local inRoute = {}
  for _, s in ipairs(ROUTE.steps) do if s.sk and s.k == "learn" then inRoute[s.sk] = true end end
  local cooking = (chosen and chosen[185]) or (not chosen and inRoute[185]) or SkillRank(185) ~= nil
  local wantsBook = WantsBook(chosen)
  local planned_ = {}
  for _, b in ipairs(db and db.bonusPlans or {}) do planned_[b.q] = true end
  for _, s in ipairs(ROUTE.steps) do
    if s.k == "chapter" and pending then
      for _, p in ipairs(pending) do out[#out + 1] = p end
      pending = nil
    end
    -- (0.1.2, Daniel 09.10.) solo: no group and escort quests (/lvd solo)
    local soloOut = db and db.solo and (s.grp or s.esc)
    -- (0.1.3, Daniel 09.10.) trainer stops lead to the trainer of your own class
    if s.k == "train" and s.tr then
      local _, myClass = UnitClass("player")
      local t = myClass and s.tr[myClass]
      -- (15.10., review round 2) the same object every time (a rebuild at the trainer lost the step and the route
      -- jumped), with the trainer's id for its map mark (names only match in English)
      if t then
        ns._trainObj = ns._trainObj or setmetatable({}, { __mode = "k" })
        local o = ns._trainObj[s]
        if not (o and o.cls == myClass) then
          o = { k = "train", lvl = s.lvl, n = t.n, m = t.m, x = t.x, y = t.y, el = s.el, _i = s._i, _ho = s._ho, npc = t.id, cls = myClass }
          ns._trainObj[s] = o
        end
        s = o
      end
    end
    -- (0.1.7) quests taken out of the routes after reports (Fit.lua, ns.SKIP_QUESTS)
    local skipQ = s.q and ns.SKIP_QUESTS and ns.SKIP_QUESTS[s.q]
    if not (chosen and s.sk and not chosen[s.sk]) and not soloOut and not skipQ then
      out[#out + 1] = s
      if s.k == "learn" then for _, b in ipairs(BuySteps(s, s.sk, cooking)) do out[#out + 1] = b end end
    end
    for _, root in ipairs(bonusAt[s._i] or {}) do merges[#merges + 1] = { root = root, at = #out } end
    if s.k == "do" then
      for root, f in pairs(FARM_BOOK) do
        if (wantsBook or f.all) and f.after == s.q and ROUTE.bonus and ROUTE.bonus[root] and not planned_[root] and not QuestDone(root) then
          out[#out + 1] = { k = "farm", q = root, i = f.i, n = ItemName(f.i, f.n), mob = L[f.mob], m = s.m, x = s.x, y = s.y, chain = not wantsBook }
          merges[#merges + 1] = { root = root, at = #out }
          planned_[root] = true
        end
      end
    end
    for _, id in ipairs(planned[s._i] or {}) do
      local d = DUNGEON_BY_ID[id]
      if d then for _, x in ipairs(DungeonSteps(d, s.m, s.x, s.y)) do out[#out + 1] = x end end
    end
    if s.k == "profs" and chosen then
      pending = {}
      for _, o in ipairs(ROUTE.profOptions or {}) do
        if chosen[o.sk] and not inRoute[o.sk] then
          out[#out + 1] = { k = "learn", sk = o.sk, n = o.skn, m = o.t.m, x = o.t.x, y = o.t.y }
          for _, b in ipairs(BuySteps(o, o.sk, cooking)) do out[#out + 1] = b end
          out[#out + 1] = { k = "accept", q = o.q, n = o.n, lv = o.lv, sk = o.sk, m = o.a.m, x = o.a.x, y = o.a.y }
          pending[#pending + 1] = { k = "skillup", sk = o.sk, n = o.skn, need = o.need, mats = o.mats, m = o.t.m, x = o.t.x, y = o.t.y }
          pending[#pending + 1] = { k = "turnin", q = o.q, n = o.n, lv = o.lv, sk = o.sk, m = o.t.m, x = o.t.x, y = o.t.y }
        end
      end
    end
  end
  if pending then for _, p in ipairs(pending) do out[#out + 1] = p end end
  -- (0.1.4, Daniel 09.10.: after the book chain came in, Goldshire's turn-ins and accepts waited behind
  -- all of it) each step of a bonus chain goes where the route passes its place anyway, in its order
  table.sort(merges, function(a, b) return a.at > b.at end)
  for _, mg in ipairs(merges) do
    local last = mg.at
    for _, c in ipairs(ns.SoloChain(ROUTE.bonus and ROUTE.bonus[mg.root] or {})) do
      local found
      if c.m and c.x then
        -- (0.1.6 playtest 1, Daniel 10.10.: the book chain's quests stayed open while the route went on)
        -- at the same NPC or building as the chain's step before it: right behind it; an accept or turn-in
        -- at the route's next hub within NPC_NEAR (behind the hub, its order is sorted out below); a mob area
        -- with the route's own mobs within DO_NEAR (one visit, e.g. the kobolds of Echo Ridge); else the first
        -- step within PASS_NEAR (on the way to it when that is a mob area)
        local prevC = out[last]
        local wayJ
        if c.way and MOB_KIND[c.k] then
          -- (24.10., Daniel's Kamarace: Shhh! We're Hunting Kobolds "on the way to Goldshire") a kill spot on the road to the
          -- next area (way=true in the chain's row, Korrekturliste): done before the route leaves for it, at the end of this one
          local j = last
          while out[j + 1] and out[j + 1].k ~= "chapter" do j = j + 1 end
          if out[j + 1] then wayJ = j end
        end
        if wayJ then
          found = wayJ
        elseif NPC_KIND[c.k] and prevC and NPC_KIND[prevC.k] and Within(prevC, c, NEAR.npc) then
          found = last
        else
          local chapters, pass = 0, nil
          for j = last + 1, #out do
            local t = out[j]
            if t.k == "chapter" then chapters = chapters + 1 if chapters > 1 then break end end
            if NPC_KIND[c.k] and NPC_KIND[t.k] and Within(t, c, NEAR.npc) then found = HubEnd(out, j) break end
            if MOB_KIND[c.k] and MOB_KIND[t.k] and Within(t, c, NEAR.mob) then found = j break end
            if not pass and Within(t, c, NEAR.pass) then pass = j end
          end
          if not found and pass then found = MOB_KIND[out[pass].k] and pass - 1 or pass end
        end
      end
      local at = math.max(found or last, last)
      table.insert(out, at + 1, c)
      last = at + 1
    end
  end
  -- (0.1.4, Daniel 09.10.: "could I not have learned Skinning in the start area?") gathering professions
  -- with a trainer in the start area: the choice and those trainers come there, where the route passes them
  local firstLearn
  for _, e in ipairs(ROUTE.early or {}) do
    if not (chosen and not chosen[e.sk]) then
      local at, chapters = nil, 0
      for j = 1, #out do
        local t = out[j]
        if t.k == "chapter" then chapters = chapters + 1 if chapters > 1 then break end end
        if t.m == e.m and t.x and ((t.x - e.x) ^ 2 + (t.y - e.y) ^ 2) < MERGE_NEAR ^ 2 then at = at or j end
        -- (0.1.6 playtest 1) better: a stop at an NPC close to the trainer (not the middle of a mob area)
        if NPC_KIND[t.k] and Within(t, e, NEAR.npc) then at = j break end
      end
      if at then
        -- (review round 3) the same object every time; the trainer's name for its map mark
        ns._earlyObj = ns._earlyObj or setmetatable({}, { __mode = "k" })
        local lo = ns._earlyObj[e]
        if not lo or lo._used == ns._composeId then
          lo = { k = "learn", sk = e.sk, n = e.n .. " (" .. (e.npc or "?") .. ")", m = e.m, x = e.x, y = e.y, _early = true, tn = e.npc }
          ns._earlyObj[e] = lo
        end
        lo._used = ns._composeId
        table.insert(out, at + 1, lo)
        for n, b in ipairs(BuySteps(e, e.sk, cooking)) do table.insert(out, at + 1 + n, b) end
        if not firstLearn or at + 1 <= firstLearn then firstLearn = at + 1 end
      end
    end
  end
  if firstLearn then
    local l = out[firstLearn]
    table.insert(out, firstLearn, { k = "profs", m = l.m, x = l.x, y = l.y })
  end
  -- one buy per item: the first on the way (a hammer for Blacksmithing and Engineering, a knife from
  -- the start area's trainer and again at the Camping 101 quest)
  local bought, j = {}, 1
  while j <= #out do
    local t = out[j]
    if t.k == "buy" and not t.q and bought[t.i] then table.remove(out, j)
    else
      if t.k == "buy" and not t.q then bought[t.i] = true end
      j = j + 1
    end
  end
  LearnDetours(out)
  if ns.CookingAtLearn then ns.CookingAtLearn(out) end -- (11.10.) Camping 101: Cooking right after learning
  FishAndCook(out, chosen)
  GatherBook(out, chosen)
  LearnDetours(out, true) -- (playtest 1) the professions' turn-ins the same way, with the next visit of their NPC
  MergeBuys(out)
  AfterPrereqs(out)
  -- (0.1.7, Daniel 11.10.) quests you took yourself that fit the route (Fit.lua)
  if ns.ApplyExtraPlans then ns.ApplyExtraPlans(out) end
  HubOrder(out)
  -- (0.1.7, Daniel 11.10.: a timed quest failed) its do and turn-in right behind the accept
  if ns.TimedOrder then ns.TimedOrder(out) end
  if ns.CookAtFire then ns.CookAtFire(out) end -- (11.10.)
  -- (0.1.7) trainer visits without anything worth the trip go; the next visit teaches it all
  if ns.TR.Data() then
    local planned, last, dropped = {}, (db and db.trained) or 1, 0
    local j = 1
    while j <= #out do
      local t = out[j]
      if t.k == "train" and t.lvl then
        local twos, ones, list = ns.TR.Pending(t.lvl, planned)
        if t.lvl > ((db and db.trained) or 0) and not ns.TR.Worth(twos, ones, t.lvl - last) then
          table.remove(out, j)
          dropped = dropped + 1
        else
          t.learns, t.optional = {}, 0
          local spec = ns.TR.Spec()
          -- (15.10., review round 1) a visit already past (nothing learned there, 5 copper) does not plan its
          -- spells away: the next visit still recommends them
          -- (review round 4) and not the visit just made (marked at the trainer window)
          local future = t.lvl > ((db and db.trained) or 0) and not marks[t]
          for _, e in ipairs(list) do
            if future then planned[e[1]] = true end
            local imp = ns.TR.Imp(e, spec)
            if imp == 2 then t.learns[#t.learns + 1] = e elseif imp == 1 then t.optional = t.optional + 1 end
          end
          last = t.lvl
          j = j + 1
        end
      else
        j = j + 1
      end
    end
    ns._trainDropped = dropped
  end
  -- (15.10., review round 3) accepts moved further on for their level (MoveAcceptLater) stay moved
  -- (15.10., review round 4) class quests ClassNow pulled forward stay there
  for q, before in pairs(db and db.pullMoves or {}) do
    if not QuestDone(q) then
      local bi
      for j, t in ipairs(out) do if t._i == before then bi = j break end end
      if bi then
        local moved, j = {}, bi + 1
        while j <= #out do
          local t = out[j]
          if t.q == q and (t.k == "accept" or t.k == "do" or t.k == "turnin") then table.insert(moved, table.remove(out, j)) else j = j + 1 end
        end
        -- (an accept left behind would follow its own kill step: then nothing moves)
        local accBefore = false
        for j2 = 1, bi - 1 do if out[j2].q == q and out[j2].k == "accept" then accBefore = true end end
        local accMoved = false
        for _, t in ipairs(moved) do if t.k == "accept" then accMoved = true end end
        if accMoved or accBefore or #moved == 0 then
          for k, t in ipairs(moved) do table.insert(out, bi + k - 1, t) t._pulled = ns._composeId end
        else
          for _, t in ipairs(moved) do table.insert(out, t) end
        end
      end
    end
  end
  for q, after in pairs(db and db.laterMoves or {}) do
    local ai, ti
    for j, t in ipairs(out) do
      if t.k == "accept" and t.q == q and not ai then ai = j end
      if t._i == after then ti = j end
    end
    if ai and ti and ai < ti and not QuestDone(q) and not InLog(q) then
      local a = table.remove(out, ai)
      table.insert(out, ti, a)   -- (ti - 1 + 1: right after that step)
      a._movedLater = ns._composeId
      -- its own do and turn-in steps that now stand before it go behind it, in their order
      local moved, j = {}, 1   -- (review round 4) any of them before it, not only those between
      while j < ti do
        local t = out[j]
        if t.q == q and (t.k == "do" or t.k == "turnin") then table.insert(moved, table.remove(out, j)) ti = ti - 1 else j = j + 1 end
      end
      for k, t in ipairs(moved) do table.insert(out, ti + k, t) end
    end
  end
  STEPS = out
end
-- (0.1.6 playtest 1, Daniel 10.10.) a buy that waited for the money: once it is there, the buy goes in behind
-- the next stop of the route (this chapter or the next) at a vendor that sells it; never a trip of its own.
-- Bought meanwhile, or its profession dropped: forgotten.
local function PlaceLaterBuys()
  if not (db and db.buyLater) then return end
  for i, info in pairs(db.buyLater) do
    local owned = ItemCount(i) > 0 or (IsEquippedItem ~= nil and IsEquippedItem(i) == true) or (info.sp ~= nil and Knows(info.sp))
    if owned or (db.profs and info.sk and not db.profs[info.sk]) or db.noProfs then
      db.buyLater[i] = nil
    elseif not CantAfford(i) then
      local ahead = false
      for j = cur, #STEPS do if STEPS[j].k == "buy" and STEPS[j].i == i then ahead = true break end end
      if not ahead then
        local sellers, ch = Sellers(i), 0
        for j = math.max(cur, 1), #STEPS do
          local t = STEPS[j]
          if t.k == "chapter" and j > cur then ch = ch + 1 if ch > 1 then break end end
          local v = AtSeller(t, sellers)
          if v then
            local b = { k = "buy", i = i, n = info.n, v = v.n, m = v.m, x = v.x, y = v.y, sk = info.sk, sp = info.sp, ck = info.ck, _later = true }
            table.insert(STEPS, j + 1, b)
            laterPlaced[i] = b
            break
          end
        end
      end
    end
  end
end
ns.PlaceLaterBuys = PlaceLaterBuys -- (tests)
ns.LeveldonSteps = function() return STEPS end -- (tests)
ns.LeveldonStepDone = function(i) return StepDone(i) end -- (tests)
ns.LeveldonStepText = function(i, upcoming) return StepText(STEPS[i], upcoming) end -- (tests)
ns.LeveldonCompose = function() Compose() end -- (tests)
ns.LeveldonCur = function(i) if i then cur = i end return cur end -- (tests; 0.1.7 also the recorder)
ns.LeveldonRouteKey = function() return db and db.route end -- (0.1.7 recorder, reports)
-- (13.10.) the ids of the route bands loaded ("2cf90623d2+..."), nil for a route without ids (built-in test route)
ns.LeveldonRouteId = function() return ROUTE and ROUTE.ids and #ROUTE.ids > 0 and table.concat(ROUTE.ids, "+") or nil end
ns.LeveldonRoute = function() return ROUTE end -- (0.1.7 tests)
ns.LeveldonPanelFrame = function() return panel end -- (0.1.7 Resize.lua)


---------------------------------------------------------------------------
-- (0.1.2, Daniel 09.10.) On the way: hints below the current step.
--   Mobs on the way: always on a walk, louder when you are behind the plan
--     (every step knows the level the route expects there, el).
--   Vendor on the way: a merchant from the route's list within 60 yards:
--     sell (Questdon repairs and sells grey items); hunters: ammunition.
--   Campfire: once an hour, optional (db.camp ~= false), when you carry a
--     Basic Campfire Kit or Simple Wood with Flint and Tinder.
--   Buff food: the Well Fed buff runs out (15 minutes): eat again.
--   Bag check at login: campfire material and food with you?
---------------------------------------------------------------------------
local KIT, WOOD, FLINT = 279981, 4470, 4471
local CAMP_EVERY = 3600
local campAt = 0         -- GetTime() of the last campfire (0: none this session)
local sessionStart = 0
local merchantAt = -1e9
local wellFedName

local function Now() return GetTime and GetTime() or 0 end
local function Count(id) return ItemCount(id) end
local function HasCampMaterial() return Count(KIT) > 0 or (Count(WOOD) > 0 and Count(FLINT) > 0) end
ns.NoCampfire = function() return not HasCampMaterial() end -- (11.10. Place)
-- (Daniel 09.10.) the campfire only once the character can make one: Cooking learned
-- (the Basic Campfire Kit needs Cooking 1; the Camping 101 quests come with it)
local function CanCamp() return SkillRank(185) ~= nil end

-- (12.10., Daniel: "use the sleeping bag continuously, it gives more speed") The Cozy Sleeping Bag (item 211527,
-- quest chain from level 14): a stack of Well-Rested per minute lying in it, up to 3 (+1 % XP each, kills and
-- quests), for 2 hours; the bag has a 1 hour cooldown and counts as a rest area (Rested XP). Reminder: when the
-- bonus runs out (or you have none yet), the bag is ready, out of combat and not in a town; eat and drink meanwhile.
-- (23.10., Daniel's /lvd mem: a window build about 58 KB) the player's buffs by name, read once after each change
-- (UNIT_AURA, at the latest every 10 s): C_UnitAuras.GetBuffDataByIndex hands out a new table of some 25 fields per
-- buff, and the window asked twice per build (sleeping bag, Well Fed), the recorder (eating) every second.
-- ns.Auras.Find(name): the buff's expiration time (0 without one), nil when it is not on you
ns.Auras = { by = {}, dirty = true, at = -100 }
function ns.Auras.Find(name)
  local A, now = ns.Auras, Now()
  if A.dirty or now - A.at > 10 or now < A.at then
    A.dirty, A.at = false, now
    for k in pairs(A.by) do A.by[k] = nil end
    for i = 1, 40 do
      local n, expires = Buff("player", i)
      if not n then break end
      if Usable(n) and A.by[n] == nil then A.by[n] = (type(expires) == "number" and Usable(expires)) and expires or 0 end
    end
  end
  return A.by[name]
end
do
  local af = ns.CreateFrame("Frame")
  if not (af.RegisterUnitEvent and pcall(af.RegisterUnitEvent, af, "UNIT_AURA", "player")) then pcall(af.RegisterEvent, af, "UNIT_AURA") end
  af:SetScript("OnEvent", function(_, _, unit) if unit == nil or unit == "player" then ns.Auras.dirty = true end end)
end
ns.Bag = { item = 211527, lasts = 7200, at = 0 } -- at: GetTime() when you lay down last (0: not this session)
function ns.Bag.Ready()
  if Count(ns.Bag.item) == 0 then return false end
  local start, dur
  if C_Container and C_Container.GetItemCooldown then start, dur = C_Container.GetItemCooldown(ns.Bag.item)
  elseif GetItemCooldown then start, dur = GetItemCooldown(ns.Bag.item) end
  start, dur = tonumber(start) or 0, tonumber(dur) or 0
  return start == 0 or dur == 0 or start + dur <= Now()
end
function ns.Bag.Left()
  ns.Bag.buff = ns.Bag.buff or "Well-Rested"
  local expires = ns.Auras.Find(ns.Bag.buff)
  if expires then return expires > 0 and (expires - Now()) or ns.Bag.lasts end
  if ns.Bag.at > 0 and Now() - ns.Bag.at < ns.Bag.lasts then return ns.Bag.lasts - (Now() - ns.Bag.at) end
  -- (15.10., review round 1) after a reload, in every language: the time you lay down, kept in the saved variables
  local at = db and tonumber(db.bagAt)
  if at and time and time() - at < ns.Bag.lasts then return ns.Bag.lasts - (time() - at) end
  return nil
end
ns.SleepingBagHint = function() -- (tests)
  if not (db ~= nil and db.bag ~= false and ns.Bag.Ready()) then return false end -- (23.10.) the buffs only when it can matter
  local left = ns.Bag.Left()
  return (not left or left < 600)
    and not (UnitAffectingCombat and UnitAffectingCombat("player")) and not (IsResting and IsResting())
end


-- food and drink in the bags (item class 0 = consumable, subclass 5 = food and drink)
local function FoodCount()
  local n = 0
  local slots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
  local itemID = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID
  local info = (C_Container and C_Container.GetContainerItemInfo)
  if not (slots and itemID) then return nil end
  for bag = 0, 4 do
    for slot = 1, (slots(bag) or 0) do
      local id = itemID(bag, slot)
      if id and C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(id)
        if classID == 0 and subclassID == 5 then
          local c = 1
          if info then local i = info(bag, slot) c = (type(i) == "table" and i.stackCount) or 1 end
          n = n + c
        end
      end
    end
  end
  return n
end

-- seconds left on Well Fed (nil: not fed)
local function WellFedLeft()
  wellFedName = wellFedName or SpellName(19705) or L["Well Fed"]
  local expires = ns.Auras.Find(wellFedName)
  if expires then return expires > 0 and (expires - Now()) or 900 end
  return nil
end
local wasFed = false

local function PlayerFrac()
  local cur, max = UnitXP and UnitXP("player") or 0, UnitXPMax and UnitXPMax("player") or 1
  return Level() + (max > 0 and cur / max or 0)
end

-- the experience of the finished quests in the log, as part of the current level
local function BankedFrac()
  local xp, seen = 0, {}
  for _, s in ipairs(STEPS) do
    if s.k == "turnin" and s.q and not seen[s.q] and InLog(s.q) and Complete(s.q) then
      seen[s.q] = true
      local live = GetQuestLogRewardXP and tonumber((select(2, pcall(GetQuestLogRewardXP, s.q))))
      xp = xp + ((live and live > 0) and live or s.xp or 0)
    end
  end
  local max = UnitXPMax and UnitXPMax("player") or 0
  return max > 0 and xp / max or 0
end

local function IsHunter() local _, c = UnitClass("player") return c == "HUNTER" end
local function AmmoCount()
  local slot = GetInventorySlotInfo and select(1, GetInventorySlotInfo("AmmoSlot"))
  return slot and GetInventoryItemCount and GetInventoryItemCount("player", slot) or 0
end
ns.IsHunter, ns.AmmoCount = IsHunter, AmmoCount -- (for StepText further up)

local function NearVendor()
  local a = API()
  if not (a and a.DistanceTo) or Now() - merchantAt < 600 then return nil end
  local here = Map()
  for _, v in ipairs(ROUTE.vendors or {}) do
    if v.m == here then
      local d = a.DistanceTo(v.m, v.x / 100, v.y / 100)
      if type(d) == "number" and d < 60 then return v, d end
    end
  end
end

local function NearTrainer()
  local a = API()
  local lv = Level()
  if not (a and a.DistanceTo and db) or lv < 2 or (db.trained or 1) >= lv - lv % 2 then return nil end
  if STEPS[cur] and STEPS[cur].k == "train" then return nil end
  -- (0.1.7) nothing worth the trip waits: no hint either
  local tw, on = ns.TR.Pending(lv)
  if tw and not ns.TR.Worth(tw, on, lv - (db.trained or 1)) then return nil end
  local here, seen = Map(), {}
  for _, s in ipairs(STEPS) do
    if s.k == "train" and s.m == here and s.x and s.y and not seen[s.n or ""] then
      seen[s.n or ""] = true
      local d = a.DistanceTo(s.m, s.x / 100, s.y / 100)
      if type(d) == "number" and d < 40 then return s, d end
    end
  end
end

-- (Daniel 12.10.: "the vendor on every hub visit, not only as a small hint"; "and when does the trainer come as
-- a stop? only a small hint too") arriving at a hub (the current step at an NPC, you within HUB_WALK yards): the
-- hub's vendor and your class trainer become steps of this visit, not only hints.
--   Vendor: grey loot worth GREY (copper), bags nearly full, gear worn down or (hunters) ammunition low, and no
--     vendor opened for HUB_EVERY seconds. The step goes before the hub's trainer, learning and buying (the
--     money first), else at the end of the visit (after the turn-ins). Done when a vendor window opened.
--   Trainer: new skills worth the trip (as the hint) and no trainer stop for them in this visit: at its end.
--     The route's own trainer stops planned for a level you have not reached yet go by (as before); this one
--     catches up at the next hub with your trainer.
-- Both within HUB_SERVICE yards of a stop of the visit, on the same map.
-- (12.10., Daniel's hunter: "selling at the start makes no sense"; "less than 100 arrows and I should keep killing
-- although I am at the hub") grey loot alone from level greyLevel and greyc copper; ammunition below ammo (a hunter
-- starts with 200 arrows, the old 400 sent him to the vendor at level 1)
ns.HUB = { walk = 200, service = 150, every = 600, grey = 50, greyLevel = 4, ammo = 150, wear = 0.6 }
do -- (no new main-chunk locals: Lua allows 200)
local function HubSellWorth()
  local H = ns.HUB
  if ns.FreeSlots and ns.FreeSlots() <= 4 then return true end
  if Level() >= H.greyLevel and ns.GreyValue and ns.GreyValue() >= H.grey then return true end
  if GetInventoryItemDurability then
    for slot = 1, 18 do
      local ok, c, m = pcall(GetInventoryItemDurability, slot)
      if ok and type(c) == "number" and type(m) == "number" and m > 0 and c / m < H.wear then return true end
    end
  end
  return IsHunter() and AmmoCount() < H.ammo
end
ns.HubSellWorth = HubSellWorth -- (tests)
local hubAsked = {}
local function Key(t) return ("%d:%.1f:%.1f"):format(t.m, t.x, t.y) end
function ns.CheckHub()
  local s = STEPS[cur]
  if not (db and s and NPC_KIND[s.k] and s.m and s.x and s.y) then return end
  if UnitAffectingCombat and UnitAffectingCombat("player") then return end
  local a = API()
  if not (a and a.DistanceTo) then return end
  local okD, d = pcall(a.DistanceTo, s.m, s.x / 100, s.y / 100)
  if not (okD and type(d) == "number" and d <= ns.HUB.walk) then return end
  local H, now = ns.HUB, Now()
  local last = HubEnd(STEPS, cur)
  local function NearVisit(t)
    for j = cur, last do if Within(t, STEPS[j], H.service) then return true end end
    return false
  end
  local firstPay, haveSell, haveTrain
  local lv = Level()
  for j = cur, last do
    local t = STEPS[j]
    if not firstPay and (t.k == "train" or t.k == "learn" or t.k == "buy") then firstPay = j end
    if t.k == "sell" then haveSell = true end
    if t.k == "train" and (t.lvl or 0) <= lv then haveTrain = true end
  end
  -- (22.10., Daniel: a fixed sell step at hubs) the route's own sell stop right behind the visit (its vendor stands
  -- 80 to 150 yd off the first stop, so HubEnd's run ends before it) is this visit's vendor stop: no second one
  local nxt = STEPS[last + 1]
  if nxt and nxt.k == "sell" and NearVisit(nxt) then haveSell = true end
  -- the vendor
  if not haveSell and now - (ns._merchantAt or -1e9) >= H.every and HubSellWorth() then
    local list = {}
    for _, v in ipairs(ROUTE.vendors or {}) do list[#list + 1] = v end
    for _, v in pairs(LeveldonDB and LeveldonDB.merchants or {}) do if type(v) == "table" then list[#list + 1] = v end end
    local best, bd
    for _, v in ipairs(list) do
      if v.m == s.m and v.x and v.y and NearVisit(v) then
        local y = Yards(v, s)
        if y and (not bd or y < bd) then best, bd = v, y end
      end
    end
    local key = best and Key(best)
    if best and now - (hubAsked[key] or -1e9) >= H.every then
      hubAsked[key] = now
      local at = firstPay or (last + 1)
      table.insert(STEPS, at, { k = "sell", n = best.n, m = best.m, x = best.x, y = best.y, why = "hub", t0 = now, ammo = best.ammo })
      last = last + 1
    end
  end
  -- the class trainer
  if not haveTrain and lv >= 2 and (db.trained or 1) < lv - lv % 2 then
    local tw, on = ns.TR.Pending(lv)
    if not tw or ns.TR.Worth(tw, on, lv - (db.trained or 1)) then
      local tr
      for _, t in ipairs(STEPS) do
        if t.k == "train" and t.m == s.m and t.x and t.y and NearVisit(t) then tr = t break end
      end
      -- (13.10., Daniel's mage Zip in Goldshire: "The Great Outdoors first would make more sense") quests right here
      -- without a fight (its do step and turn-in next to you) come before the trainer
      local at = last
      while STEPS[at + 1] and STEPS[at + 1].k == "do" and not ((STEPS[at + 1].kills or 0) > 0)
          and Within(STEPS[at + 1], s, NEAR.hub) do
        at = HubEnd(STEPS, at + 1)
      end
      -- (13.10., Zip leaving Northshire at level 6: "better learn in Goldshire, you do not fight any more until then")
      -- a trainer of your class the route passes before its next fight waits for that visit
      local later = false
      if tr then
        for j = at + 1, #STEPS do
          local u = STEPS[j]
          if (u.k == "do" and (u.kills or 0) > 0) or u.k == "grind" then break end
          if u.k ~= "train" and u.m and u.x then
            for _, t in ipairs(STEPS) do
              if t.k == "train" and t ~= tr and t.m == u.m and t.x and Within(t, u, H.service) and not Within(t, tr, H.service) then later = true break end
            end
          end
          if later then break end
        end
      end
      local key = tr and ("train:" .. Key(tr))
      if tr and not later and now - (hubAsked[key] or -1e9) >= H.every then
        hubAsked[key] = now
        table.insert(STEPS, at + 1, { k = "train", n = tr.n, lvl = lv - lv % 2, m = tr.m, x = tr.x, y = tr.y, npc = tr.npc or tr.id, _hub = true })
      end
    end
  end
end
ns.HubReset = function() for k in pairs(hubAsked) do hubAsked[k] = nil end end -- (tests)
-- a stop of this kind among the next few steps (the hints stay quiet then)
function ns.StopAhead(kind)
  for j = cur, math.min(#STEPS, cur + 6) do if STEPS[j].k == kind then return true end end
  return false
end
end

-- quest IDs in the log
-- (23.10., /lvd mem) the list is kept until the log changes (QUEST_LOG_UPDATE and its kin, ns._logDirty) and at most
-- 5 s: the game's C_QuestLog.GetInfo makes a new table of 21 fields for each line of the log, every 3 s for AlongHere
local function LogQuests()
  local now = GetTime and GetTime() or 0
  if ns._logQ and not ns._logDirty and now - (ns._logQAt or -100) < 5 and now >= (ns._logQAt or 0) then return ns._logQ end
  local out = {}
  ns._logQ, ns._logQAt, ns._logDirty = out, now, nil
  local n = (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries())
    or (GetNumQuestLogEntries and GetNumQuestLogEntries()) or 0
  for i = 1, n do
    local id
    if C_QuestLog and C_QuestLog.GetInfo then
      local info = C_QuestLog.GetInfo(i)
      id = info and not info.isHeader and info.questID
    elseif GetQuestLogTitle then
      local _, _, _, header, _, _, _, qid = GetQuestLogTitle(i)
      id = not header and qid
    end
    if id and id > 0 then out[#out + 1] = id end
  end
  return out
end

-- (0.1.4, Daniel 09.10.) another quest in the log has open objectives right here: do them along
local alongAt, alongName, alongObjs = 0, nil, nil
local function AlongHere(s)
  if Now() - alongAt < 3 then return alongName, alongObjs end
  alongAt, alongName, alongObjs, ns._alongQ = Now(), nil, nil, nil
  -- (21.10., Daniel: "what else is to do in this area") up to two more quests with open objectives right here:
  -- ns._alongMore (the first one stays as it was; the station lists the others below it)
  local more = ns._alongMore or {}
  ns._alongMore = more
  for k = #more, 1, -1 do more[k] = nil end
  local a = API()
  if not (a and a.ObjectivePoints and a.DistanceTo) then return nil end
  for _, q in ipairs(LogQuests()) do
    if q ~= (s and s.q) and not Complete(q) and #OpenObjectives(q) > 0 then
      local _, d = NearestObjective(q)
      if d and d < 120 then
        if not alongName then
          local name = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(q)
          alongName, alongObjs, ns._alongQ = name or (L["Quest "] .. q), OpenObjectives(q), q
        else
          more[#more + 1] = q
          if #more >= 2 then break end
        end
      end
    end
  end
  return alongName, alongObjs
end

local WALK = { accept = true, ["do"] = true, turnin = true, travel = true, grind = true, fp = true, bind = true, train = true, learn = true }
local function Hints(s)
  local out = {}
  -- (0.1.7) a timed quest: the time left; failed: abandon and take it again
  if s and s.q and (Kind(s) == "do" or s.k == "turnin") and InLog(s.q) then
    if ns.QuestFailed and ns.QuestFailed(s.q) then
      out[#out + 1] = { L["Failed: abandon it in your quest log and take it again, Leveldon then leads you back"], "warning" }
    else
      local left = ns.TimeLeft and ns.TimeLeft(s.q)
      if left then out[#out + 1] = { (L["Timed quest: %d:%02d left, no stops on the way"]):format(math.floor(left / 60), math.floor(left % 60)), "warning" } end
    end
  end
  -- (11.10., Daniel: "a button: I have enough", other meat for Cooking, not enough Linen) a skill-up can be left
  if s and s.k == "skillup" then out[#out + 1] = { L["Enough already, or no materials? The arrow \194\187 above goes on"], "textHint" } end
  -- (15.10., Daniel's mage Zip: "why does it send me to the herbs there? It should be a reminder", "I thought of
  -- being an herbalist much too late"; Camping 101 needs 20) a gathering skill-up later on the route: a reminder
  -- from now on, so the skill comes along the way and the step is done when you get there
  if s and s.k ~= "skillup" then
    for j = cur + 1, math.min(#STEPS, cur + 200) do
      local t = STEPS[j]
      if t and t.k == "skillup" and ns.GATHER_REMIND[t.sk] then
        local rank = SkillRank(t.sk)
        if rank and rank < (t.need or 20) then
          out[#out + 1] = { ns.GATHER_REMIND[t.sk]:format(rank, t.need or 20), "accent" }
        end
        break
      end
    end
  end
  -- (11.10., Daniel: "Kyle: nothing in the quest log", the game shows only "Kyle fed") what the game does not say
  local tip = s and s.q and (s.k == "do" or Kind(s) == "do" or s.k == "accept") and ns.QUEST_TIPS and ns.QUEST_TIPS[s.q]
  if tip then out[#out + 1] = { tip, "accent" } end
  -- (11.10., Daniel: "when an NPC patrols, that is important to know") Questdon saw it at places far apart
  local qa = (s and s.q and (s.k == "accept" or s.k == "turnin")) and API() or nil
  if qa and qa.QuestNpcWalks and qa.QuestNpcWalks(s.q, s.k == "turnin") then
    out[#out + 1] = { (s.k == "turnin" and L["The turn-in NPC"] or L["The quest giver"]) .. L[" walks around: look nearby"], "accent" }
  end
  -- (0.1.7) a trainer visit: what it teaches that counts (the most important first)
  -- (15.10., the super saving mode) the recommended spells with their price; the rest is your choice
  if s and s.k == "train" and s.learns and #s.learns > 0 then
    local names, sum = {}, 0
    for k, e in ipairs(s.learns) do
      sum = sum + (e[7] or 0)
      if k <= 4 then names[#names + 1] = (SpellName(e[1]) or e[5]) .. (e[6] > 1 and (" " .. e[6]) or "") end
    end
    local more = #s.learns - #names
    local line = L["Recommended: "] .. table.concat(names, ", ") .. (more > 0 and (L[" and "] .. more .. L[" more"]) or "")
    if sum > 0 then line = line .. " (" .. MoneyText(sum) .. ")" end
    if (s.optional or 0) > 0 then line = line .. (L["; %d more spells are your choice (saving for riding)"]):format(s.optional) end
    out[#out + 1] = { line, "accent" }
  end
  if s and Kind(s) == "do" and InLog(s.q) then
    local _, d = NearestObjective(s.q)
    -- (22.10., Daniel: "the green can go, the arrow leads me there") only without the window's station
    if d and d < IN_AREA and not ns.LvdWin then out[#out + 1] = { L["You are there: the mobs and objects are around you"], "good" } end
  end
  if s and WALK[s.k] then
    -- the planned level when this step begins: the one noted with the step before (el is after a step)
    local plan
    for j = cur - 1, 1, -1 do if STEPS[j] and STEPS[j].el then plan = STEPS[j].el break end end
    -- (0.1.4, Daniel 09.10.: 61 % behind on the way to a turn-in, gone after it) finished quests in the log
    -- count as earned: the plan has their experience at the turn-in already
    local behind = plan and (plan - PlayerFrac() - BankedFrac()) or 0
    -- (Daniel 09.10.) always for classes that fight while they walk on (hunter, warlock: pet and damage
    -- over time); for the others only when they are behind the plan, else it costs more than it brings
    local _, cls = UnitClass("player")
    -- early levels are short: a few kills more or less are not "behind" yet
    -- (0.1.6 playtest 1, Daniel 10.10.: "63 % behind" at level 2) nothing below level 6: a start-area level
    -- takes a few minutes, the next turn-ins close such a gap by themselves (the plan counts the kills of a
    -- quest before you have made them); 40 % from level 6, 15 % from level 10 as before
    if Level() >= 6 and behind >= (Level() < 10 and 0.4 or 0.15) then
      out[#out + 1] = { (L["You are %d%% of a level behind the plan: kill the mobs on your way"]):format(math.floor(behind * 100 + 0.5)), "warning" }
    elseif cls ~= "MAGE" and cls ~= "PRIEST" and not ns.LvdWin then
      -- (Daniel 09.10.) melee classes and druids in bear or cat form fight while they walk on, too
      out[#out + 1] = { L["Kill the mobs on your way"], "textHint" }
    end
  end
  -- (0.1.6 playtest 1) buys that wait for the money; with the money and a vendor of it right here: now
  for i, info in pairs(db and db.buyLater or {}) do
    if CantAfford(i) then
      out[#out + 1] = { T.buyLater:format(info.n or (L["item "] .. i), MoneyText(BUY_PRICE[i])), "accent" }
    else
      local a = API()
      for _, v in ipairs(a and a.DistanceTo and Sellers(i) or {}) do
        local ok, d = pcall(a.DistanceTo, v.m, v.x / 100, v.y / 100)
        if ok and type(d) == "number" and Usable(d) and d < NEAR.npc then
          out[#out + 1] = { T.buyNear:format(v.n, info.n or (L["item "] .. i)), "good" }
          break
        end
      end
    end
  end
  local an, ao = AlongHere(s)
  -- (Daniel 12.10.: "'do it along here' gets lost, it is so small") with the window's station it stands there
  if an and not ns.LvdWin then out[#out + 1] = { (L["Do along here: %s (%s)"]):format(an, table.concat(ao, ", ")), "accent" } end
  -- (0.1.4, Daniel 09.10.: level 4 next to his trainer) new skills come at level 2 and every 2 levels;
  -- standing near your class trainer with skills to learn: say so, whatever the route's next step is
  local t = not ns.StopAhead("train") and NearTrainer()
  if t then out[#out + 1] = { (L["Your trainer %s is right here: learn your new skills"]):format(t.n or "?"), "good" } end
  local v = not ns.StopAhead("sell") and NearVendor()
  if v then
    local t = (L["Vendor nearby: %s, sell what you do not need"]):format(v.n or "?")
    if IsHunter() and AmmoCount() < 400 and v.ammo then t = t .. L[", buy ammunition"] end
    out[#out + 1] = { t, "accent" }
  end
  if db and db.camp ~= false and CanCamp() and not (UnitAffectingCombat and UnitAffectingCombat("player")) and HasCampMaterial()
      and Now() - math.max(campAt, sessionStart) >= (campAt == 0 and 60 or CAMP_EVERY) and not (IsResting and IsResting()) then
    out[#out + 1] = { L["Light a campfire for the camp bonuses (optional, /lvd camp off)"], "accent" }
  end
  for _, d in ipairs(ROUTE.withDungeons and {} or ROUTE.dungeons or {}) do -- (12.10.) planned in: no offer
    local lv = Level()
    if db and lv >= d.lo and lv <= d.lo + 6 and not (db.dSkip and db.dSkip[d.id]) and not (db.dTaken and db.dTaken[d.id]) then
      out[#out + 1] = { (L["Dungeon %s fits your level (%d quests): /lvd dungeon to plan it, /lvd dungeon no to skip"]):format(ns.DgName(d.id, d.n), #d.quests), "accent" }
      break
    end
  end
  if ns.SleepingBagHint() then
    out[#out + 1] = { L["Lie in your sleeping bag for 3 minutes: +3 % XP for 2 hours (eat and drink meanwhile; /lvd bag off)"], "accent" }
  end
  local left = WellFedLeft()
  if left then wasFed = true end
  if wasFed and (not left or left < 60) then
    out[#out + 1] = { left and L["Your food buff runs out: eat again"] or L["Your food buff ran out: eat again"], "warning" }
  end
  return out
end

ns.LeveldonHints = function() return Hints(STEPS[cur]) end -- (tests)

-- (15.10., Daniel's mage Zip: "Book Return is an elite quest, hard alone if nobody helps") a bonus chain with /lvd
-- solo on ends before its first group or escort quest (what follows needs it); without solo the steps say
-- "(group quest)"
function ns.SoloChain(chain)
  if not (db and db.solo) then return chain end
  local out = {}
  for _, c in ipairs(chain) do
    if c.grp or c.esc then break end
    out[#out + 1] = c
  end
  return out
end

-- (0.1.3, Daniel 09.10.) a looted item starts a quest with a chain behind it that the route left out
-- (a lucky drop): the chain goes in right after the current step
local function PlanBonus(root, label)
  db.bonusPlans = db.bonusPlans or {}
  for _, b in ipairs(db.bonusPlans) do if b.q == root then return false end end
  local at = 1
  for j = cur, 1, -1 do if STEPS[j] and STEPS[j]._i then at = STEPS[j]._i break end end
  table.insert(db.bonusPlans, { q = root, at = at })
  local here, old, at = STEPS[cur], STEPS, cur
  Compose()
  cur = ns.RefindCur(here, old, at)
  print((L["|cff3fa9f5Level|rdon: \"%s\" is in your route now, along the way."]):format(label or "?"))
  return true
end

-- (0.1.4, Daniel 09.10.: the stolen books quest was open and ignored) a quest of a bonus chain already in
-- the log (accepted by Questdon's auto-accept before the route knew of it): its chain goes in, too
local function CheckLogChains()
  if not (ROUTE.bonus and db) then return end
  for root, chain in pairs(ROUTE.bonus) do
    for _, st in ipairs(chain) do
      if st.q and InLog(st.q) then
        if PlanBonus(root, st.n) then Update(false) end
        break
      end
    end
  end
end
ns.CheckLogChains = CheckLogChains

local function CheckStarters()
  if not (ROUTE.bonus and C_Container and C_Container.GetContainerItemQuestInfo and db) then return end
  for bag = 0, 4 do
    for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
      local q = C_Container.GetContainerItemQuestInfo(bag, slot)
      local qid = q and tonumber(q.questID)
      if qid and ROUTE.bonus[qid] and not q.isActive and not QuestDone(qid) then
        db.bonusPlans = db.bonusPlans or {}
        local known = false
        for _, b in ipairs(db.bonusPlans) do if b.q == qid then known = true end end
        if not known then
          local at = 1
          for j = cur, 1, -1 do if STEPS[j] and STEPS[j]._i then at = STEPS[j]._i break end end
          table.insert(db.bonusPlans, { q = qid, at = at })
          local here, old, at = STEPS[cur], STEPS, cur
          Compose()
          cur = ns.RefindCur(here, old, at)
          -- (12.10., Daniel in Northshire: "after the book dropped Leveldon sent me to the Brotherhood, I still had
          -- wolves to kill") the book's accept comes here, before the step you are on (it takes a click); the
          -- route goes on from that step afterwards instead of jumping past it
          for j = cur + 1, #STEPS do
            if STEPS[j].q == qid and STEPS[j].k == "accept" then table.insert(STEPS, cur, table.remove(STEPS, j)) STEPS[cur]._pulled = ns._composeId break end
          end
          print((L["|cff3fa9f5Level|rdon: lucky find, \"%s\" starts a quest chain: it is in your route now."]):format(ROUTE.bonus[qid][1].n or "?"))
          Update(false)
        end
      end
    end
  end
end

-- (0.1.2) an item a later quest of the route needs, looted before you have that quest: keep it
local keptSaid = {}
local function CheckKeep(msg)
  -- only your own loot ("You receive loot: ..."; the text before %s of the game's own string)
  local pre = type(LOOT_ITEM_SELF) == "string" and LOOT_ITEM_SELF:match("^(.-)%%s") or nil
  if pre and pre ~= "" and tostring(msg or ""):sub(1, #pre) ~= pre then return end
  local id = tonumber(tostring(msg or ""):match("item:(%d+)"))
  local k = id and ROUTE.keep and ROUTE.keep[id]
  if not k or keptSaid[id] or QuestDone(k.q) or InLog(k.q) then return end
  keptSaid[id] = true
  local link = tostring(msg):match("(|c%x+|Hitem:[^|]+|h%[[^%]]+%]|h|r)") or (L["item "] .. id)
  print((L["|cff3fa9f5Level|rdon: keep %s, the route needs it later for \"%s\" (bank it if your bags are full)."]):format(link, k.n or "?"))
end
ns.CheckKeep = CheckKeep -- (tests)

-- (12.10., Daniel: "quests later on that need items from earlier areas: those should be kept") besides the line
-- when you loot it: the item's tooltip says it, and a vendor window lists what in your bags the route still needs
do
  local function KeepFor(id)
    local k = id and ROUTE.keep and ROUTE.keep[id]
    -- (21.10.) not for a quest you skipped by hand, left out or outgrown, or Questdon says you cannot get: nobody
    -- needs the item then (Bags.lua Needed: the outgrown ones)
    if k and not QuestDone(k.q) and not blocked[k.q] and not (db and db.skipQ and db.skipQ[k.q])
        and not (db and db.skipAcc and db.skipAcc[k.q] and not InLog(k.q)) and (not ns.LvdBags or ns.LvdBags.Needed(k.q)) then
      return k
    end
  end
  ns.KeepFor = KeepFor -- (tests)
  local function BagItems()
    local out = {}
    local C = C_Container
    local slots = (C and C.GetContainerNumSlots) or GetContainerNumSlots
    local idOf = (C and C.GetContainerItemID) or GetContainerItemID
    local linkOf = (C and C.GetContainerItemLink) or GetContainerItemLink
    if not (slots and idOf) then return out end
    for bag = 0, 4 do
      for slot = 1, (tonumber(slots(bag)) or 0) do
        local id = idOf(bag, slot)
        if id and not out[id] then out[id] = linkOf and linkOf(bag, slot) or (L["item "] .. id) end
      end
    end
    return out
  end
  function ns.KeepAtMerchant()
    local list = {}
    for id, link in pairs(BagItems()) do
      local k = KeepFor(id)
      if k then list[#list + 1] = ("%s (%s)"):format(link, k.n or "?") end
    end
    if #list == 0 then return nil end
    table.sort(list)
    local text = (L["|cff3fa9f5Level|rdon: do not sell %s: the route needs it later."]):format(table.concat(list, ", ", 1, math.min(#list, 5)))
    print(text)
    return text
  end
  local function OnItemTooltip(tt, data)
    local id = data and data.id
    if not id and tt and tt.GetItem then local _, link = tt:GetItem() id = link and tonumber(link:match("item:(%d+)")) end
    local k = KeepFor(id)
    if k and tt and tt.AddLine then tt:AddLine((L["Leveldon: needed later for \"%s\""]):format(k.n or "?"), 0.25, 0.66, 0.96, true) end
  end
  ns.KeepTooltip = OnItemTooltip -- (tests)
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, function(tt, data) pcall(OnItemTooltip, tt, data) end)
  elseif GameTooltip and GameTooltip.HookScript then
    pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", function(tt) pcall(OnItemTooltip, tt, nil) end)
  end
end

local function BagCheck()
  local lines = {}
  if not CanCamp() then
    if IsHunter() and AmmoCount() < 300 then print((L["|cff3fa9f5Level|rdon: before you go: only %d arrows or bullets."]):format(AmmoCount())) end
    return
  end
  if not HasCampMaterial() then lines[#lines + 1] = L["no campfire material (Basic Campfire Kit, or Simple Wood and Flint and Tinder)"] end
  local f = FoodCount()
  if f and f < 10 then lines[#lines + 1] = (L["only %d food and drink in your bags"]):format(f) end
  if IsHunter() and AmmoCount() < 300 then lines[#lines + 1] = (L["only %d arrows or bullets"]):format(AmmoCount()) end
  if #lines > 0 then print(L["|cff3fa9f5Level|rdon: before you go: "] .. table.concat(lines, "; ") .. ".") end
end


---------------------------------------------------------------------------
-- (0.1.3, Daniel 09.10.) Travel times measured in the game, for the route
-- builder (its boat, zeppelin and portal times are estimates).
--   Links (ROUTE.links): near one end of a link (60 yards) Leveldon notes
--   when you arrived and when you left; reaching the other end within 30
--   minutes logs the ride (left -> arrived) and the wait (arrived -> left).
--   Flights: from taking off (UnitOnTaxi) to landing, with both places.
-- Kept account-wide in LeveldonDB.travel (at most 300), /lvd export shows
-- them as text to copy (format LDX1, only numbers and map IDs, no names).
---------------------------------------------------------------------------
local TravelTick, ShowExport
do
local TRAVEL_R = 60
local dock        -- { i = link, side = 1/2, arrived = t, left = t }
local taxiFrom    -- { m, x, y, t }

local function PlayerPos()
  local m = Map()
  if not (m and C_Map and C_Map.GetPlayerMapPosition) then return nil end
  local p = C_Map.GetPlayerMapPosition(m, "player")
  if not p then return nil end
  local x, y = p:GetXY()
  return m, x * 100, y * 100
end

local function LogTravel(entry)
  LeveldonDB = LeveldonDB or {}
  LeveldonDB.travel = LeveldonDB.travel or {}
  local t = LeveldonDB.travel
  t[#t + 1] = entry
  while #t > 300 do table.remove(t, 1) end
end

function TravelTick()
  local now = Now()
  -- flights
  local onTaxi = UnitOnTaxi and UnitOnTaxi("player")
  if onTaxi and not taxiFrom then
    local m, x, y = PlayerPos()
    taxiFrom = { m = m, x = x, y = y, t = now }
  elseif not onTaxi and taxiFrom then
    local m, x, y = PlayerPos()
    local s = now - taxiFrom.t
    if m and taxiFrom.m and s > 10 then
      LogTravel({ k = "fly", am = taxiFrom.m, ax = taxiFrom.x, ay = taxiFrom.y, bm = m, bx = x, by = y, s = math.floor(s + 0.5), d = time() })
    end
    taxiFrom = nil
  end
  if onTaxi then return end
  -- boats, zeppelins, tram, portals, skyships
  local a = API()
  if not (a and a.DistanceTo) then return end
  local here = Map()
  for i, lk in ipairs(ROUTE.links or {}) do   -- (15.10., review round 1: "L" hid the texts, the line threw)
    for side = 1, 2 do -- (23.10.) was ipairs({ lk.a, lk.b }): a table per link every 2 s
      local e = side == 1 and lk.a or lk.b
      if e and e.m == here then
        local d = a.DistanceTo(e.m, e.x / 100, e.y / 100)
        if type(d) == "number" and d < TRAVEL_R then
          if dock and dock.i == i and dock.side ~= side then
            if now - dock.left < 1800 then
              LogTravel({ k = lk.k, link = i, from = dock.side, s = math.floor(now - dock.left + 0.5),
                w = math.floor(dock.left - dock.arrived + 0.5), d = time() })
              print((L["|cff3fa9f5Level|rdon: %s took %d s (waited %d s), noted for /lvd export."]):format(L[lk.k], now - dock.left, dock.left - dock.arrived))
            end
            dock = { i = i, side = side, arrived = now, left = now }
          elseif dock and dock.i == i and dock.side == side then
            dock.left = now
          else
            dock = { i = i, side = side, arrived = now, left = now }
          end
          return
        end
      end
    end
  end
end

local exportFrame
local function ExportText()
  local lines = { "LDX1 Leveldon travel times", ("route %s"):format(ROUTE.race or "?") }
  for _, e in ipairs(LeveldonDB and LeveldonDB.travel or {}) do
    if e.k == "fly" then
      lines[#lines + 1] = ("F %d %.1f %.1f %d %.1f %.1f %d"):format(e.am or 0, e.ax or 0, e.ay or 0, e.bm or 0, e.bx or 0, e.by or 0, e.s or 0)
    else
      local L = ROUTE.links and ROUTE.links[e.link]
      local A, B = L and L.a, L and L.b
      if e.from == 2 then A, B = B, A end
      lines[#lines + 1] = ("T %s %d %.1f %.1f %d %.1f %.1f %d %d"):format(e.k, A and A.m or 0, A and A.x or 0, A and A.y or 0,
        B and B.m or 0, B and B.x or 0, B and B.y or 0, e.s or 0, e.w or 0)
    end
  end
  -- (0.1.6 playtest 1) NPC places found indoors (1) or outdoors (0), for the route builder's walking ways
  local keys = {}
  for k in pairs(LeveldonDB and LeveldonDB.indoors or {}) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local m, x, y = k:match("^(%d+):([%d%.]+):([%d%.]+)$")
    if m then lines[#lines + 1] = ("I %s %s %s %d"):format(m, x, y, LeveldonDB.indoors[k] and 1 or 0) end
  end
  -- (0.2.0 beta) your reports with what you wrote, and what other Leveldon players shared (Share.lua): pasted
  -- into a comment on CurseForge or GitHub, it reaches the route builder
  for _, r in ipairs(LeveldonDB and LeveldonDB.reports or {}) do
    lines[#lines + 1] = ("Q %s %s %d %d %s %d %s %s %s | %s"):format(r.reason or "?", tostring(r.route or "?"), r.lv or 0, r.ri or 0,
      tostring(r.k or "?"), r.q or 0, tostring(r.m or 0), tostring(r.x or 0), tostring(r.y or 0), tostring(r.text or ""):gsub("[\r\n|]", " "))
  end
  for _, l in ipairs(ns.ShareExportLines and ns.ShareExportLines() or {}) do lines[#lines + 1] = l end
  return table.concat(lines, "\n")
end
function ShowExport()
  if not exportFrame then
    local f = ns.CreateFrame("Frame", "LeveldonExport", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(460, 300)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    if f.SetBackdrop then
      f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
      f:SetBackdropColor(0.06, 0.07, 0.09, 0.95)
      f:SetBackdropBorderColor(1, 1, 1, 0.08)
    end
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 8, -6)
    title:SetText(Style.Wordmark("Level", "don") .. L["  export: Ctrl+A, Ctrl+C"])
    local close = ns.CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    local sf = ns.CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 8, -26)
    sf:SetPoint("BOTTOMRIGHT", -28, 8)
    local eb = ns.CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetFontObject(ChatFontNormal or "ChatFontNormal")
    eb:SetWidth(420)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() f:Hide() end)
    sf:SetScrollChild(eb)
    f.eb = eb
    tinsert(UISpecialFrames, "LeveldonExport")
    exportFrame = f
  end
  exportFrame.eb:SetText(ExportText())
  exportFrame:Show()
  exportFrame.eb:SetFocus()
  exportFrame.eb:HighlightText()
end
ns.LeveldonExportText = ExportText -- (tests)
end

---------------------------------------------------------------------------
-- (0.1.6, Daniel 10.10.) The profession choice in the book look of the Leveldon
-- window: a row per profession (name, a gold card when picked) and a line under
-- it (primary or secondary, what it needs, where its trainer is), at most two
-- primary ones and every secondary one, and "No professions" (all profession
-- steps left out, the choice does not come back). db.profs as before.
---------------------------------------------------------------------------
local BK = Style.BOOK or {}
-- what a profession needs when the route says nothing about it
local PROF_NEED = {
  [171] = L["herbs (Herbalism) and vials from a trade supplies vendor"],
  [164] = L["ore and stone (Mining) and a Blacksmith Hammer"],
  [333] = L["magic materials from disenchanting green items"],
  [202] = L["ore and stone (Mining) and a Blacksmith Hammer"],
  [182] = L["herbs you pick on the way"],
  [165] = L["leather (Skinning)"],
  [186] = L["a Mining Pick, ore veins on the way"],
  [393] = L["a Skinning Knife, the beasts you kill on the way"],
  [197] = L["cloth from humanoids"],
  [129] = L["cloth from humanoids, for bandages"],
  [185] = L["meat or fish, and a cooking fire"],
  [356] = L["a Fishing Pole, water on the way"],
}
-- what it needs and where the route has its trainer (the start area's first, then the route's, then the
-- picked-later ones)
local function ProfInfo(sk)
  local need, where
  for _, e in ipairs(ROUTE.early or {}) do
    if e.sk == sk and e.m and not where then where = { m = e.m, x = e.x, y = e.y, npc = e.npc } end
  end
  for _, s in ipairs(ROUTE.steps) do
    if s.sk == sk and s.k == "skillup" and s.mats and not need then need = s.mats end
    if s.sk == sk and s.k == "learn" and s.m and not where then where = { m = s.m, x = s.x, y = s.y } end
  end
  for _, o in ipairs(ROUTE.profOptions or {}) do
    if o.sk == sk then
      need = need or o.mats
      if not where and o.t then where = { m = o.t.m, x = o.t.x, y = o.t.y } end
    end
  end
  local w = where and ("%s%s %.1f, %.1f"):format(where.npc and (where.npc .. ", ") or "", MapName(where.m), where.x or 0, where.y or 0)
  return need or PROF_NEED[sk], w
end
ns.ProfInfo = ProfInfo -- (tests)
local function ProfIcon(sk)
  local sp = PROF_SPELL[sk]
  return (C_Spell and Val(C_Spell.GetSpellTexture, sp)) or Val(GetSpellTexture, sp)
end

local profsPanel, picked
local function ApplyProfs(set, none)
  db.profs = {}
  for sk in pairs(set) do db.profs[sk] = true end
  -- (15.10., review round 1) a profession you know but did not pick stays out (a skill event put it back in)
  db.profsOff = nil
  for _, list in ipairs({ PRIMARY, SECONDARY }) do
    for _, sk in ipairs(list) do
      if not set[sk] and SkillRank(sk) then db.profsOff = db.profsOff or {} db.profsOff[sk] = true end
    end
  end
  db.noProfs = none and true or nil
  local at, here, hereK, old = cur, STEPS[cur], STEPS[cur] and STEPS[cur].k, STEPS
  Compose()
  local found
  if hereK == "profs" then
    -- on to the step after the choice that was open (the start area's or Goldshire's); the start area's
    -- step is new after Compose, so it is found by its kind near the same position
    local i = IndexIn(STEPS, here)
    if i then found = i + 1 end
    if not found then
      for j = math.max(1, at - 3), math.min(#STEPS, at + 3) do if STEPS[j].k == "profs" then found = j + 1 break end end
    end
    -- (15.10., review round 3, H3: undead warlock's turn-in of 364 passed, Tainted Scroll blocked) the first of the
    -- steps after the choice in the new order, the new profession steps after the choice too
    local after = ns.RefindCur(nil, old, at + 1)
    if not found or after < found then found = after end
  else
    -- (0.1.6) chosen early (after the first quest): the route stays at its step, or the next one still in it
    found = ns.RefindCur(here, old, at)
  end
  cur = found or math.min(at, #STEPS + 1)
  if profsPanel then profsPanel:FadeOut() end
  if none then print("|cff3fa9f5Level|rdon: " .. T.profsNoneSaid) end
  Update(false)
end
ns.ApplyProfs = ApplyProfs -- (tests)

-- (0.1.6, Daniel 10.10.: "overloaded") one compact row per profession: icon, name and on the right
-- "learned 45" / "picked"; what it needs and where its trainer is only in the row's tooltip.
local function ProfRow(p, sk, kind, on, full, toggle)
  local have = SkillRank(sk)
  local value = have and T.profsKnown:format(have) or (on and T.profsPicked or "")
  local row = Style.Row(p):SetMain(true)
    :SetText(ns.PName(sk), (full and not on) and (BK.textHint or "textHint") or (BK.textPrimary or "textPrimary"))
    :SetValue(value, on and (BK.goldLight or "good") or (BK.textHint or "textHint"))
    :SetActive(on and true or false)
    :SetOnClick(toggle)
    :SetTooltip(function()
      local need, where = ProfInfo(sk)
      local lines = { kind }
      if need then lines[#lines + 1] = T.profsNeeds:format(need) end
      lines[#lines + 1] = where and T.profsTrainer:format(where) or T.profsTrainerNone
      return ns.PName(sk), lines, (full and not on) and T.profsFullHint or T.profsClickHint
    end)
  local icon = ProfIcon(sk)
  if icon then row:SetIcon(icon, false, true) end
  return row
end

-- (18.10.) a book card button: no professions on the left, done on the right, a gap between them
do
local profsBtnBar
local function ProfsButton(parent, text, fill, textColor, fn)
  local b = ns.CreateFrame("Button", nil, parent)
  local function Tex(layer, c, a)
    local t = b:CreateTexture(nil, layer)
    t:SetColorTexture(c[1], c[2], c[3], a or 1)
    return t
  end
  local edge = BK.gold or { 0.86, 0.71, 0.42 }
  b.border = Tex("BACKGROUND", BK.goldDark or edge)
  b.border:SetAllPoints(b)
  b.bg = Tex("BORDER", fill)
  b.bg:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
  b.bg:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
  b.hover = Tex("ARTWORK", { 1, 1, 1 }, 0.07)
  b.hover:SetAllPoints(b.bg)
  b.hover:Hide()
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.text:SetPoint("LEFT", b, "LEFT", 6, 0)
  b.text:SetPoint("RIGHT", b, "RIGHT", -6, 0)
  b.text:SetJustifyH("CENTER")
  if b.text.SetWordWrap then b.text:SetWordWrap(true) end
  b.text:SetText(text)
  b.text:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
  b._onClick = fn
  b:SetScript("OnClick", function(self) if self._onClick then self._onClick(self) end end)
  b:SetScript("OnEnter", function(self)
    self.hover:Show()
    self.border:SetColorTexture(edge[1], edge[2], edge[3], 1)
  end)
  b:SetScript("OnLeave", function(self)
    self.hover:Hide()
    local d = BK.goldDark or edge
    self.border:SetColorTexture(d[1], d[2], d[3], 1)
  end)
  return b
end
ns.ProfsBar = function()
  if not profsBtnBar then
    local f = ns.CreateFrame("Frame", nil, UIParent)
    local none = ProfsButton(f, T.profsNone, BK.cardLow or { 0.11, 0.13, 0.28 }, BK.textSecondary or { 0.8, 0.76, 0.68 },
      function() ApplyProfs({}, true) end)
    local done = ProfsButton(f, T.profsDone, BK.card or { 0.17, 0.21, 0.40 }, BK.goldLight or { 0.97, 0.87, 0.60 },
      function() ApplyProfs(picked, false) end)
    none:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    none:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 0)
    done:SetPoint("TOPLEFT", f, "TOP", 6, 0)
    done:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    f.none, f.done = none, done
    profsBtnBar = f
  end
  return profsBtnBar
end
ns.ProfsButtons = function() local f = ns.ProfsBar() return f.done, f.none end -- (tests)
end

local function ProfsRefresh()
  local p = profsPanel
  p:ClearRows()
  -- (0.1.6, Daniel 10.10.: "check which are learned already") one line on top
  local have = {}
  for _, list in ipairs({ PRIMARY, SECONDARY }) do
    for _, sk in ipairs(list) do
      local r = SkillRank(sk)
      if r then have[#have + 1] = ("%s %d"):format(ns.PName(sk), r) end
    end
  end
  Style.Row(p):SetText(#have > 0 and T.profsHave:format(table.concat(have, ", ")) or T.profsHaveNone, BK.textSecondary or "textSecondary")
  local n = 0
  for _, sk in ipairs(PRIMARY) do if picked[sk] then n = n + 1 end end
  Style.Header(p, T.profsPrimary:format(n))
  for _, sk in ipairs(PRIMARY) do
    ProfRow(p, sk, T.profsKindPrimary, picked[sk], n >= 2, function()
      if picked[sk] then picked[sk] = nil elseif n < 2 then picked[sk] = true end
      ProfsRefresh()
    end)
  end
  Style.Header(p, T.profsSecondary):SetGapBefore(6)
  for _, sk in ipairs(SECONDARY) do
    ProfRow(p, sk, T.profsKindSecondary, picked[sk], false, function() picked[sk] = not picked[sk] or nil ProfsRefresh() end)
  end
  Style.Row(p):SetText(T.profsFoot, BK.textHint or "textHint"):SetGapBefore(4)
  -- (18.10., Daniel: "easy to click the wrong one") the two ways out as two buttons side by side at the bottom
  Style.Content(p, ns.ProfsBar(), 34, { gapBefore = 8 })
  p:Relayout()
end
local function ShowProfs()
  if not profsPanel then
    profsPanel = Style.Panel("LeveldonProfs", UIParent, { look = "book", media = "Interface\\AddOns\\Leveldon\\Media\\",
      title = Style.Wordmark("Level", "don") .. T.profsTitle, width = 400, close = true,
      defaultPoint = { "CENTER", "CENTER", 0, 80 },
      -- (18.10., Daniel: it opened behind the options window, which is HIGH) a choice window on top
      strata = "DIALOG" })
    -- (0.1.6) a choice window: the route window behind it must not shine through
    if profsPanel.SetBackgroundAlpha then profsPanel:SetBackgroundAlpha(0.97, true) end
  end
  picked = {}
  if db and db.profs then for sk in pairs(db.profs) do picked[sk] = true end
  else for _, sk in ipairs(PRIMARY) do if SkillRank(sk) then picked[sk] = true end end
    for _, sk in ipairs(SECONDARY) do picked[sk] = true end end
  ProfsRefresh()
  profsPanel:FadeIn()
end
ns.ShowProfs = ShowProfs

-- (0.1.6, Daniel 10.10.: "show the choice early") right after the character's first quest is accepted
-- (once per character, out of combat, a moment later), not only at the route's choice step; closed
-- without a choice, that step still asks
local profsEarlyWaiting = false
local function RouteHasProfs()
  for _, s in ipairs(ROUTE.steps) do if s.k == "profs" or s.sk then return true end end
  return #(ROUTE.early or {}) > 0 or #(ROUTE.profOptions or {}) > 0
end
local function ShowProfsEarly()
  profsEarlyWaiting = false
  if not db or db.profs ~= nil or (profsPanel and profsPanel:IsShown()) then return end
  if InCombat() then profsEarlyWaiting = true return end
  ShowProfs()
end
-- (0.1.6, Daniel 10.10.: "check which professions are learned; if a primary or secondary one is missing,
-- ask right at the start") At login, for a character that has started already (installed later, or the
-- choice was closed): nothing chosen yet and a free primary slot or a missing secondary profession -> the
-- choice comes now (out of combat). Everything learned already -> taken as the choice, no window.
-- A brand-new character (level 1, nothing accepted yet) still gets it after the first quest.
local function Started()
  if db and db.firstAccept then return true end
  if Level() > 1 then return true end
  local n = GetNumQuestLogEntries and select(1, GetNumQuestLogEntries()) or 0
  return (tonumber(n) or 0) > 0
end
local profsStartTries = 0
local function CheckProfsAtStart()
  if not db or db.profs ~= nil or db.noProfs or not RouteHasProfs() or not Started() then return end
  -- the skill lines may come a moment after login
  if GetNumSkillLines and (tonumber(GetNumSkillLines()) or 0) == 0 and profsStartTries < 3 then
    profsStartTries = profsStartTries + 1
    ns.After(3, CheckProfsAtStart)
    return
  end
  local primaries, missing, set = 0, false, {}
  for _, sk in ipairs(PRIMARY) do if SkillRank(sk) then primaries = primaries + 1 set[sk] = true end end
  for _, sk in ipairs(SECONDARY) do if SkillRank(sk) then set[sk] = true else missing = true end end
  db.firstAccept = true -- the after-first-quest window is not needed any more
  if primaries < 2 or missing then
    ShowProfsEarly()
  else
    local names = {}
    for _, list in ipairs({ PRIMARY, SECONDARY }) do for _, sk in ipairs(list) do if set[sk] then names[#names + 1] = ns.PName(sk) end end end
    ApplyProfs(set, false)
    print("|cff3fa9f5Level|rdon: " .. T.profsFound:format(table.concat(names, ", ")))
  end
end
ns.CheckProfsAtStart = CheckProfsAtStart -- (tests)

-- (13.10., Daniel's hunter Don picked "no professions", then learned Cooking, Fishing, First Aid and Skinning: the
-- Camping 101 steps were not in his route) a profession you learn later comes into the route by itself
function ns.CheckLearnedProfs()
  if not db or (db.profs == nil and not db.noProfs) then return false end
  local set, added = {}, {}
  for sk in pairs(db.profs or {}) do set[sk] = true end
  for _, list in ipairs({ PRIMARY, SECONDARY }) do
    for _, sk in ipairs(list) do
      if SkillRank(sk) and not set[sk] and not (db.profsOff and db.profsOff[sk]) then set[sk] = true added[#added + 1] = ns.PName(sk) end
    end
  end
  if #added == 0 then return false end
  ApplyProfs(set, false)
  print((L["|cff3fa9f5Level|rdon: you learned %s: its steps are in your route now."]):format(table.concat(added, ", ")))
  return true
end

local function OnFirstAccept()
  if not db or db.firstAccept then return end
  db.firstAccept = true
  if db.profs ~= nil or not RouteHasProfs() then return end
  ns.After(2, ShowProfsEarly)
end

---------------------------------------------------------------------------
-- (0.1.6, Daniel 10.10.) Blizzard's quest tracker hidden (db.hideTracker, on by
-- default): made invisible and click-through (alpha 0, mouse off), no hooks; a
-- light check every half second sets it again when the game shows it again.
-- Never in combat: it waits for PLAYER_REGEN_ENABLED. In the quest log a small
-- button of ours switches it ("Quest tracker: show/hide").
---------------------------------------------------------------------------
local TRACKERS = { "ObjectiveTrackerFrame", "QuestWatchFrame", "WatchFrame" }
local trackerHidden, trackerMouse -- the frame we made invisible, whether its mouse was on
local trackerPending = false
local function TrackerFrame()
  for _, n in ipairs(TRACKERS) do
    local f = rawget(_G, n)
    if type(f) == "table" and type(f.SetAlpha) == "function" then return f end
  end
end
local function ApplyTracker()
  local f = TrackerFrame()
  if not f then return end
  if InCombat() then trackerPending = true return end
  trackerPending = false
  if db and db.hideTracker ~= false then
    local a = Val(f.GetAlpha, f)
    if trackerHidden ~= f or (type(a) == "number" and a > 0) then
      if trackerHidden ~= f then trackerMouse = Val(f.IsMouseEnabled, f) end
      pcall(f.SetAlpha, f, 0)
      if type(f.EnableMouse) == "function" then pcall(f.EnableMouse, f, false) end
      trackerHidden = f
    end
  elseif trackerHidden then
    local h = trackerHidden
    trackerHidden = nil
    pcall(h.SetAlpha, h, 1)
    if type(h.EnableMouse) == "function" then pcall(h.EnableMouse, h, trackerMouse ~= false) end
  end
end
ns.ApplyTracker = ApplyTracker -- (tests)
ns.TrackerHidden = function() return trackerHidden ~= nil end -- (tests)

local QUESTLOG_HOSTS = { "QuestMapFrame", "QuestLogFrame", "WorldMapFrame" }
local logButton
local function LogButtonText()
  return (db and db.hideTracker ~= false) and T.trackerButtonShow or T.trackerButtonHide
end
local function RefreshLogButton()
  if not logButton then return end
  logButton.label:SetText(LogButtonText())
  local ok, w = pcall(logButton.label.GetStringWidth, logButton.label)
  if ok and type(w) == "number" and Usable(w) and w > 0 then logButton:SetWidth(math.floor(w + 20)) end
end
local function ToggleTracker()
  if not db then return end
  db.hideTracker = db.hideTracker == false
  ApplyTracker()
  RefreshLogButton()
  print("|cff3fa9f5Level|rdon: " .. (db.hideTracker and T.trackerOn or T.trackerOff) .. (InCombat() and L[" (after the fight)"] or "") .. ".")
end
-- Our button below the quest log (the map's quest list in the modern client, else the classic quest log),
-- a child of it: it shows and hides with it, its OnShow brings the label up to date.
local function MakeLogButton()
  local host, rank
  for i, n in ipairs(QUESTLOG_HOSTS) do
    local f = rawget(_G, n)
    if type(f) == "table" and type(f.IsShown) == "function" then host, rank = f, i break end
  end
  if not host then return logButton end
  if logButton then
    -- a better place than the first one found (the map's quest list loaded later)
    if rank < logButton._rank then
      pcall(logButton.SetParent, logButton, host)
      logButton:ClearAllPoints()
      logButton:SetPoint("TOPRIGHT", host, "BOTTOMRIGHT", 0, -2)
      logButton._host, logButton._rank = host, rank
    end
    return logButton
  end
  local b = ns.CreateFrame("Button", "LeveldonTrackerButton", host, BackdropTemplateMixin and "BackdropTemplate" or nil)
  b:SetSize(150, 20)
  b:SetPoint("TOPRIGHT", host, "BOTTOMRIGHT", 0, -2)
  if b.SetBackdrop then
    pcall(b.SetBackdrop, b, { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    local bg, gold = BK.header or { 0.07, 0.08, 0.17 }, BK.gold or { 0.86, 0.71, 0.42 }
    pcall(b.SetBackdropColor, b, bg[1], bg[2], bg[3], 0.95)
    pcall(b.SetBackdropBorderColor, b, gold[1], gold[2], gold[3], 0.8)
  end
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
  local tc = BK.textPrimary or { 1, 1, 1 }
  pcall(b.label.SetTextColor, b.label, tc[1], tc[2], tc[3], 1)
  b:SetScript("OnClick", ToggleTracker)
  b:SetScript("OnShow", RefreshLogButton)
  b:SetScript("OnEnter", function(self) Style.Tooltip(self, Style.Wordmark("Level", "don"), { T.trackerTip }, "/lvd tracker") end)
  b:SetScript("OnLeave", function(self) Style.HideTooltip(self) end)
  b._host, b._rank = host, rank
  logButton = b
  RefreshLogButton()
  return b
end
ns.MakeLogButton = MakeLogButton -- (tests)

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function Get(key) return db and db.panel and db.panel[key] end
local function Set(key, value) if db then db.panel = db.panel or {} db.panel[key] = value end end

-- (0.1.4, Daniel 09.10.: "tidier, like Questdon's quest book") the window: the chapter as the section,
-- the step as a gold card with its icon, where it is and how far, at most three hints (the important
-- first), the next three steps with their icons, the chapter's progress as a gold bar.
local KIND_ICON = {
  accept = "Interface\\GossipFrame\\AvailableQuestIcon", turnin = "Interface\\GossipFrame\\ActiveQuestIcon",
  ["do"] = "Interface\\Icons\\INV_Sword_04", grind = "Interface\\Icons\\Ability_DualWield",
  train = "Interface\\Icons\\INV_Misc_Book_11", travel = "Interface\\Icons\\Ability_Rogue_Sprint",
  fp = "Interface\\Icons\\INV_Misc_Map_01", bind = "Interface\\Icons\\INV_Misc_Rune_01",
  hearth = "Interface\\Icons\\INV_Misc_Rune_01", profs = "Interface\\Icons\\INV_Misc_Note_01",
  die = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
  learn = "Interface\\Icons\\INV_Misc_Note_01", skillup = "Interface\\Icons\\INV_Misc_Note_01",
  buy = "Interface\\Icons\\INV_Misc_Coin_01", sell = "Interface\\Icons\\INV_Misc_Coin_02",
  use = "Interface\\Icons\\INV_Misc_Book_09", farm = "Interface\\Icons\\INV_Sword_04",
  dungeon = "Interface\\Icons\\INV_Misc_Key_03", chapter = "Interface\\Icons\\INV_Misc_Book_09",
}
local HINT_ORDER = { warning = 1, good = 2, accent = 3, textHint = 4 }
local B = Style.BOOK or {}
local function ChapterProgress()
  local first, last
  for j = math.min(cur, #STEPS), 1, -1 do if STEPS[j].k == "chapter" then first = j break end end
  for j = math.min(cur, #STEPS) + 1, #STEPS do if STEPS[j].k == "chapter" then last = j - 1 break end end
  first, last = first or 1, last or #STEPS
  if last <= first then return 0 end
  return math.max(0, math.min(1, (cur - first) / (last - first)))
end

-- (21.10., Daniel: "the step list scrollable, in two parts") what StepList.lua (ns.LvdList) reads of the route: the
-- helpers Refresh uses, handed over once (a do block: Lua allows 200 locals in this file)
do
  ns.LvdListCtx = {
    state = function() return STEPS, cur end,
    done = StepDone, outgrown = Outgrown, kind = Kind, text = StepText, place = Place,
    icon = KIND_ICON, level = Level, inLog = InLog,
    chapterName = function(n) return ns.ChName(n) end,
    buyWaits = function(j) return ns.BuyWaits ~= nil and ns.BuyWaits(j) end,
    open = function(n) ns.OpenQuest(n) end,
  }
end

-- (0.1.8, Daniel 12.10.: "the chapter path with the compass in the current station and the speedrun line")
-- Window.lua (ns.LvdWin) draws the new parts; without it the window is built as before.
function ns.LvdObjList(q)
  local out = {}
  local ok, objs = pcall(C_QuestLog and C_QuestLog.GetQuestObjectives or function() end, q)
  for _, o in ipairs(ok and type(objs) == "table" and objs or {}) do
    if type(o) == "table" and o.text and o.text ~= "" then
      out[#out + 1] = { text = o.text, done = o.finished and true or false, have = tonumber(o.numFulfilled), need = tonumber(o.numRequired) }
    end
  end
  return out
end
local function Refresh()
  if not panel then return end
  if ns.LF.TickReset then ns.LF.TickReset() end -- (17.10.) any build counts as fresh for the ticker
  panel:ClearRows()
  local Win = ns.LvdWin
  if Win then Win.Begin(panel) pcall(Win.Run, panel, STEPS, cur) end
  local ch = ChapterOf(math.min(cur, #STEPS))
  if ch then
    local plan
    for j = cur - 1, 1, -1 do if STEPS[j] and STEPS[j].el then plan = STEPS[j].el break end end
    -- (22.10., Daniel: "not the steps in total but the steps in the zone") step n of the chapter's steps
    local _, c0 = ChapterOf(math.min(cur, #STEPS))
    local c1 = #STEPS
    c0 = c0 or 1
    for j = c0 + 1, #STEPS do if STEPS[j].k == "chapter" then c1 = j - 1 break end end
    if not (Win and pcall(Win.Banner, panel, ns.ChName(ch), ch.lo, ch.hi, math.max(1, math.min(cur, #STEPS) - c0), math.max(1, c1 - c0), ChapterProgress(), plan, (panel._width or 360) - 2)) then
      Style.Header(panel, (L["%s  ·  level %d to %d"]):format(ns.ChName(ch), ch.lo or 0, ch.hi or 0))
    end
    if ch._pv then
      Style.Row(panel):SetText(L["Preview: this part of the route is not tested yet."], B.textSecondary or "textSecondary")
    end
  end
  -- (Daniel 12.10.: "the done steps from before up top are too much") no stations behind you any more
  local s = STEPS[cur]
  local kind = Kind(s)
  local main = Style.Row(panel):SetMain(true):SetActive(true):SetText(StepText(s, nil, Win and true or nil), B.textPrimary or "textPrimary")
  main:SetIcon(s and KIND_ICON[kind] or KIND_ICON.chapter, false, kind ~= "accept" and kind ~= "turnin" or nil)
  -- (0.2.3) right-click: the menu with skip this step, skip this quest
  local left = s and s.k == "profs" and ShowProfs or (s and s.q and function() ns.OpenQuest(s) end) or nil
  main:SetOnClick(s and function(self, button)
    if button == "RightButton" then ns.SM.Show() elseif left then left(self, button) end
  end or nil)
  if Win then Win.Line(main, "now") pcall(Win.Now, main) end
  local m, x, y = Place(cur)
  if s and s.k == "die" and s.gm and s.gx and not ns.DieWalkFirst(s) then m, x, y = s.gm, s.gx, s.gy end -- (12.10.) the spirit healer
  -- (0.1.4) a do step: the place the arrow points at (the nearest open one), not the planned one
  if s and kind == "do" and InLog(s.q) then
    local p = NearestObjective(s.q)
    if p then m, x, y = p.mapID, p.x * 100, p.y * 100 end
  end
  local stationDone = false
  if Win and s then
    local where = m and ("%s  ·  %.1f, %.1f"):format(MapName(m), x, y) or nil
    local objs = (s.q and InLog(s.q) and (kind == "do" or kind == "turnin")) and ns.LvdObjList(s.q) or {}
    -- (Daniel 12.10.) a quest to do along here: in the station, as large as the step's own objectives
    local along
    -- (22.10., Daniel: "turning in at the hub, 'along here' kill the mobs is disturbing: first turn in, accept, sell,
    -- then off to the quests") the quests along here only while the step itself is out doing quests
    if (kind == "do" or s.k == "grind") and AlongHere(s) and ns._alongQ then
      along = { title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(ns._alongQ) or (L["Quest "] .. ns._alongQ),
        objs = ns.LvdObjList(ns._alongQ) }
      -- (21.10.) and the other quests with open objectives right here, below it
      for _, q2 in ipairs(ns._alongMore or {}) do
        along.more = along.more or {}
        along.more[#along.more + 1] = { title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(q2) or (L["Quest "] .. q2),
          objs = ns.LvdObjList(q2) }
      end
    end
    stationDone = pcall(Win.Station, panel, objs, where, (panel._width or 360) - 2, along)
  end
  if s and m and not stationDone then
    local where = ("%s  ·  %.1f, %.1f"):format(MapName(m), x, y)
    local a = API()
    local d = a and a.DistanceTo and a.DistanceTo(m, x / 100, y / 100)
    local row = Style.Row(panel):SetText(where, B.textSecondary or "textSecondary"):SetIndent(18)
    if type(d) == "number" then row:SetValue((L["%d yd"]):format(math.floor(d + 0.5)), B.goldLight or "accent") end
  end
  -- hints: the important first, three at most ("kill the mobs on your way" only when there is room)
  local hints = Hints(s)
  table.sort(hints, function(a, b) return (HINT_ORDER[a[2]] or 5) < (HINT_ORDER[b[2]] or 5) end)
  for k = 1, math.min(3, #hints) do
    local h = hints[k]
    Style.Row(panel):SetText(h[1], h[2] == "textHint" and (B.textHint or "textHint") or h[2]):SetIndent(18):SetGapBefore(k == 1 and 4 or nil)
  end
  local shown = 0
  -- (21.10., Daniel: "scrollable with a slider", "two parts") the area rows and the coming steps as one scrollable
  -- block (StepList.lua); the plain list below stays as the fallback
  local listed = false
  if Win and ns.LvdList and ns.LvdListCtx then
    local okL, did = pcall(ns.LvdList.Build, panel, ns.LvdListCtx, (panel._width or 360) - 2)
    listed = okL and did == true
  end
  -- (0.1.8) the next level the plan reaches on the way: a gold diamond on the path
  local nextLv = Level() + 1
  for j = cur + 1, listed and cur or #STEPS do
    local n = STEPS[j]
    local isCh = n.k == "chapter"
    -- (playtest 1) a buy without the money is not "next": it waits (see the hint)
    if isCh or (not StepDone(j) and not Outgrown(n) and not (n.k == "buy" and ns.BuyWaits(j))) then
      if shown == 0 and not Win then Style.Header(panel, L["Next"]) end
      local prevEl
      for k = j - 1, cur, -1 do if STEPS[k] and STEPS[k].el then prevEl = STEPS[k].el break end end
      if Win and prevEl and prevEl >= nextLv then Win.Milestone(panel, nextLv) nextLv = math.floor(prevEl) + 1 end
      local row = Style.Row(panel):SetText(isCh and (L["Chapter: "] .. ns.ChName(n)) or StepText(n, true), B.textHint or "textHint")
        :SetIcon(KIND_ICON[isCh and "chapter" or Kind(n, true)] or KIND_ICON.chapter, false, not (n.k == "accept" or n.k == "turnin") or nil)
        :SetOnClick(n.q and function() ns.OpenQuest(n) end or nil)
      if Win then Win.Line(row, "next") end
      shown = shown + 1
      if shown >= (ns.nextShown or NEXT_SHOWN) then break end -- (0.1.7) more with a taller window (Resize.lua)
    end
  end
  local foot = Style.Row(panel):SetText((L["Step %d of %d"]):format(math.min(cur, #STEPS), #STEPS), B.textHint or "textHint")
    :SetValue((L["chapter %d%%"]):format(math.floor(ChapterProgress() * 100 + 0.5)), B.gold or "textSecondary"):SetGapBefore(6)
  Style.Bar(foot, { height = 3, segments = { { key = "value", color = B.gold or "accent", value = ChapterProgress() } } })
  panel:Relayout()
  if Win then pcall(Win.Finish, panel) end
end

local arrowStep, arrowKey
-- (13.10., Daniel's hunter Don at level 10: "as a hunter the next step should always be the hunter quest, unless
-- you can turn in a quest right where you are"; "the same for the important class quests, the warlock's
-- Voidwalker for example") once you have the level of a class quest of your route (from level CLASS_MIN on: the pet,
-- the Voidwalker, the bear, the totems, the stances), it comes next with the quests that follow it: after the steps
-- at NPCs right here (within NEAR.hub of you), before everything else
ns.LF = {} -- (13.10.) ClassNow and FollowPlayer (few locals: Lua allows 200 in this file)
ns.LF.CLASS_MIN = 4
function ns.LF.HereSteps(from, to)
  local m = Map()
  local x, y = ns.PlayerXY()
  local me = m and x and { m = m, x = x, y = y }
  local k = from - 1
  while me and k + 1 < to and STEPS[k + 1] and NPC_KIND[STEPS[k + 1].k] and Within(STEPS[k + 1], me, NEAR.hub) do k = k + 1 end
  return k
end
function ns.LF.Mine(g, classID)
  for _, c in ipairs(g and g.classes or {}) do if c == classID then return true end end
  return false
end
function ns.LF.ClassNow()
  local _, _, classID = UnitClass("player")
  local a = API()
  if not (classID and a and a.GetQuest) then return false end
  local first, g1
  for j = cur, math.min(#STEPS, cur + 400) do
    local t = STEPS[j]
    -- (15.10., review round 1) not from far ahead (the human warrior's level 33 chain out of the 30 to 60 preview at
    -- level 23) and not a grey one (a druid's level 14 quest at 23, put first and dropped again)
    if t.k == "accept" and (t.el or 0) > Level() + (t._pv and 2 or 6) then break end
    if t.k == "accept" and t.q and not QuestDone(t.q) and not InLog(t.q) and not (ns._acceptSkipped and ns._acceptSkipped[t.q])
        and not Outgrown(t) then
      local g = a.GetQuest(t.q)
      local min = g and tonumber(g.minLevel)
      if min and min >= ns.LF.CLASS_MIN and min <= Level() and ns.LF.Mine(g, classID)
          and not (a.CanTakeQuest and a.CanTakeQuest(t.q) == false) then first, g1 = j, g end
    end
    if first then break end
  end
  if not first then return false end
  local at = ns.LF.HereSteps(cur, first) + 1
  if first <= at then return false end
  -- the chain: class quests taken at the same NPC and the ones that follow them, in their order
  local chain, idx = { [STEPS[first].q] = true }, {}
  for j = first, math.min(#STEPS, first + 80) do
    local t = STEPS[j]
    if t.q and not chain[t.q] and t.k == "accept" then
      local g = a.GetQuest(t.q)
      local follows = false
      for _, p in ipairs(g and g.prereqs or {}) do if chain[p] then follows = true end end
      if ns.LF.Mine(g, classID) and (follows or Within(t, STEPS[first], NEAR.hub)) then chain[t.q] = true end
    end
    if t.q and chain[t.q] and IsQuestStep(t) then idx[#idx + 1] = j end
  end
  local moved = {}
  for n = #idx, 1, -1 do table.insert(moved, 1, table.remove(STEPS, idx[n])) end
  for n, t in ipairs(moved) do table.insert(STEPS, at + n - 1, t) t._pulled = ns._composeId end   -- (review round 3)
  -- (review round 4) and kept when the steps are built again (a /reload put the class chain back at its place, the
  -- step changed): in front of the same route step
  local nextRi
  for j = at + #moved, math.min(#STEPS, at + #moved + 20) do
    local t = STEPS[j]
    if t and t._i and t._pulled ~= ns._composeId then nextRi = t._i break end
  end
  if nextRi and db then
    db.pullMoves = db.pullMoves or {}
    for _, t in ipairs(moved) do if t.q then db.pullMoves[t.q] = nextRi end end
    db.laterKey = ns.LaterKeyOf(db)
  end
  ns._classNowSaid = ns._classNowSaid or {}
  if not ns._classNowSaid[moved[1].q] then
    ns._classNowSaid[moved[1].q] = true
    print((L["|cff3fa9f5Level|rdon: level %d: \"%s\" comes next (your class quest)."]):format(tonumber(g1.minLevel) or Level(), ns.QName(moved[1]) or "?"))
  end
  if ns.RecEvent then pcall(ns.RecEvent, "C", moved[1].q, at) end
  return true
end
ns.LeveldonClassNow = ns.LF.ClassNow -- (tests)

-- (13.10., Daniel's hunter Don: 47 min on "accept Applejack Still" while he did the Jasperlode Mine and the east
-- of Elwynn himself) a step that stays for FOLLOW_SECONDS while you take or hand in quests that come later on the
-- route: the route goes on from there (a chat line says so), the steps in between count as skipped
ns.LF.SECONDS, ns.LF.QUESTS, ns.LF.since, ns.LF.seen, ns.LF.recent = 600, 2, 0, nil, {}
function ns.NoteQuestEvent(q) if q then ns.LF.recent[q] = Now() end end
function ns.LF.FollowPlayer()
  if ns.LF.seen ~= STEPS[cur] then ns.LF.seen, ns.LF.since, ns.LF.recent = STEPS[cur], Now(), {} return false end
  if Now() - ns.LF.since < ns.LF.SECONDS then return false end
  -- not while you work on the step itself (its kills, a skill, a grind): quests you pick up meanwhile are no sign
  local s0 = STEPS[cur]
  -- (15.10., review round 1) an unfinished quest's turn-in (shown as Do) too
  if s0 and ((Kind(s0) == "do" and s0.q and InLog(s0.q)) or s0.k == "grind" or s0.k == "skillup" or s0.k == "farm" or s0.k == "dungeon") then return false end
  local first, hits, seen = nil, 0, {}
  for j = cur + 1, math.min(#STEPS, cur + 120) do
    local t = STEPS[j]
    if t.q and IsQuestStep(t) and ns.LF.recent[t.q] and ns.LF.recent[t.q] >= ns.LF.since and StepDone(j) then
      first = first or j
      if not seen[t.q] then seen[t.q] = true hits = hits + 1 end
    end
  end
  if hits < ns.LF.QUESTS then return false end
  local to = first
  while STEPS[to] and StepDone(to) do to = to + 1 end
  ns._acceptSkipped = ns._acceptSkipped or {}
  -- (15.10., review round 1) a quest still in your log keeps its do and turn-in: they come right behind the step
  -- the route goes on at, not marked done behind it
  local keep = {}
  for k = cur, to - 1 do
    local t = STEPS[k]
    if not StepDone(k) then
      if t.q and (t.k == "do" or t.k == "turnin") and InLog(t.q) then
        keep[#keep + 1] = t
      elseif t.k == "bind" and ns.BindOpenHere and ns.BindOpenHere(t) then
        keep[#keep + 1] = t   -- (22.10., Daniel: "setting the hearthstone must not be skipped") in its hub: it stays
      else
        marks[t] = true
        if t.k == "accept" and t.q and not InLog(t.q) then
          ns._acceptSkipped[t.q] = true
          if db then db.skipAcc = db.skipAcc or {} db.skipAcc[t.q] = true end   -- (review round 2) after a /reload too
        end
      end
    end
  end
  ns._recHow = "f"
  if ns.RecEvent then pcall(ns.RecEvent, "C", 0, cur, to) end
  for _, t in ipairs(keep) do
    local j = IndexIn(STEPS, t)
    if j then table.remove(STEPS, j) to = to - 1 end
  end
  -- (22.10., Daniel) the hearthstone step stays in front: you are in its hub; the quests' steps right behind the step
  local nb = 0
  for _, t in ipairs(keep) do if t.k == "bind" then table.insert(STEPS, to + nb, t) nb = nb + 1 end end
  local n2 = nb
  for _, t in ipairs(keep) do if t.k ~= "bind" then n2 = n2 + 1 table.insert(STEPS, to + n2, t) end end
  cur = to
  ns.SaveStep()
  print((L["|cff3fa9f5Level|rdon: you are ahead on the route; it goes on at \"%s\"."]):format(STEPS[cur] and (ns.QName(STEPS[cur]) or STEPS[cur].n) or "?"))
  ns.LF.seen, ns.LF.since, ns.LF.recent = STEPS[cur], Now(), {}
  return true
end
ns.LeveldonFollow = ns.LF.FollowPlayer -- (tests)
-- (15.10., review round 3, H2: a player one level behind the plan lost 6 to 39 accepts and their chains, Call of
-- Earth among them) an accept left out for its level comes back once the level is there: at the next visit of its
-- giver before its kill step or turn-in ahead (not one you skipped by hand)
ns.ReturnLeftOut = function()
  if not ns._acceptSkipped then return end
  local back = 0
  for q in pairs(ns._acceptSkipped) do
    if not (db and db.skipAcc and db.skipAcc[q]) and not InLog(q) and not QuestDone(q) and not (ns.TooLowFor and ns.TooLowFor(q))
        and not Blocked(q) then
      local ja, jd
      for j = 1, cur - 1 do if STEPS[j].k == "accept" and STEPS[j].q == q then ja = j end end
      for j = cur, #STEPS do local t = STEPS[j] if t.q == q and (t.k == "do" or t.k == "turnin") then jd = j break end end
      if ja and jd then
        ns._acceptSkipped[q] = nil
        local s = table.remove(STEPS, ja)
        cur, jd = cur - 1, jd - 1
        local to = jd
        for j = cur, jd - 1 do
          local t = STEPS[j]
          if NPC_KIND[t.k] and s.m and Within(t, s, NEAR.hub) then to = j + 1 break end
        end
        table.insert(STEPS, to, s)
        marks[s] = nil
        -- (review round 4) kept there when the steps are built again
        s._movedLater = ns._composeId
        for j = to - 1, 1, -1 do
          if STEPS[j]._i then ns.LaterMove(q, STEPS[j]._i) break end
        end
        back = back + 1
      end
    end
  end
  if back > 0 then ns.SaveStep() Update(false) end
  return back
end
ns.LeveldonKind = function(i) return Kind(STEPS[i]) end -- (tests) a step as shown: an unfinished turn-in is a "do"
ns.LeveldonFollowClock = function(t) ns.LF.since = t end -- (tests)

function Update(initial)
  if not panel then return end   -- (15.10., review round 1) an event before PLAYER_LOGIN: nothing to update or save yet
  local before = cur
  -- (15.10., review round 1) when your home changed (a bind step done a moment early), kept over a /reload
  if db and GetBindLocation then
    local home = GetBindLocation()
    if home and db.homeLast and home ~= db.homeLast and GetTime then
      db.homeAt = GetTime()
      if ns.NoteHome then pcall(ns.NoteHome, home) end   -- (22.10.) which inn it is (Fit.lua)
    end
    if home then db.homeLast = home end
  end
  if ns.CheckHub then pcall(ns.CheckHub) end
  if ns.CheckSell then pcall(ns.CheckSell) end
  local behind = initial and not ns._restored
  if initial then ns._restored = nil end
  Advance(behind)
  if ns._replan and C_Timer then
    ns._replan = nil
    ns.After(0, function() if ns.LeveldonRecompose then pcall(ns.LeveldonRecompose) end end)
  end
  if not initial and not (ns._held and ns._held.s == STEPS[cur]) then   -- (13.10.) a held step: no jumps either
    -- (17.10.) while a timed quest's clock runs no class quest goes in front of it either (Fit.lua ns.TimedRunning)
    local timed = ns.TimedRunning and ns.TimedRunning()
    if not timed then pcall(ns.LF.ClassNow) end
    local ok, moved = pcall(ns.LF.FollowPlayer)
    if ok and moved then Advance(false) end
    -- (15.10., review round 1: Fit.lua's "finish what is around you first" was never called) a kill step with an
    -- open objective right here comes before walking away
    if ns.FinishNearbyFirst and not timed then pcall(ns.FinishNearbyFirst, STEPS, cur) end
    -- (22.10., Daniel: the hearthstone first when you stand at the inn) Fit.lua
    if ns.BindFirst and not timed then pcall(ns.BindFirst, STEPS, cur) end
    -- (15.10., review round 4) saved with what ClassNow or FinishNearbyFirst just put here: a /reload before the next
    -- save went back to the step before the pull
    ns.SaveStep()
  end
  if db and db.mountLater then pcall(ns.MountReminder) end   -- (review round 1) reached level 40 with the gold
  if STEPS[cur] and STEPS[cur].k == "bind" and not (bindAtStep and bindAtStep.s == STEPS[cur]) then
    bindAtStep = { s = STEPS[cur], at = GetBindLocation and GetBindLocation() or false }
  end
  -- (0.1.4, Daniel 09.10.: no arrow after choosing professions) the steps were rebuilt under the same
  -- number: a new step object needs the arrow too
  pcall(PlaceLaterBuys)
  -- (13.10., Daniel's hunter Don: "Elmore's Task" (level 9) stayed the step at level 7) whatever brought the route
  -- here, an accept above your level does not stay the step ("P q level w" for the recorder)
  local s0 = STEPS[cur]
  if s0 and s0.k == "accept" and s0.q and ns.TooLowFor and ns.TooLowFor(s0.q) then
    if ns.RecEvent then pcall(ns.RecEvent, "P", s0.q, select(2, ns.TooLowFor(s0.q)) or 0, "w") end
    Advance(false)
  end
  -- (0.1.6 playtest 1, Daniel 10.10.: the window said "Turn in", the arrow still "Do: ... 9/10") the arrow
  -- follows the step's kind and text at once (objective counts, a do that became a turn-in)
  local s = STEPS[cur]
  local key = s and (tostring(Kind(s)) .. "|" .. StepText(s)) or ""
  if cur ~= before or initial or s ~= arrowStep or key ~= arrowKey then arrowStep, arrowKey = s, key Arrow() end
  -- the stop: the choice opens by itself once
  if STEPS[cur] and STEPS[cur].k == "profs" and not (profsPanel and profsPanel:IsShown()) and not ns._profsAsked then
    ns._profsAsked = true
    ShowProfs()
  end
  pcall(MarkTick)
  Refresh()
end

local function Skip(delta)
  ns._recHow = delta > 0 and "s" or "b" -- (0.1.7) the recorder notes skipped and back
  local from = STEPS[cur]
  -- (review round 4) a waiting buy skipped by hand does not come back three steps later
  if delta > 0 and from and from._later and db and db.buyLater then db.buyLater[from.i] = nil end
  if delta > 0 and DropLater(cur) then delta = delta - 1 end
  cur = math.max(1, math.min(#STEPS + 1, cur + delta))
  -- (15.10., review round 3) back onto a chapter header (a title, no step): the step before it
  if delta < 0 and STEPS[cur] and STEPS[cur].k == "chapter" and cur > 1 then cur = cur - 1 end
  if delta > 0 and STEPS[cur - 1] then
    marks[STEPS[cur - 1]] = true
    local t = STEPS[cur - 1]
    if db and not t._i and (t.k == "buy" or t.k == "learn" or t.k == "train" or t.k == "skillup") then
      db.skipKeys = db.skipKeys or {}
      db.skipKeys[ns.StepKey(t)] = true
    end
  end
  if delta < 0 and STEPS[cur] then
    marks[STEPS[cur]] = nil
    if db and db.skipKeys then db.skipKeys[ns.StepKey(STEPS[cur])] = nil end
  end
  -- (13.10.) back: this step is held (Advance); forward ends the hold
  -- (15.10., review round 2) held by the step itself: a vendor stop put in at its number is not held
  if delta < 0 then ns._held = { s = STEPS[cur], wasDone = StepDone(cur) } else ns._held = nil end
  -- (11.10., Daniel: The Adventurer reported "giver not there", then Leveldon wanted it turned in: "I don't have
  -- the quest") an accept skipped without the quest: its do and turn-in steps go by too (StepDone), back undoes it
  ns._acceptSkipped = ns._acceptSkipped or {}
  if delta > 0 and from and from.k == "accept" and from.q and not InLog(from.q) and not QuestDone(from.q) then
    ns._acceptSkipped[from.q] = true
    -- (15.10., review round 1) kept over a /reload (per route: db.skipAcc goes with db.route)
    if db then db.skipAcc = db.skipAcc or {} db.skipAcc[from.q] = true end
  elseif delta < 0 and STEPS[cur] and STEPS[cur].k == "accept" and STEPS[cur].q then
    ns._acceptSkipped[STEPS[cur].q] = nil
    if db and db.skipAcc then db.skipAcc[STEPS[cur].q] = nil end
  end
  -- (0.2.3) back onto a step of a quest skipped by hand: the quest is back
  if delta < 0 and STEPS[cur] and STEPS[cur].q and db and db.skipQ then db.skipQ[STEPS[cur].q] = nil end
  -- (15.10., review round 4) the quest skipped last, also when done steps lie between: back to its step
  if delta < 0 and ns._lastSkipQ and db and db.skipQ and db.skipQ[ns._lastSkipQ.q] then
    db.skipQ[ns._lastSkipQ.q] = nil
    local j = IndexIn(STEPS, ns._lastSkipQ.s)
    if j then cur = j ns._held = { s = STEPS[cur], wasDone = StepDone(cur) } end
  end
  if delta > 0 then ns._lastSkipQ = nil end
  bindAtStep = nil
  ns.SaveStep()
  if delta > 0 then Advance(false) end
  Arrow()
  pcall(MarkTick)
  Refresh()
end

ns.LeveldonRefresh = function() if panel then Refresh() end end -- (0.1.7 Resize.lua)
-- (17.10., Daniel: "the same performance boost for the other addons") The window was built anew every second (rows,
-- closures, texts: about 10 KB a second). The second's ticker now builds it only when something it shows can have
-- changed: the step, the route, level and XP, the player's place in steps of TICK_YARDS, the marks; a timed quest's
-- clock every second; and at least every TICK_FULL seconds (food, camp and the like). Events build it as before.
do -- (few locals: Lua allows 200 in this file)
local TICK_YARDS, TICK_FULL = 20, 10
local tick = {}
ns.LF.TickReset = function() tick.at = GetTime and GetTime() or 0 end
function ns.LF.TickRefresh()
  local now = GetTime and GetTime() or 0
  local py, px = nil, nil
  if UnitPosition then py, px = UnitPosition("player") end
  local bx = type(px) == "number" and math.floor(px / TICK_YARDS) or nil
  local by = type(py) == "number" and math.floor(py / TICK_YARDS) or nil
  local nm = 0
  for _ in pairs(marks) do nm = nm + 1 end
  local lv, xp = Level(), UnitXP and UnitXP("player") or 0
  local timed = ns.TimedRunning and ns.TimedRunning()
  if not timed and tick.at and now - tick.at < TICK_FULL and now >= tick.at and tick.cur == cur and tick.steps == STEPS
      and tick.n == #STEPS and tick.lv == lv and tick.xp == xp and tick.bx == bx and tick.by == by and tick.nm == nm
      and tick.w == panel._width and tick.map == Map() then
    return
  end
  tick.at, tick.cur, tick.steps, tick.n, tick.lv, tick.xp, tick.bx, tick.by, tick.nm, tick.w, tick.map =
    now, cur, STEPS, #STEPS, lv, xp, bx, by, nm, panel._width, Map()
  Refresh()
end
end
-- (0.1.7 Fit.lua) the steps built again, the current step kept
ns.LeveldonRecompose = function()
  local here, old, at = STEPS[cur], STEPS, cur
  Compose()
  cur = ns.RefindCur(here, old, at)
  ns.SaveStep()
  Update(false)
end
ns.LeveldonSkip = function(delta) Skip(delta) end
-- (15.10., review round 2) skip that step, even when another came before it meanwhile (a vendor stop while you wrote
-- a report); the route stays at the step it is on
ns.LeveldonSkipStep = function(obj)
  local j = obj and IndexIn(STEPS, obj)
  if not j then return Skip(1) end
  local was = STEPS[cur]
  cur = j
  Skip(1)
  if was and was ~= obj then
    local w = IndexIn(STEPS, was)
    if w and w < cur and not StepDone(w) then cur = w ns.SaveStep() Refresh() end
  end
end -- (0.1.7 Report.lua: after a report the next step)

-- (0.2.3, Daniel 13.10.: "right-click on the current quest with the option skip") a small menu on the current
-- step: skip this step (as the arrow button), or skip the whole quest: all its steps go by (taking, doing, handing
-- in, buying for it), kept per character in db.skipQ; a step back onto one of its steps brings the quest back
ns.SM = {}
function ns.SM.Action(what)
  local s = STEPS[cur]
  if what == "step" then
    Skip(1)
  elseif what == "quest" and s and s.q and db then
    db.skipQ = db.skipQ or {}
    db.skipQ[s.q] = true
    if ns.LvdBags then ns.LvdBags.Soon() end -- (21.10.) an item kept for it loses its mark in the bags
    ns._lastSkipQ = { q = s.q, s = s }   -- (review round 4) one step back brings it back, wherever the route went on
    ns._recHow, ns._held = "s", nil
    bindAtStep = nil
    print((L["|cff3fa9f5Level|rdon: \"%s\" skipped. One step back brings it back."]):format(ns.QName(s) or s.n or tostring(s.q)))
    Advance(false)
    ns.SaveStep()
    Arrow()
    pcall(MarkTick)
    Refresh()
  end
  if ns.SM.menu then ns.SM.menu:Hide() end
end
function ns.SM.Row(parent)
  local r = ns.CreateFrame("Button", nil, parent)
  r:SetHeight(22)
  r.hover = r:CreateTexture(nil, "BACKGROUND")
  r.hover:SetAllPoints(r)
  r.hover:SetColorTexture(1, 1, 1, 0.07)
  r.hover:Hide()
  r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  r.text:SetPoint("LEFT", r, "LEFT", 8, 0)
  r.text:SetPoint("RIGHT", r, "RIGHT", -4, 0)
  r.text:SetJustifyH("LEFT")
  r:SetScript("OnEnter", function(self) self.hover:Show() end)
  r:SetScript("OnLeave", function(self) self.hover:Hide() end)
  return r
end
function ns.SM.Show()
  local s = STEPS[cur]
  if not s then return end
  local m = ns.SM.menu
  if not m then
    local c = ns.CreateFrame("Button", nil, UIParent)
    c:SetAllPoints(UIParent)
    c:SetFrameStrata("DIALOG")
    if c.RegisterForClicks then c:RegisterForClicks("AnyUp") end
    c:SetScript("OnClick", function() if ns.SM.menu then ns.SM.menu:Hide() end end)
    m = ns.CreateFrame("Frame", "LeveldonStepMenu", UIParent)
    m.catcher = c
    m:SetFrameStrata("DIALOG")
    local lvl = c.GetFrameLevel and tonumber(c:GetFrameLevel())
    if lvl and m.SetFrameLevel then m:SetFrameLevel(lvl + 10) end
    m:SetWidth(220)
    m:EnableMouse(true)
    m:SetClampedToScreen(true)
    local bg = m:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(m)
    bg:SetColorTexture(0.10, 0.11, 0.22, 0.97)
    m.title = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    m.title:SetPoint("TOPLEFT", m, "TOPLEFT", 10, -8)
    m.title:SetPoint("RIGHT", m, "RIGHT", -10, 0)
    m.title:SetJustifyH("LEFT")
    m.rows = { ns.SM.Row(m), ns.SM.Row(m) }
    for k, r in ipairs(m.rows) do
      local above = k == 1 and m.title or m.rows[k - 1]
      local dy = k == 1 and -6 or 0
      r:SetPoint("TOPLEFT", above, "BOTTOMLEFT", k == 1 and -6 or 0, dy)
      r:SetPoint("RIGHT", m, "RIGHT", -4, 0)
    end
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "LeveldonStepMenu") end
    m:SetScript("OnHide", function(self) self.catcher:Hide() end)
    ns.SM.menu = m
  end
  m.title:SetText(StepText(s))
  local items = { { "step", L["Skip this step"] } }
  if s.q then items[2] = { "quest", L["Skip this quest"] } end
  for k, r in ipairs(m.rows) do
    local it = items[k]
    if it then
      r.text:SetText(it[2])
      r:SetScript("OnClick", function() ns.SM.Action(it[1]) end)
      r:Show()
    else
      r:Hide()
    end
  end
  m.items = #items
  local th = m.title.GetStringHeight and tonumber(m.title:GetStringHeight()) or 14
  if not th or th < 12 then th = 14 end
  m:SetHeight(8 + th + 6 + #items * 22 + 8)
  if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
  local x, y = 0, 0
  if GetCursorPosition then x, y = GetCursorPosition() end
  local sc = UIParent.GetEffectiveScale and tonumber(UIParent:GetEffectiveScale()) or 1
  m:ClearAllPoints()
  m:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (x or 0) / sc - 8, (y or 0) / sc + 8)
  m.catcher:Show()
  m:Show()
end
local function Build()
  panel = Style.Panel("LeveldonPanel", UIParent, {
    look = "book", media = "Interface\\AddOns\\Leveldon\\Media\\",
    title = Style.Wordmark("Level", "don") .. L["  |cff8a8f99beta "] .. VERSION .. "|r",
    width = 360, close = true, collapse = true, get = Get, set = Set,
    defaultPoint = { "TOPRIGHT", "TOPRIGHT", -260, -260 },
    buttons = {
      -- (17.10., Daniel: "the options menu in Questdon's look") the options window (Options.lua), as Questdon's cog
      { kind = "options", key = "options", onClick = function() if ns.ToggleOptions then ns.ToggleOptions() end end,
        tooltip = { L["Options"], nil, "/lvd options" } },
      { kind = "forward", key = "next", onClick = function() Skip(1) end, tooltip = { L["Skip this step"], { L["Right-click the step: skip it or the whole quest."] }, "/lvd next" } },
      { kind = "back", key = "back", onClick = function() Skip(-1) end, tooltip = { L["One step back"], nil, "/lvd back" } },
      -- (0.1.7, Daniel 11.10.) report this step: quest giver not there, route makes no sense, a remark
      { kind = "report", key = "report", onClick = function() if ns.OpenReport then ns.OpenReport() end end,
        tooltip = { L["Report this step"], { L["Quest giver not there, route makes no sense, or a remark."] }, "/lvd report" } },
      -- (0.1.8, Daniel 12.10.) the whole quest to read (17.10.: the stopwatch button is gone)
      { kind = "lvdRead", key = "read", onClick = function()
          local st, a = STEPS[cur], API()
          if st and st.q and a and a.ShowQuestText then a.ShowQuestText(st.q) end
        end, tooltip = { L["Read the whole quest"], nil, L["Shift-click a step: the same."] } },
    },
  })
  if Get("shown") ~= false then panel:FadeIn() end
end

-- (23.10., Daniel's /lvd mem: the three tickers of PLAYER_LOGIN 62 KB a second together) their parts by name: called
-- from a ticker they show as "(inner)", from an event at the top. Outside /lvd mem each wrapper checks one variable.
if ns.Track then
  Refresh = ns.Track("window build", Refresh)
  ns.LF.TickRefresh = ns.Track("window tick", ns.LF.TickRefresh)
  AlongHere = ns.Track("along here", AlongHere)
  NearestObjective = ns.Track("nearest objective", NearestObjective)
  Arrow = ns.Track("arrow", Arrow)
  MarkTick = ns.Track("mark tick", MarkTick)
  TravelTick = ns.Track("travel tick", TravelTick)
  ApplyTracker = ns.Track("tracker hide", ApplyTracker)
  -- (23.10., second /lvd mem: "window build" about 58 KB each in the game, 3.6 KB in the bench) the build's parts
  Hints = ns.Track("hints", Hints)
  StepText = ns.Track("step text", StepText)
  Kind = ns.Track("kind", Kind)
  StepDone = ns.Track("step done", StepDone)
  ns.LvdObjList = ns.Track("objective list", ns.LvdObjList)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local f = ns.CreateFrame("Frame")
local pending = false
local function Soon()
  if pending then return end
  pending = true
  ns.After(0.3, function() pending = false Update(false) end)
end

f:SetScript("OnEvent", function(_, event, ...)
  if event == "QUEST_LOG_UPDATE" or event == "QUEST_ACCEPTED" or event == "QUEST_TURNED_IN" or event == "UNIT_QUEST_LOG_CHANGED" then
    ns._logDirty = true -- (23.10.) LogQuests builds its list again
  end
  -- (15.10., review round 3) Questdon's "cannot take" can change: a quest handed in, a skill learned, a level
  if event == "QUEST_TURNED_IN" or event == "SKILL_LINES_CHANGED" or event == "PLAYER_LEVEL_UP" then
    for k in pairs(blocked) do blocked[k] = nil end
  end
  if (event == "PLAYER_LEVEL_UP" or event == "QUEST_TURNED_IN") and C_Timer then ns.After(1, function() pcall(ns.ReturnLeftOut) end) end
  if event == "ADDON_LOADED" then
    -- (0.1.6) the quest log of the map (or the classic one) may come with a Blizzard addon later
    if ... ~= addonName then if db then pcall(MakeLogButton) end return end
    LeveldonCharDB = LeveldonCharDB or {}
    db = LeveldonCharDB
  elseif event == "PLAYER_LOGIN" then
    -- (12.10., Daniel: "the clock says 1:18, I have played 32 min") a new character with the name of a deleted one
    -- gets the old one's saved data (the game keeps it by name): with another character ID all but the window go
    local guid = UnitGUID and UnitGUID("player")
    if type(guid) == "string" and type(db.guid) == "string" and db.guid ~= guid then
      local panel = db.panel
      for k in pairs(db) do db[k] = nil end
      db.panel = panel
    end
    if type(guid) == "string" then db.guid = guid end
    LoadRoute()
    -- another route (race, class, a new build) than last time: the step number starts over, the speedrun clock
    -- too when race or class changed (a new build keeps your time)
    local key = (ROUTE.race or "?") .. ":" .. (ROUTE.cls or "?") .. ":" .. #ROUTE.steps
    local remap
    if db.route ~= key then
      local other = type(db.route) == "string" and db.route:match("^[^:]*:[^:]*") ~= key:match("^[^:]*:[^:]*")
      if other then db.run = nil
      elseif db.stepK and db.stepQ then remap = { k = db.stepK, q = db.stepQ } end -- (13.10.) a new build: same quest step
      -- (15.10., review round 2) a new build (or the dungeon switch) keeps the accepts you skipped (quest IDs stay);
      -- another race or class does not
      if other or type(db.route) ~= "string" then db.skipAcc, ns._acceptSkipped = nil, nil end
      db.route, db.step, db.laterMoves, db.pullMoves = key, nil, nil, nil   -- (review round 4) moves by route index
    end
    -- (15.10., review round 1) accepts skipped by hand on this route, also after a /reload
    if db.skipAcc then
      ns._acceptSkipped = ns._acceptSkipped or {}
      for q in pairs(db.skipAcc) do ns._acceptSkipped[q] = true end
    end
    -- (13.10.) the recording session started on the same event may have read the route before it was loaded
    local rs = ns.RecSession and ns.RecSession()
    if rs then rs.route, rs.rid = db.route, ns.LeveldonRouteId() end
    Compose()
    Build()
    local restored = ns.RestoreStep()
    cur = restored or StartIndex()
    -- (15.10., review round 2) the step you logged out on stays: the first update does not pass a pending inn,
    -- flight point or trainer because a later quest of the chapter is in your log (that is for a first start)
    ns._restored = restored ~= nil or remap ~= nil
    if remap then
      for j, t in ipairs(STEPS) do if t.k == remap.k and t.q == remap.q then cur = j break end end
      ns.SaveStep()
    end
    ns.After(2, function() Update(true) end) -- quest log and Questdon are ready by then
    sessionStart = Now()
    ns.After(6, BagCheck)
    ns.After(4, function() pcall(CheckLogChains) end)
    ns.NewTicker(1, function() if panel and panel:IsShown() then pcall(ns.LF.TickRefresh) end pcall(MarkTick) end)
    -- (0.1.6) Blizzard's quest tracker: hidden again when the game shows it again (one alpha read)
    pcall(ApplyTracker)
    pcall(MakeLogButton)
    ns.After(3, function() pcall(CheckProfsAtStart) end) -- (0.1.6) professions missing: the choice now
    ns.NewTicker(0.5, function()
      if (db.hideTracker ~= false or trackerHidden) and not InCombat() then pcall(ApplyTracker) end
      if not logButton or logButton._rank > 1 then pcall(MakeLogButton) end
    end)
    ns.NewTicker(2, function()
      pcall(TravelTick)
      if STEPS[cur] and Kind(STEPS[cur]) == "do" then pcall(MarkUsed, STEPS[cur].q) pcall(Arrow) end
      -- (15.10., Zip at Mirror Lake: "arrow still pointing to Mirror Lake") a turn-in's place asked again: right
      -- after the objective Questdon may still give the objective's spot (its map points are rebuilt a moment later)
      if STEPS[cur] and Kind(STEPS[cur]) == "turnin" then pcall(Arrow) end
    end)
  elseif event == "TAXIMAP_OPENED" then
    pcall(RecordIndoor)
    pcall(MarkInteract)
    if STEPS[cur] and STEPS[cur].k == "fp" then marks[STEPS[cur]] = true end
    -- (15.10., review round 1) talked to the flight master a step early: its fp step close ahead and here goes by too
    local x, y = ns.PlayerXY()
    for j = cur + 1, math.min(#STEPS, cur + 4) do
      local t = STEPS[j]
      if t.k == "fp" and x and t.m == Map() and t.x and Within({ m = t.m, x = x, y = y }, t, 400) then marks[t] = true end
    end
    Soon()
  elseif event == "TRAINER_SHOW" then
    pcall(RecordIndoor)
    pcall(MarkInteract)
    -- (0.1.4) the class trainer: what this level brings is learned, later trainer stops up to it are done
    if db and not (IsTradeskillTrainer and IsTradeskillTrainer()) and ns.TR.IsClassTrainer() then
      -- (15.10., review round 2) only your class trainer's window does the step (a profession or pet trainer not)
      if STEPS[cur] and STEPS[cur].k == "train" then marks[STEPS[cur]] = true end
      pcall(ns.TR.Recommend)
      db.trained = math.max(db.trained or 0, Level())
      -- (15.10., review round 1) the trainer steps ahead planned again: what you could not pay here (5 copper)
      -- is recommended at the next visit; again when the window closes, with what you bought
      if ns.LeveldonRecompose then pcall(ns.LeveldonRecompose) end
      ns._trainerOpen = true
    end
    Soon()
  elseif event == "TRAINER_CLOSED" then
    if ns._trainerOpen and ns.LeveldonRecompose then pcall(ns.LeveldonRecompose) end
    ns._trainerOpen = nil
  elseif event == "CHAT_MSG_SYSTEM" then
    pcall(OnSystemMessage, (...))
    Soon()
  elseif event == "CHAT_MSG_SKILL" then
    pcall(OnSkillMessage, (...))
    Soon()
  elseif event == "CHAT_MSG_LOOT" then
    local msg = ...
    CheckKeep(msg)
  elseif event == "PLAYER_MONEY" then
    pcall(ns.MountReminder)
  elseif event == "CHARACTER_POINTS_CHANGED" then
    -- (15.10., review round 1) a talent point spent: the trainer steps ahead recommend by your talents again
    if ns.LeveldonRecompose then pcall(ns.LeveldonRecompose) end
  elseif event == "BAG_UPDATE_DELAYED" then
    pcall(CheckStarters)
    -- (15.10., Daniel's mage Zip: "bought 1 stack and it does not go on") a buy step is done once the items are in
    -- the bags: buying sends no quest event, so the step waited for the next one
    Soon()
  elseif event == "QUEST_ACCEPTED" then
    local a1, a2 = ...
    ns.NoteQuestEvent(tonumber(a2) or tonumber(a1)) -- (13.10.) FollowPlayer: quests taken while the step waits
    -- (15.10., review round 1) taken again: a second abandon brings its accept back again (RetakeBefore)
    if ns._retaken then ns._retaken[tonumber(a2) or tonumber(a1) or 0] = nil end
    pcall(OnFirstAccept)
    pcall(CheckLogChains)
    Soon()
  elseif event == "MERCHANT_SHOW" then
    pcall(RecordIndoor)
    pcall(MarkInteract)
    if ns.NoteMerchant then pcall(ns.NoteMerchant) end
    if ns.KeepAtMerchant then pcall(ns.KeepAtMerchant) end
    merchantAt = Now()
    ns._merchantAt = merchantAt
    Soon()
  elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
    -- (11.10.) alive again (the spirit healer, or back at the corpse): a "die" step is done
    if STEPS[cur] and STEPS[cur].k == "die" and (event == "PLAYER_UNGHOST" or not (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player"))) then marks[STEPS[cur]] = true end
    Soon()
  elseif event == "GOSSIP_SHOW" then
    pcall(RecordIndoor)
    pcall(MarkInteract)
  elseif event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then
    pcall(RecordIndoor)
  elseif event == "QUEST_TURNED_IN" then
    ns.NoteQuestEvent(tonumber((...)))
    Soon()
  elseif event == "SKILL_LINES_CHANGED" then
    pcall(ns.CheckLearnedProfs)
    Soon()
  elseif event == "PLAYER_REGEN_ENABLED" then
    -- (0.1.6) what waited for the end of the fight
    if trackerPending then pcall(ApplyTracker) end
    if profsEarlyWaiting then ns.After(1, ShowProfsEarly) end
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, _, spellID = ...
    local sname = SpellName(spellID)
    if unit == "player" and sname and (sname == SpellName(818) or sname == SpellName(1229737)) then campAt = Now() end
    -- (12.10.) the sleeping bag used: the 2 hours of Well-Rested start
    if unit == "player" and sname and GetItemSpell and sname == GetItemSpell(ns.Bag.item) then
      ns.Bag.at = Now()
      if db and time then db.bagAt = time() end
    end
    if unit == "player" and STEPS[cur] and STEPS[cur].k == "hearth" and (spellID == 8690 or spellID == STEPS[cur].sp) then marks[STEPS[cur]] = true end
    Soon()
  else
    Soon()
  end
end)
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_LOG_UPDATE",
  "PLAYER_LEVEL_UP", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "TAXIMAP_OPENED", "TRAINER_SHOW",
  "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_XP_UPDATE", "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "CHAT_MSG_SYSTEM", "SPELLS_CHANGED", "MERCHANT_SHOW", "CHAT_MSG_LOOT", "BAG_UPDATE_DELAYED",
  "GOSSIP_SHOW", "PLAYER_REGEN_ENABLED", "UNIT_QUEST_LOG_CHANGED", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE",
  "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_MONEY", "CHARACTER_POINTS_CHANGED", "TRAINER_CLOSED" }) do
  pcall(f.RegisterEvent, f, e)
end

-- (12.10., 22.10.) the route again after a switch (dungeons, start area): the same step in the new route, else the start of
-- the first chapter above your level; what you did already is skipped by the usual checks
function ns.ReloadRoute()
  local was = STEPS[cur]
  LoadRoute()
  Compose()
  if not panel then Build() end   -- (15.10., review round 1) Build made a second window next to the old one
  -- (15.10., review round 3) the same quest step in the other route, else the chapter's start as before
  local again
  if was then
    -- (review round 4) a service step too (inn, trainer, flight point): by kind, name and level
    for j, t in ipairs(STEPS) do
      if t.k == was.k and t.q == was.q and (was.q or (t.n == was.n and t.lvl == was.lvl)) then again = j break end
    end
  end
  cur = again or StartIndex()
  Update(again == nil)
end

-- (22.10., Daniel: "routes selectable, a dwarf may want the human route for reputation") the start areas this character can
-- take (ns.LINES), the one picked ("" = the race's own) and the switch; also mid-route
function ns.LineChoices()
  local race = PlayerRaceKey()
  local _, cls = UnitClass("player")
  cls = cls and cls:lower()
  local info = race and ns.LINES and ns.LINES[race]
  local byLine = info and (info[cls] or info.warrior)
  if not byLine then return nil end
  local list = { { key = info.own, own = true } }
  for key in pairs(byLine) do if key ~= info.own then list[#list + 1] = { key = key } end end
  table.sort(list, function(a, b) if a.own ~= b.own then return a.own == true end return a.key < b.key end)
  for _, e in ipairs(list) do e.info = byLine[e.key] end
  return list, (db and db.line) or info.own
end
function ns.SetLine(key)
  local list = ns.LineChoices()
  if not (list and db) then return false end
  local ok
  for _, e in ipairs(list) do if e.key == key then ok = e end end
  if not ok then return false end
  local now = db.line
  if (ok.own and not now) or now == key then return true end
  db.line = (not ok.own) and key or nil
  ns.ReloadRoute()
  if ns.LineRefresh then pcall(ns.LineRefresh) end
  return true
end

-- (25.10.) the window on or off from elsewhere (Options.lua: only record), saved like /lvd does
function ns.SetWindowShown(v)
  if not panel then return end
  if v and not panel:IsShown() then panel:FadeIn() Set("shown", true) Refresh()
  elseif not v and panel:IsShown() then panel:FadeOut() Set("shown", false) end
end
function ns.WindowShown() return panel ~= nil and panel:IsShown() or false end
function ns.ToggleWindow() ns.SetWindowShown(not ns.WindowShown()) end
-- (25.10., Daniel: "a key for the window") Bindings.xml calls this; the names show in Key Bindings > AddOns
BINDING_HEADER_LEVELDON = "Leveldon"
BINDING_NAME_LEVELDON_TOGGLE = L["Show or hide the window"]
LeveldonToggleWindow = function() pcall(ns.ToggleWindow) end

SLASH_LEVELDON1 = "/lvd"
SLASH_LEVELDON2 = "/leveldon"
SlashCmdList.LEVELDON = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if msg == "next" then Skip(1)
  elseif msg == "mem" or msg:match("^mem %d+$") then if ns.MemCheck then ns.MemCheck(msg:match("^mem (%d+)$")) end -- (23.10.) memory by part
  elseif msg == "options" or msg == "config" then if ns.OpenOptions then ns.OpenOptions() end
  elseif msg == "report" then if ns.OpenReport then ns.OpenReport() end
  elseif msg == "text" or msg:match("^text ") then if ns.TextCommand then ns.TextCommand(msg:match("^text%s*(.*)$")) end
  elseif msg == "rec" or msg == "rec on" or msg == "rec off" then if ns.RecCommand then ns.RecCommand(msg:match("^rec ?(.*)$")) end
  elseif msg == "route" then print("|cff3fa9f5Level|rdon: " .. routeInfo)
  elseif msg == "profs" or msg == "professions" then ShowProfs()
  elseif msg == "line" or msg:match("^line ") then if ns.LineCommand then ns.LineCommand(msg:match("^line%s*(.*)$")) end
  elseif msg == "bag off" or msg == "bag on" then
    db.bag = msg == "bag on"
    print(L["|cff3fa9f5Level|rdon: sleeping bag reminder "] .. (db.bag and L["on"] or L["off"]) .. ".")
  elseif msg == "camp off" or msg == "camp on" then
    db.camp = msg == "camp on"
    print(L["|cff3fa9f5Level|rdon: campfire reminder "] .. (db.camp and L["on"] or L["off"]) .. ".")
  elseif msg == "bags" then BagCheck()
  elseif msg == "marks" then
    -- (0.1.6) the map pin on service stops
    db.markStops = not db.markStops
    pcall(MarkTick)
    print("|cff3fa9f5Level|rdon: " .. (db.markStops and T.marksOn or T.marksOff) .. ".")
  elseif msg == "tracker" then ToggleTracker()
  elseif msg == "raidmarks" then if ns.LvdMarks then ns.LvdMarks.Command() end
  elseif msg == "export" then ShowExport()
  elseif msg == "share" or msg == "share on" or msg == "share off" then if ns.ShareCommand then ns.ShareCommand(msg:match("^share ?(.*)$")) end
  elseif msg == "dungeon" or msg == "dungeon no" then
    local lv = Level()
    for _, d in ipairs(ROUTE.dungeons or {}) do
      if lv >= d.lo and lv <= d.lo + 6 and not (db.dSkip and db.dSkip[d.id]) and not (db.dTaken and db.dTaken[d.id]) then
        if msg == "dungeon no" then
          db.dSkip = db.dSkip or {} db.dSkip[d.id] = true
          print("|cff3fa9f5Level|rdon: " .. ns.DgName(d.id, d.n) .. L[" skipped."])
        else
          db.dTaken = db.dTaken or {} db.dTaken[d.id] = true
          -- after the current step of the route (its index in the route itself)
          local at = 1
          for j = cur, 1, -1 do if STEPS[j] and STEPS[j]._i then at = STEPS[j]._i break end end
          db.dPlans = db.dPlans or {}
          table.insert(db.dPlans, { id = d.id, at = at })
          -- (15.10., review round 3) the step you are on stays; the run's steps come right after it
          local here, old, at0 = STEPS[cur], STEPS, cur
          Compose()
          cur = ns.RefindCur(here, old, at0)
          Update(false)
          print("|cff3fa9f5Level|rdon: " .. ns.DgName(d.id, d.n) .. L[" planned: pick up its quests, find a group, turn them in."])
        end
        break
      end
    end
  elseif msg == "dungeons" or msg == "dungeons on" or msg == "dungeons off" then
    -- (12.10.) the route with the dungeons of your faction planned in (1 to 30), or without
    if msg ~= "dungeons" then db.dungeons = msg == "dungeons on" end
    if msg ~= "dungeons" then ns.ReloadRoute() end
    print("|cff3fa9f5Level|rdon: " .. (db.dungeons and L["dungeons planned in (/lvd dungeons off)"] or L["no dungeons (/lvd dungeons on)"])
      .. (db.dungeons and not ROUTE.withDungeons and L[", none planned for this character yet"] or "") .. ".")
  elseif msg == "solo" then
    db.solo = not db.solo
    -- (15.10., review round 1) the current step kept by its object (group steps taken out moved it by their count);
    -- a group step that goes: the next step that stays
    -- (review round 4) through RefindCur: a hub trainer stop you are on stays, moved steps go back to their place
    local here, old, at0 = STEPS[cur], STEPS, cur
    Compose()
    cur = math.min(ns.RefindCur(here, old, at0), #STEPS)
    Update(false)   -- (review round 4) not the first-start pass over service steps
    print(L["|cff3fa9f5Level|rdon: solo "] .. (db.solo and L["on: no group and escort quests"] or L["off"]) .. ".")
  elseif msg == "back" then Skip(-1)
  elseif msg == "quiet" or msg == "record" then if ns.SetRecordOnly then ns.SetRecordOnly() end -- (25.10.)
  elseif msg == "reset" then
    marks, bindAtStep = setmetatable({}, { __mode = "k" }), nil
    cur = StartIndex()
    Update(true)
    print(L["|cff3fa9f5Level|rdon: route started again from your level."])
  elseif panel then
    ns.ToggleWindow()
  end
end
