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
  local race = PlayerRaceKey()
  local _, cls = UnitClass("player")
  cls = cls and cls:lower()
  if not race or not cls then return false end
  local addon = DATA_ADDON[race]
  local loader = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
  if addon and loader and not (LeveldonRoutes and LeveldonRoutes[race]) then pcall(loader, addon) end
  local bands = LeveldonRoutes and LeveldonRoutes[race] and (LeveldonRoutes[race][cls] or LeveldonRoutes[race].warrior)
  if type(bands) ~= "table" then return false end
  local merged = { race = race, cls = cls, steps = {}, early = {}, profOptions = {}, vendors = {}, keep = {}, dungeons = {}, links = {}, bonus = {}, ids = {} }
  local seenD, hours = {}, 0
  local tOffset = 0 -- (0.1.8) the planned times (t) of a band count from its start: the next band's go on
  -- (12.10., Daniel: dungeons as optional blocks) /lvd dungeons on: the 1 to 30 band the builder planned with the
  -- dungeons of this faction (their quests before, the run at its level, the turn-ins after), where there is one
  local useDg = LeveldonCharDB and LeveldonCharDB.dungeons and type(bands.dg) == "string"
  merged.withDungeons = useDg or nil
  for bi, text in ipairs(bands) do
    if bi == 1 and useDg then text = bands.dg end
    local t = Unpack(text)
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
        if t.hubopt then st._ho = true end -- (11.10.) its hubs already ordered by the builder (hubopt.py)
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
  routeInfo = (L["%s %s%s, %d steps, about %.0f h"]):format(race, cls, useDg and L[" with dungeons"] or "", #merged.steps, hours)
  return true
end
ns.LoadRoute = LoadRoute
ns.RouteInfo = function() return routeInfo end
local NEXT_SHOWN = 3
local GRAY = 8 -- a quest this many levels below the character is skipped

local db
local panel
local cur = 1
local marks = {} -- non-quest steps done this session: [index] = true
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
local VERSION = "0.2.1"
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

-- (0.1.6, Daniel 10.10.) the start areas' reward books for a gathering profession (Wowhead Forever, 10.10.:
-- "Increases your <profession> skill by 2. Cannot raise <profession> skill over 15", the profession is learned
-- with it). Each start area has one quest offering the three as a choice. Only used when the player chose a
-- gathering profession; otherwise the quest stays an ordinary quest.
local GATHER_BOOK = {
  [186] = { i = 247840, n = "Mining for Dummies" },
  [393] = { i = 247846, n = "Pelt Collecting for Beginners" },
  [182] = { i = 247841, n = "Wild Harvest" },
}
local GATHER_ORDER = { 182, 186, 393 }
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
-- recipe (Wowhead Forever: both need Cooking 1, colours 1/45/65/85, one raw fish each, at a cooking fire)
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
local HERB = { "Herbalism", "Kräuterkunde", "Herboristerie", "Herboristería", "Herborismo", "Травничество", "약초 채집", "草藥學" }

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
local function SkillNames(sk)
  local names = {}
  local n = SpellName(PROF_SPELL[sk])
  if n then names[n] = true end
  names[SKILL_EN[sk] or ""] = true
  if sk == 182 then for _, h in ipairs(HERB) do names[h] = true end end
  return names
end
local function Knows(spell)
  if not spell then return false end
  for _, f in ipairs({ IsPlayerSpell, IsSpellKnown }) do
    local ok, v = pcall(f or function() end, spell)
    if ok and v then return true end
  end
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
function ns.TR.Pending(toLv, planned)
  local data = ns.TR.Data()
  if not data then return nil end
  local list, twos, ones = {}, 0, 0
  for lv = 1, toLv do
    for _, e in ipairs(data[lv] or {}) do
      local id, imp, prev, tal = e[1], e[2], e[3], e[4]
      if not (planned and planned[id]) and not Knows(id) and (tal == 0 or Knows(prev)) then
        list[#list + 1] = e
        if imp == 2 then twos = twos + 1 elseif imp == 1 then ones = ones + 1 end
      end
    end
  end
  return twos, ones, list
end
function ns.TR.Worth(twos, ones, gap) return twos > 0 or ones >= 3 or (gap >= 6 and ones > 0) end
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
function ns.PlayerXY()
  local m = Map()
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
-- copper: Wowhead Forever item pages (item=2901, 7005, 6256, 6529, 6325, 6326, 5956), "Sold by" list, column
-- "cost", read 10.10.2026; the highest price among the vendors of Leveldon's routes (others sell a copper
-- or two cheaper)
local BUY_PRICE = { [2901] = 10, [7005] = 10, [6256] = 24, [6529] = 52, [6325] = 42, [6326] = 42, [5956] = 20 }
-- (playtest 1) who sells them: the same "Sold by" lists, only the vendors that Leveldon's routes know (their
-- places come from the route's vendor list and buy data)
local SELLS = {} -- vendor name -> { [item] = true }
do
local SELLERS_OF = {
  [2901] = "Abigail Shiel;Adlin Pridedrift;Andrew Hilbert;Banalash;Belandiel Farflight;Billibub Cogspinner;Brother Danil;Christopher Hewen;Dalria;Drake Lindgren;Duokna;Elisa Steelhand;Elizabeth Van Talen;Fanorran Stilloak;Felicia Doan;Felika;Flakk;Gigget Zipcoil;Gina MacGregor;Helenia Olden;Iallion Featherfall;Jack Findle;Jandia;Jase Farlane;Joshua Kien;Kawnie Softbreeze;Keena;Kelsey Fargo;Kireena;Kulwia;Kuruk;Lah'Mawhani;Lorelae Wintersong;Loslor Rudge;Lyrai;Messana Crestwind;Micha Yance;Mishta;Narret Shadowgrove;Neal Allen;Nerrist;Norzsh;Qia;Ranik;Sally Swiftwrench;Samuel Van Brunt;Shadi Mistrunner;Shandrina;Sheendra Tallgrass;Shimra;Syurana;Tai'tasi;Tari'qa;Taur Stonehoof;Tharynn Bouden;Thrawn Boltar;Thurman Mullby;Trak'gen;Ullanna;Uualia Suncrest;Vartha Rockmane;Vivianna;Wunna Darkmane",
  [7005] = "Abigail Shiel;Adlin Pridedrift;Andrew Hilbert;Banalash;Belandiel Farflight;Bombus Finespindle;Brighid Stormflayer;Brother Danil;Christopher Hewen;Dalria;Drake Lindgren;Duokna;Felicia Doan;Felika;Flakk;Gigget Zipcoil;Gina MacGregor;Helenia Olden;Iallion Featherfall;Jack Findle;Jase Farlane;Joshua Kien;Kagil;Kawnie Softbreeze;Keena;Kireena;Kulwia;Kuruk;Lah'Mawhani;Lorelae Wintersong;Lyrai;Margaret Weaver;Mishta;Nadyia Maneweaver;Narret Shadowgrove;Nawka Wildsong;Nerrist;Qia;Ranik;Riley Peltskinner;Shadi Mistrunner;Shandrina;Sheendra Tallgrass;Shimra;Syurana;Tai'tasi;Tamar;Tari'qa;Terunne Bearshaper;Tharynn Bouden;Thurman Mullby;Trak'gen;Ullanna;Uualia Suncrest;Vivianna;Wunna Darkmane",
  [6256] = "Abigail Shiel;Andrew Hilbert;Banalash;Belandiel Farflight;Christopher Hewen;Dalria;Drake Lindgren;Felicia Doan;Felika;Fenn Fairweather;Flakk;Gigget Zipcoil;Gina MacGregor;Gretta Ganter;Harn Longcast;Helenia Olden;Iallion Featherfall;Jack Findle;Jase Farlane;Keena;Kireena;Kulwia;Lah'Mawhani;Lorelae Wintersong;Martine Tramblay;Mishta;Narret Shadowgrove;Nerrist;Nessa Shadowsong;Qia;Ranik;Shadi Mistrunner;Shandrina;Sheendra Tallgrass;Shimra;Syurana;Tai'tasi;Tari'qa;Tharynn Bouden;Ullanna;Vivianna;Voloren;Wunna Darkmane;Zansoa",
  [6529] = "Abigail Shiel;Andrew Hilbert;Belandiel Farflight;Christopher Hewen;Drake Lindgren;Felicia Doan;Felika;Flakk;Gina MacGregor;Gretta Ganter;Harn Longcast;Iallion Featherfall;Kireena;Kulwia;Lah'Mawhani;Martine Tramblay;Narret Shadowgrove;Nessa Shadowsong;Ranik;Shadi Mistrunner;Shimra;Tai'tasi;Tari'qa;Tharynn Bouden;Ullanna;Voloren;Wunna Darkmane;Zansoa",
  [6325] = "Gretta Ganter;Harn Longcast;Martine Tramblay;Nyalah Brightfire;Tharynn Bouden",
  [6326] = "Martine Tramblay;Nessa Shadowsong;Nyalah Brightfire;Zansoa",
  [5956] = "Abigail Shiel;Andrew Hilbert;Banalash;Belandiel Farflight;Billibub Cogspinner;Christopher Hewen;Drake Lindgren;Elisa Steelhand;Elizabeth Van Talen;Fanorran Stilloak;Felicia Doan;Felika;Flakk;Gina MacGregor;Iallion Featherfall;Jandia;Kelsey Fargo;Kireena;Kulwia;Lah'Mawhani;Lorelae Wintersong;Loslor Rudge;Micha Yance;Narret Shadowgrove;Neal Allen;Norzsh;Ranik;Sally Swiftwrench;Samuel Van Brunt;Shadi Mistrunner;Sheendra Tallgrass;Shimra;Tai'tasi;Tari'qa;Taur Stonehoof;Tharynn Bouden;Thrawn Boltar;Ullanna;Vartha Rockmane;Vivianna;Wunna Darkmane",
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
local function StepDone(i)
  local s = STEPS[i]
  if not s then return true end
  if (s.k == "accept" or s.k == "do" or s.k == "turnin") and s.q and blocked[s.q] then return true end
  -- only for the current step: a later quest's prerequisite may still come before it on the route
  if i == cur and s.k == "accept" and s.q and Blocked(s.q) then return true end
  if s.k == "chapter" then return true end
  if marks[i] then return true end
  -- (0.1.7) a quest left out for now (not offered yet): its do and turn-in steps go by, unless you took it
  if (s.k == "do" or s.k == "turnin") and s.q and ns._acceptSkipped and ns._acceptSkipped[s.q] and not InLog(s.q) then return true end
  -- (13.10., Daniel's hunter Don: "Elmore's Task" at level 7 stayed the step, it needs 9) once left out for its
  -- level it stays left out wherever the route stands, until the level is there
  if s.k == "accept" and s.q and ns._acceptSkipped and ns._acceptSkipped[s.q] and ns.TooLowFor and ns.TooLowFor(s.q) then return true end
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
      for _, q in ipairs(s.qs) do if not (QuestDone(q) or (InLog(q) and Complete(q))) then return false end end
      return true
    end
    local d = DUNGEON_BY_ID[s.id]
    if not d then return true end
    for _, q in ipairs(d.quests) do if not (QuestDone(q.q) or (InLog(q.q) and Complete(q.q))) then return false end end
    return true
  end
  if s.k == "learn" then return SkillRank(s.sk) ~= nil end
  if s.k == "use" then return SkillRank(s.sk) ~= nil end
  if s.k == "farm" then return ItemCount(s.i) > 0 or InLog(s.q) or QuestDone(s.q) end
  -- (11.10.) a vendor stop put in when the bags were full or the money short (Fit.lua ns.CheckSell)
  if s.k == "sell" then
    return (ns._merchantAt or -1e9) >= (s.t0 or 0) or (s.why == "bags" and ns.FreeSlots ~= nil and ns.FreeSlots() >= 4)
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
  if s.k == "bind" then
    local now = GetBindLocation and GetBindLocation()
    return bindAtStep ~= nil and now ~= nil and now ~= bindAtStep
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


-- Too low by now: a quest far below the character.
local function Outgrown(s)
  return IsQuestStep(s) and s.lv and s.lv > 0 and s.lv + GRAY <= Level() and not InLog(s.q)
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
  local moved = {}
  for k, v in pairs(marks) do if k ~= i then moved[k > i and k - 1 or k] = v end end
  marks = moved
  return true
end
local function Advance(initial)
  local guard = 0
  while cur <= #STEPS and guard < #STEPS do
    guard = guard + 1
    local s = STEPS[cur]
    if s._later and (StepDone(cur) or CantAfford(s.i)) then
      DropLater(cur)
    elseif StepDone(cur) or Outgrown(s) or (initial and not IsQuestStep(s) and LaterProgress(cur)) then
      cur = cur + 1
    elseif (s.k == "do" or s.k == "turnin") and s.q and not InLog(s.q) and not QuestDone(s.q) and not s._retake
        and not (ns._acceptSkipped and ns._acceptSkipped[s.q]) and ns.RetakeBefore and ns.RetakeBefore(cur) then
      -- (0.1.7) abandoned (a failed timed quest): its accept again, here (the loop looks at it now)
    elseif s.k == "accept" and ns.TooLowFor and ns.TooLowFor(s.q) then
      -- (0.1.7, Daniel 11.10.: "Break Sharptusk!" at level 2, the quest needs 3) the accept moves to the
      -- route's next visit of that NPC (the loop looks at the step that is here now); no later visit: it
      -- is left out for now, its do and turn-in steps too (StepDone)
      local movedOn = ns.MoveAcceptLater and ns.MoveAcceptLater(cur)
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
    elseif s.k == "buy" and ns.BuyWaits(cur) then
      -- (0.1.6 playtest 1, Daniel 10.10.: no money for the pick) the buy waits: a hint says what it costs,
      -- it comes back at the next vendor on the way that sells it once the money is there (never a detour)
      if db then db.buyLater = db.buyLater or {} db.buyLater[s.i] = { n = s.n, sk = s.sk, sp = s.sp, ck = s.ck } end
      cur = cur + 1
    else
      break
    end
  end
  if db then db.step = cur end
end

-- (0.1.5) what the bought thing is for
local BUY_HINT = {
  [393] = L["  (keep it in your bags: you need it to skin)"], [186] = L["  (keep it in your bags: you need it to mine)"],
  [356] = L["  (equip it to fish)"], [164] = L["  (you need it in your bags to forge)"], [202] = L["  (you need it in your bags to build)"],
  recipe = L["  (right-click it to learn it, then cook the fish you catch for Cooking)"],
  lure = L["  (use it on your fishing pole: more fishing skill for a while)"], -- (0.1.6) Shiny Bauble 6529
}
local LURES = { [6529] = true }


local function StepText(s, upcoming)
  if not s then return L["Route finished"] end
  local kind = Kind(s, upcoming)
  local verb = VERB[kind] or s.k
  if s.k == "accept" or s.k == "do" or s.k == "turnin" then
    local t = verb .. ": " .. (ns.QName(s) or (L["Quest "] .. s.q))
    if kind == "do" and InLog(s.q) then
      -- (0.1.3, Daniel 09.10.) the game's own objectives: "2/10 Kobold Vermin slain" instead of an estimate
      local open = OpenObjectives(s.q)
      if #open > 0 then t = t .. ":  " .. table.concat(open, ", ") end
    elseif s.k == "do" and s.kills then t = t .. (L["  (about %d mobs)"]):format(s.kills) end
    if s.k == "accept" and s.item then t = t .. L["  (starts from an item: Questdon's quest item button)"] end
    if s.ins then t = t .. L["  (inside the dungeon)"] elseif s.grp then t = t .. L["  (group quest)"] end
    if s.k == "accept" and s.esc then t = t .. L["  (escort: starts at once)"] end
    if s.k == "accept" and s.bc then t = t .. L["  (take it along: it leads to the next zone)"] end
    -- (13.10.) a hint players gave for this quest (STEP_NOTES)
    local note = s.q and ns.STEP_NOTES[s.q] and ns.STEP_NOTES[s.q][s.k]
    if note then t = t .. note end
    if s.k == "turnin" and s._book then
      t = t .. T.bookChoose:format(ItemName(s._book.i, GATHER_BOOK[s._book.sk].n), ns.PName(s._book.sk))
    end
    return t
  elseif s.k == "grind" then
    return (L["Grind to level %d (about %d mobs)"]):format(s.to, s.kills or 0)
  elseif s.k == "die" then
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
    if s.min then return (L["Run %s with a group (%d quests, about %d min)"]):format(s.n or "?", n, s.min) end
    return (L["Run %s with a group (%d quests)"]):format(s.n or "?", n)
  elseif s.k == "profs" then
    return verb .. L[" (up to 2 primary, all secondary; click here)"]
  elseif s.k == "learn" then
    return (L["Learn %s at the trainer"]):format(s.sk and ns.PName(s.sk) or s.n or "?")
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
      local t = used[PointKey(p)]
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
  if s.k == "die" and s.gm and s.gx then
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
  -- (0.1.7, Daniel 11.10.: "the arrow confuses when you are in the area killing the mobs") a do step brings
  -- its objective places: in their area Questdon shows "In the objective area" instead of the needle
  if t and Kind(s) == "do" and InLog(s.q) and a.ObjectivePoints then
    local pts = {}
    for _, p in ipairs(a.ObjectivePoints(s.q) or {}) do pts[#pts + 1] = { mapID = p.mapID, x = p.x, y = p.y } end
    if #pts > 0 then t.area, t.questID, t.points = true, s.q, pts end
  end
  -- (Daniel 11.10.: standing still it flipped between the needle and "In the objective area") the same
  -- quest's area target stays as it is: Questdon picks the nearest spot in it, a new table every 2 s
  -- with Leveldon's own spot made it jump
  local old = ns._arrowT
  if t and t.area and old and old.area and old.questID == t.questID and old.label == t.label and #old.points == #t.points then return end
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
  for _, b in ipairs(src and src.b or {}) do
    if not b.ck or cooking then
      out[#out + 1] = { k = "buy", i = b.i, n = b.n, v = b.v, sp = b.sp, ck = b.ck, sk = sk, m = b.m, x = b.x, y = b.y }
    end
  end
  return out
end

local MERGE_NEAR = 6 -- map percent (about 200 yards in Elwynn Forest)
local function IndexIn(list, obj) for i, s in ipairs(list) do if s == obj then return i end end end

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
-- visit of its quest giver after the learn; without one before the turn-in it stays (Wowhead Forever lists
-- no skill requirement for these quests, only the level: the quest waits in the log until the skill-up).
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
            if not turnins and t.sk == L.sk and t.k == "accept" and k < li and not acc then acc = k end
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
      if t then s = { k = "train", lvl = s.lvl, n = t.n, m = t.m, x = t.x, y = t.y, el = s.el, _i = s._i, _ho = s._ho } end
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
          out[#out + 1] = { k = "farm", q = root, i = f.i, n = ItemName(f.i, f.n), mob = f.mob, m = s.m, x = s.x, y = s.y, chain = not wantsBook }
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
    for _, c in ipairs(ROUTE.bonus and ROUTE.bonus[mg.root] or {}) do
      local found
      if c.m and c.x then
        -- (0.1.6 playtest 1, Daniel 10.10.: the book chain's quests stayed open while the route went on)
        -- at the same NPC or building as the chain's step before it: right behind it; an accept or turn-in
        -- at the route's next hub within NPC_NEAR (behind the hub, its order is sorted out below); a mob area
        -- with the route's own mobs within DO_NEAR (one visit, e.g. the kobolds of Echo Ridge); else the first
        -- step within PASS_NEAR (on the way to it when that is a mob area)
        local prevC = out[last]
        if NPC_KIND[c.k] and prevC and NPC_KIND[prevC.k] and Within(prevC, c, NEAR.npc) then
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
        table.insert(out, at + 1, { k = "learn", sk = e.sk, n = e.n .. " (" .. (e.npc or "?") .. ")", m = e.m, x = e.x, y = e.y, _early = true })
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
          t.learns = {}
          for _, e in ipairs(list) do
            planned[e[1]] = true
            if e[2] > 0 then t.learns[#t.learns + 1] = e end
          end
          table.sort(t.learns, function(a, b) return a[2] > b[2] end)
          last = t.lvl
          j = j + 1
        end
      else
        j = j + 1
      end
    end
    ns._trainDropped = dropped
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
            local moved = {}
            for k, val in pairs(marks) do moved[k > j and k + 1 or k] = val end
            marks = moved
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
  for i = 1, 40 do
    local name, expires = Buff("player", i)
    if not name then break end
    if name == ns.Bag.buff then return expires and expires > 0 and (expires - Now()) or ns.Bag.lasts end
  end
  if ns.Bag.at > 0 and Now() - ns.Bag.at < ns.Bag.lasts then return ns.Bag.lasts - (Now() - ns.Bag.at) end
  return nil
end
ns.SleepingBagHint = function() -- (tests)
  local left = ns.Bag.Left()
  return db ~= nil and db.bag ~= false and ns.Bag.Ready() and (not left or left < 600)
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
  for i = 1, 40 do
    local name, expires = Buff("player", i)
    if not name then break end
    if name == wellFedName then return expires and expires > 0 and (expires - Now()) or 900 end
  end
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
      local key = tr and ("train:" .. Key(tr))
      if tr and now - (hubAsked[key] or -1e9) >= H.every then
        hubAsked[key] = now
        table.insert(STEPS, last + 1, { k = "train", n = tr.n, lvl = lv - lv % 2, m = tr.m, x = tr.x, y = tr.y, _hub = true })
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
local function LogQuests()
  local out = {}
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
  local a = API()
  if not (a and a.ObjectivePoints and a.DistanceTo) then return nil end
  for _, q in ipairs(LogQuests()) do
    if q ~= (s and s.q) and not Complete(q) and #OpenObjectives(q) > 0 then
      local _, d = NearestObjective(q)
      if d and d < 120 then
        local name = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(q)
        alongName, alongObjs, ns._alongQ = name or (L["Quest "] .. q), OpenObjectives(q), q
        return alongName, alongObjs
      end
    end
  end
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
  -- (11.10., Daniel: "Kyle: nothing in the quest log", the game shows only "Kyle fed") what the game does not say
  local tip = s and s.q and (s.k == "do" or Kind(s) == "do" or s.k == "accept") and ns.QUEST_TIPS and ns.QUEST_TIPS[s.q]
  if tip then out[#out + 1] = { tip, "accent" } end
  -- (11.10., Daniel: "when an NPC patrols, that is important to know") Questdon saw it at places far apart
  local qa = (s and s.q and (s.k == "accept" or s.k == "turnin")) and API() or nil
  if qa and qa.QuestNpcWalks and qa.QuestNpcWalks(s.q, s.k == "turnin") then
    out[#out + 1] = { (s.k == "turnin" and L["The turn-in NPC"] or L["The quest giver"]) .. L[" walks around: look nearby"], "accent" }
  end
  -- (0.1.7) a trainer visit: what it teaches that counts (the most important first)
  if s and s.k == "train" and s.learns and #s.learns > 0 then
    local names = {}
    for k = 1, math.min(4, #s.learns) do
      local e = s.learns[k]
      names[#names + 1] = (SpellName(e[1]) or e[5]) .. (e[6] > 1 and (" " .. e[6]) or "")
    end
    local more = #s.learns - #names
    out[#out + 1] = { L["New: "] .. table.concat(names, ", ") .. (more > 0 and (L[" and "] .. more .. L[" more"]) or ""), "accent" }
  end
  if s and Kind(s) == "do" and InLog(s.q) then
    local _, d = NearestObjective(s.q)
    if d and d < IN_AREA then out[#out + 1] = { L["You are there: the mobs and objects are around you"], "good" } end
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
    elseif cls ~= "MAGE" and cls ~= "PRIEST" then
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
      out[#out + 1] = { (L["Dungeon %s fits your level (%d quests): /lvd dungeon to plan it, /lvd dungeon no to skip"]):format(d.n, #d.quests), "accent" }
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

-- (0.1.3, Daniel 09.10.) a looted item starts a quest with a chain behind it that the route left out
-- (a lucky drop): the chain goes in right after the current step
local function PlanBonus(root, label)
  db.bonusPlans = db.bonusPlans or {}
  for _, b in ipairs(db.bonusPlans) do if b.q == root then return false end end
  local at = 1
  for j = cur, 1, -1 do if STEPS[j] and STEPS[j]._i then at = STEPS[j]._i break end end
  table.insert(db.bonusPlans, { q = root, at = at })
  local here = STEPS[cur]
  Compose()
  for j, s in ipairs(STEPS) do if s == here then cur = j break end end
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
          local here = STEPS[cur]
          Compose()
          for j, s in ipairs(STEPS) do if s == here then cur = j break end end
          -- (12.10., Daniel in Northshire: "after the book dropped Leveldon sent me to the Brotherhood, I still had
          -- wolves to kill") the book's accept comes here, before the step you are on (it takes a click); the
          -- route goes on from that step afterwards instead of jumping past it
          for j = cur + 1, #STEPS do
            if STEPS[j].q == qid and STEPS[j].k == "accept" then table.insert(STEPS, cur, table.remove(STEPS, j)) break end
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
    if k and not QuestDone(k.q) then return k end
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
  for i, L in ipairs(ROUTE.links or {}) do
    for side, e in ipairs({ L.a, L.b }) do
      if e.m == here then
        local d = a.DistanceTo(e.m, e.x / 100, e.y / 100)
        if type(d) == "number" and d < TRAVEL_R then
          if dock and dock.i == i and dock.side ~= side then
            if now - dock.left < 1800 then
              LogTravel({ k = L.k, link = i, from = dock.side, s = math.floor(now - dock.left + 0.5),
                w = math.floor(dock.left - dock.arrived + 0.5), d = time() })
              print((L["|cff3fa9f5Level|rdon: %s took %d s (waited %d s), noted for /lvd export."]):format(L.k, now - dock.left, dock.left - dock.arrived))
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
    local f = CreateFrame("Frame", "LeveldonExport", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
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
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 8, -26)
    sf:SetPoint("BOTTOMRIGHT", -28, 8)
    local eb = CreateFrame("EditBox", nil, sf)
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
    if not found then for k = at + 1, #old do found = IndexIn(STEPS, old[k]) if found then break end end end
  else
    -- (0.1.6) chosen early (after the first quest): the route stays at its step, or the next one still in it
    for k = at, #old do found = IndexIn(STEPS, old[k]) if found then break end end
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
  Style.Row(p):SetMain(true):SetText(T.profsDone, BK.goldLight or "accent"):SetGapBefore(8)
    :SetOnClick(function() ApplyProfs(picked, false) end)
  Style.Row(p):SetMain(true):SetText(T.profsNone, BK.textSecondary or "textSecondary")
    :SetOnClick(function() ApplyProfs({}, true) end)
  Style.Row(p):SetText(T.profsFoot, BK.textHint or "textHint"):SetGapBefore(4)
  p:Relayout()
end
local function ShowProfs()
  if not profsPanel then
    profsPanel = Style.Panel("LeveldonProfs", UIParent, { look = "book", media = "Interface\\AddOns\\Leveldon\\Media\\",
      title = Style.Wordmark("Level", "don") .. T.profsTitle, width = 400, close = true,
      defaultPoint = { "CENTER", "CENTER", 0, 80 } })
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
    C_Timer.After(3, CheckProfsAtStart)
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
      if SkillRank(sk) and not set[sk] then set[sk] = true added[#added + 1] = ns.PName(sk) end
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
  C_Timer.After(2, ShowProfsEarly)
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
  local b = CreateFrame("Button", "LeveldonTrackerButton", host, BackdropTemplateMixin and "BackdropTemplate" or nil)
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
  panel:ClearRows()
  local Win = ns.LvdWin
  if Win then Win.Begin(panel) pcall(Win.Run, panel, STEPS, cur) end
  local ch = ChapterOf(math.min(cur, #STEPS))
  if ch then
    local plan
    for j = cur - 1, 1, -1 do if STEPS[j] and STEPS[j].el then plan = STEPS[j].el break end end
    if not (Win and pcall(Win.Banner, panel, ns.ChName(ch), ch.lo, ch.hi, math.min(cur, #STEPS), #STEPS, ChapterProgress(), plan, (panel._width or 360) - 2)) then
      Style.Header(panel, (L["%s  ·  level %d to %d"]):format(ns.ChName(ch), ch.lo or 0, ch.hi or 0))
    end
  end
  -- (Daniel 12.10.: "the done steps from before up top are too much") no stations behind you any more
  local s = STEPS[cur]
  local kind = Kind(s)
  local main = Style.Row(panel):SetMain(true):SetActive(true):SetText(StepText(s), B.textPrimary or "textPrimary")
  main:SetIcon(s and KIND_ICON[kind] or KIND_ICON.chapter, false, kind ~= "accept" and kind ~= "turnin" or nil)
  main:SetOnClick(s and s.k == "profs" and ShowProfs or (s and s.q and function() ns.OpenQuest(s) end) or nil)
  if Win then Win.Line(main, "now") pcall(Win.Now, main) end
  local m, x, y = Place(cur)
  if s and s.k == "die" and s.gm and s.gx then m, x, y = s.gm, s.gx, s.gy end -- (12.10.) the spirit healer
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
    if AlongHere(s) and ns._alongQ then
      along = { title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(ns._alongQ) or (L["Quest "] .. ns._alongQ),
        objs = ns.LvdObjList(ns._alongQ) }
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
  -- (0.1.8) the next level the plan reaches on the way: a gold diamond on the path
  local nextLv = Level() + 1
  for j = cur + 1, #STEPS do
    local n = STEPS[j]
    local isCh = n.k == "chapter"
    -- (playtest 1) a buy without the money is not "next": it waits (see the hint)
    if isCh or (not StepDone(j) and not Outgrown(n) and not (n.k == "buy" and ns.BuyWaits(j))) then
      if shown == 0 and not Win then Style.Header(panel, "Next") end
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
    if t.k == "accept" and t.q and not QuestDone(t.q) and not InLog(t.q) and not (ns._acceptSkipped and ns._acceptSkipped[t.q]) then
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
  for n, t in ipairs(moved) do table.insert(STEPS, at + n - 1, t) end
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
  if s0 and ((s0.k == "do" and s0.q and InLog(s0.q)) or s0.k == "grind" or s0.k == "skillup" or s0.k == "farm" or s0.k == "dungeon") then return false end
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
  for k = cur, to - 1 do
    local t = STEPS[k]
    if not StepDone(k) then
      marks[k] = true
      if t.k == "accept" and t.q and not InLog(t.q) then ns._acceptSkipped[t.q] = true end
    end
  end
  ns._recHow = "f"
  if ns.RecEvent then pcall(ns.RecEvent, "C", 0, cur, to) end
  cur = to
  if db then db.step = cur end
  print((L["|cff3fa9f5Level|rdon: you are ahead on the route; it goes on at \"%s\"."]):format(STEPS[cur] and (ns.QName(STEPS[cur]) or STEPS[cur].n) or "?"))
  ns.LF.seen, ns.LF.since, ns.LF.recent = STEPS[cur], Now(), {}
  return true
end
ns.LeveldonFollow = ns.LF.FollowPlayer -- (tests)
ns.LeveldonFollowClock = function(t) ns.LF.since = t end -- (tests)

function Update(initial)
  local before = cur
  if ns.CheckHub then pcall(ns.CheckHub) end
  if ns.CheckSell then pcall(ns.CheckSell) end
  Advance(initial)
  if not initial then
    pcall(ns.LF.ClassNow)
    local ok, moved = pcall(ns.LF.FollowPlayer)
    if ok and moved then Advance(false) end
  end
  if STEPS[cur] and STEPS[cur].k == "bind" and bindAtStep == nil then
    bindAtStep = GetBindLocation and GetBindLocation() or false
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
  if delta > 0 and DropLater(cur) then delta = delta - 1 end
  cur = math.max(1, math.min(#STEPS + 1, cur + delta))
  if delta > 0 then marks[cur - 1] = true end
  if delta < 0 then marks[cur] = nil end
  -- (11.10., Daniel: The Adventurer reported "giver not there", then Leveldon wanted it turned in: "I don't have
  -- the quest") an accept skipped without the quest: its do and turn-in steps go by too (StepDone), back undoes it
  ns._acceptSkipped = ns._acceptSkipped or {}
  if delta > 0 and from and from.k == "accept" and from.q and not InLog(from.q) and not QuestDone(from.q) then
    ns._acceptSkipped[from.q] = true
  elseif delta < 0 and STEPS[cur] and STEPS[cur].k == "accept" and STEPS[cur].q then
    ns._acceptSkipped[STEPS[cur].q] = nil
  end
  bindAtStep = nil
  if db then db.step = cur end
  if delta > 0 then Advance(false) end
  Arrow()
  pcall(MarkTick)
  Refresh()
end

ns.LeveldonRefresh = function() if panel then Refresh() end end -- (0.1.7 Resize.lua)
-- (0.1.7 Fit.lua) the steps built again, the current step kept
ns.LeveldonRecompose = function()
  local here = STEPS[cur]
  Compose()
  for j, s in ipairs(STEPS) do if s == here then cur = j break end end
  if db then db.step = cur end
  Update(false)
end
ns.LeveldonSkip = function(delta) Skip(delta) end -- (0.1.7 Report.lua: after a report the next step)
local function Build()
  panel = Style.Panel("LeveldonPanel", UIParent, {
    look = "book", media = "Interface\\AddOns\\Leveldon\\Media\\",
    title = Style.Wordmark("Level", "don") .. L["  |cff8a8f99beta "] .. VERSION .. "|r",
    width = 360, close = true, collapse = true, get = Get, set = Set,
    defaultPoint = { "TOPRIGHT", "TOPRIGHT", -260, -260 },
    buttons = {
      { kind = "forward", key = "next", onClick = function() Skip(1) end, tooltip = { L["Skip this step"], nil, "/lvd next" } },
      { kind = "back", key = "back", onClick = function() Skip(-1) end, tooltip = { L["One step back"], nil, "/lvd back" } },
      -- (0.1.7, Daniel 11.10.) report this step: quest giver not there, route makes no sense, a remark
      { kind = "report", key = "report", onClick = function() if ns.OpenReport then ns.OpenReport() end end,
        tooltip = { L["Report this step"], { L["Quest giver not there, route makes no sense, or a remark."] }, "/lvd report" } },
      -- (0.1.8, Daniel 12.10.) the whole quest to read; the speedrun line on and off
      { kind = "lvdRead", key = "read", onClick = function()
          local st, a = STEPS[cur], API()
          if st and st.q and a and a.ShowQuestText then a.ShowQuestText(st.q) end
        end, tooltip = { L["Read the whole quest"], nil, L["Shift-click a step: the same."] } },
      { kind = "lvdTimer", key = "run", onClick = function()
          if db then db.runLine = db.runLine ~= true end
          Refresh()
        end, tooltip = { L["Speedrun line"], { L["Your time on the route against the plan, the last level-ups, when the next level is due."] }, "/lvd run" } },
    },
  })
  if Get("shown") ~= false then panel:FadeIn() end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local f = CreateFrame("Frame")
local pending = false
local function Soon()
  if pending then return end
  pending = true
  C_Timer.After(0.3, function() pending = false Update(false) end)
end

f:SetScript("OnEvent", function(_, event, ...)
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
    if db.route ~= key then
      if type(db.route) == "string" and db.route:match("^[^:]*:[^:]*") ~= key:match("^[^:]*:[^:]*") then db.run = nil end
      db.route, db.step = key, nil
    end
    -- (13.10.) the recording session started on the same event may have read the route before it was loaded
    local rs = ns.RecSession and ns.RecSession()
    if rs then rs.route, rs.rid = db.route, ns.LeveldonRouteId() end
    Compose()
    Build()
    cur = db.step or StartIndex()
    C_Timer.After(2, function() Update(true) end) -- quest log and Questdon are ready by then
    sessionStart = Now()
    C_Timer.After(6, BagCheck)
    C_Timer.After(4, function() pcall(CheckLogChains) end)
    C_Timer.NewTicker(1, function() if panel and panel:IsShown() then Refresh() end pcall(MarkTick) end)
    -- (0.1.6) Blizzard's quest tracker: hidden again when the game shows it again (one alpha read)
    pcall(ApplyTracker)
    pcall(MakeLogButton)
    C_Timer.After(3, function() pcall(CheckProfsAtStart) end) -- (0.1.6) professions missing: the choice now
    C_Timer.NewTicker(0.5, function()
      if (db.hideTracker ~= false or trackerHidden) and not InCombat() then pcall(ApplyTracker) end
      if not logButton or logButton._rank > 1 then pcall(MakeLogButton) end
    end)
    C_Timer.NewTicker(2, function()
      pcall(TravelTick)
      if STEPS[cur] and Kind(STEPS[cur]) == "do" then pcall(MarkUsed, STEPS[cur].q) pcall(Arrow) end
    end)
  elseif event == "TAXIMAP_OPENED" then
    pcall(RecordIndoor)
    pcall(MarkInteract)
    if STEPS[cur] and STEPS[cur].k == "fp" then marks[cur] = true end
    Soon()
  elseif event == "TRAINER_SHOW" then
    pcall(RecordIndoor)
    pcall(MarkInteract)
    if STEPS[cur] and STEPS[cur].k == "train" then marks[cur] = true end
    -- (0.1.4) the class trainer: what this level brings is learned, later trainer stops up to it are done
    if db and not (IsTradeskillTrainer and IsTradeskillTrainer()) then db.trained = math.max(db.trained or 0, Level()) end
    Soon()
  elseif event == "CHAT_MSG_SYSTEM" then
    pcall(OnSystemMessage, (...))
    Soon()
  elseif event == "CHAT_MSG_SKILL" then
    pcall(OnSkillMessage, (...))
    Soon()
  elseif event == "CHAT_MSG_LOOT" then
    local msg = ...
    CheckKeep(msg)
  elseif event == "BAG_UPDATE_DELAYED" then
    pcall(CheckStarters)
  elseif event == "QUEST_ACCEPTED" then
    local a1, a2 = ...
    ns.NoteQuestEvent(tonumber(a2) or tonumber(a1)) -- (13.10.) FollowPlayer: quests taken while the step waits
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
    if STEPS[cur] and STEPS[cur].k == "die" and (event == "PLAYER_UNGHOST" or not (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player"))) then marks[cur] = true end
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
    if profsEarlyWaiting then C_Timer.After(1, ShowProfsEarly) end
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, _, spellID = ...
    local sname = SpellName(spellID)
    if unit == "player" and sname and (sname == SpellName(818) or sname == SpellName(1229737)) then campAt = Now() end
    -- (12.10.) the sleeping bag used: the 2 hours of Well-Rested start
    if unit == "player" and sname and GetItemSpell and sname == GetItemSpell(ns.Bag.item) then ns.Bag.at = Now() end
    if unit == "player" and spellID == 8690 and STEPS[cur] and STEPS[cur].k == "hearth" then marks[cur] = true end
    Soon()
  else
    Soon()
  end
end)
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_LOG_UPDATE",
  "PLAYER_LEVEL_UP", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "TAXIMAP_OPENED", "TRAINER_SHOW",
  "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_XP_UPDATE", "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "CHAT_MSG_SYSTEM", "SPELLS_CHANGED", "MERCHANT_SHOW", "CHAT_MSG_LOOT", "BAG_UPDATE_DELAYED",
  "GOSSIP_SHOW", "PLAYER_REGEN_ENABLED", "UNIT_QUEST_LOG_CHANGED", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE",
  "PLAYER_ALIVE", "PLAYER_UNGHOST" }) do
  pcall(f.RegisterEvent, f, e)
end

SLASH_LEVELDON1 = "/lvd"
SLASH_LEVELDON2 = "/leveldon"
SlashCmdList.LEVELDON = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if msg == "next" then Skip(1)
  elseif msg == "report" then if ns.OpenReport then ns.OpenReport() end
  elseif msg == "text" or msg:match("^text ") then if ns.TextCommand then ns.TextCommand(msg:match("^text%s*(.*)$")) end
  elseif msg == "rec" or msg == "rec on" or msg == "rec off" then if ns.RecCommand then ns.RecCommand(msg:match("^rec ?(.*)$")) end
  elseif msg == "route" then print("|cff3fa9f5Level|rdon: " .. routeInfo)
  elseif msg == "profs" or msg == "professions" then ShowProfs()
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
  elseif msg == "run" or msg == "run reset" then
    -- (0.1.8) the speedrun line: on and off; "reset" starts the clock again where the plan has you now
    if msg == "run reset" then db.run = nil else db.runLine = db.runLine ~= true end
    Refresh()
  elseif msg == "export" then ShowExport()
  elseif msg == "share" or msg == "share on" or msg == "share off" then if ns.ShareCommand then ns.ShareCommand(msg:match("^share ?(.*)$")) end
  elseif msg == "dungeon" or msg == "dungeon no" then
    local lv = Level()
    for _, d in ipairs(ROUTE.dungeons or {}) do
      if lv >= d.lo and lv <= d.lo + 6 and not (db.dSkip and db.dSkip[d.id]) and not (db.dTaken and db.dTaken[d.id]) then
        if msg == "dungeon no" then
          db.dSkip = db.dSkip or {} db.dSkip[d.id] = true
          print("|cff3fa9f5Level|rdon: " .. d.n .. L[" skipped."])
        else
          db.dTaken = db.dTaken or {} db.dTaken[d.id] = true
          -- after the current step of the route (its index in the route itself)
          local at = 1
          for j = cur, 1, -1 do if STEPS[j] and STEPS[j]._i then at = STEPS[j]._i break end end
          db.dPlans = db.dPlans or {}
          table.insert(db.dPlans, { id = d.id, at = at })
          Compose()
          for j, s in ipairs(STEPS) do if s.dg == d.id then cur = j break end end
          Update(false)
          print("|cff3fa9f5Level|rdon: " .. d.n .. L[" planned: pick up its quests, find a group, turn them in."])
        end
        break
      end
    end
  elseif msg == "dungeons" or msg == "dungeons on" or msg == "dungeons off" then
    -- (12.10.) the route with the dungeons of your faction planned in (1 to 30), or without
    if msg ~= "dungeons" then db.dungeons = msg == "dungeons on" end
    if msg ~= "dungeons" then
      LoadRoute()
      Compose()
      Build()
      cur = StartIndex()
      Update(true)
    end
    print("|cff3fa9f5Level|rdon: " .. (db.dungeons and L["dungeons planned in (/lvd dungeons off)"] or L["no dungeons (/lvd dungeons on)"])
      .. (db.dungeons and not ROUTE.withDungeons and L[", none planned for this character yet"] or "") .. ".")
  elseif msg == "solo" then
    db.solo = not db.solo
    Compose()
    cur = math.min(cur, #STEPS)
    Update(true)
    print(L["|cff3fa9f5Level|rdon: solo "] .. (db.solo and L["on: no group and escort quests"] or L["off"]) .. ".")
  elseif msg == "back" then Skip(-1)
  elseif msg == "reset" then
    marks, bindAtStep = {}, nil
    cur = StartIndex()
    Update(true)
    print(L["|cff3fa9f5Level|rdon: route started again from your level."])
  elseif panel then
    if panel:IsShown() then panel:FadeOut() Set("shown", false) else panel:FadeIn() Set("shown", true) Refresh() end
  end
end
