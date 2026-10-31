# Changes

## 0.2.9 Beta

- **New required addons: DonData and DonMap. Questdon is now optional.** Leveldon reads its quests from **DonData** and points the way with **DonMap**. The CurseForge app installs both for you. If you install by hand, download DonData and DonMap too and put their folders next to Leveldon in `Interface\AddOns`, or Leveldon does not load.
- **Update note:** new files, so restart the game after updating (a /reload is not enough).
- **Leveldon without Questdon:** with DonData and DonMap alone the route works: DonMap's arrow leads to the step, in an objective area to its nearest spot, the needles above the NPCs show whom you need, and dungeon names are in your game language. Questdon adds its quest list, its map pins and Leveldon's options window (without Questdon use the /lvd commands).
- **Arrow instead of the compass by default:** the separate arrow (Questdon's or DonMap's) now leads the way and the step list stays clean. The compass in the current step is still there: switch it on under Options > Window. If you had switched the compass on yourself, it stays on.
- **Abandoned quests:** a quest you abandoned gets its "take the quest" step back after the route is rebuilt (talent point, trainer).
- **Lighter:** one timer instead of five, the window does not rebuild while hidden, markers every 2 seconds, and only the route texts of your own class are loaded (Humans 854 KB down to 408 KB).
- **Recording stays on:** the recording of your run helps make the routes better; `/lvd rec off` switches it off.
- **Shared base:** the window style comes from DonCore, the common base of the Don addons. It looks the same.

## 0.2.8 Beta

- **Quests instead of grinding:** the routes now follow the way the popular Forever guides level. Alliance (Human, Dwarf, Gnome, Skyborne): Darkshore at 14 to 19 (boat from Stormwind), then Redridge, Ashenvale and Stonetalon, Wetlands and Duskwood; Skyborne skip Loch Modan. Night Elves and the Horde got new chapters in the same spirit. Grinding on the way to 30 drops from several hours to almost nothing for the Alliance and mostly under two hours elsewhere, with many more quests handed in (and the reputation that comes with them).
- **No quests below their level:** from level 6 you do a quest's objectives when you have reached its level, one level above when that costs little.
- **Levels 30 to 50 (preview) rebuilt:** this band now knows which quests you already handed in on the way to 30 and no longer plans them again. Faster for most Alliance races.
- **Quests you took but never handed in** at the end of 1 to 30 are no longer taken; Vital Intelligence is handed in in Brill instead of being dropped.
- **Items for later show how many:** the tooltip, the loot line in chat and the vendor hint say, for example, "8 needed later".
- **Trainers:** Dwarf shamans get trainer stops; every race visits its trainer once around level 55; Orc and Troll warlocks train in Orgrimmar instead of the Undercity; a few small trainer stops added.
- **Flight paths:** more flights where they end the route sooner.
- **Mor'Ladim and Look To The Stars** move to 30 to 50 (with an "Elite" hint); a hint at the grind before 30 tells Alliance players they can go on with the next chapter from 29.
- **Quest names** without leftover tags like [CATA+], [A] or [H].
- Selling stops that meant a trip there and back with the hearthstone are gone (Skyborne Horde, Tauren).

## 0.2.7 Beta

- **Druids to Moonglade by Teleport:** Night Elf and Tauren druids cast Teleport: Moonglade instead of walking there (a new step "Cast Teleport: Moonglade", done when you cast it). Druid routes end sooner: Night Elves about 20 to 50 minutes, Tauren about 47 to 84.
- **Leaving Moonglade:** where no hearthstone follows, a hint points to the druid flight master in Nighthaven, who flies you to Rut'theran Village or Thunder Bluff for free.
- **Class trainers added:** Undead paladins train with Aramis Hammerhand (Deathknell), Garen Largo (Undercity) and Alodan the Hopeful (Thunder Bluff), only where the route passes anyway. Skyborne hunters, mages, rogues and shamans train on Zephras Isle (Thendal Village, Shen'dar Village). These routes take a few minutes longer for it.
- **Stonetalon Peak (Night Elves):** a hint to fly back to Astranaar after Journey to Stonetalon Peak instead of walking down the mountain.
- Some class trainer data from ForeverDB (https://foreverdb.net, GPL v3).

## 0.2.6 Beta

- **Your language:** Leveldon now speaks French, Spanish (Spain and Latin America), Brazilian Portuguese, Russian, Korean and Traditional Chinese, besides English and German.
- **Window settings:** Options > Window > More settings now has lock, size, background opacity and dim in combat, as in Questdon, plus a button to put the window back to its starting place.
- **Arrow instead of the compass:** Options > Window: Questdon's direction arrow leads you to the step instead of the compass in Leveldon's window and in the quest list (needs Questdon 1.3.11); switched off again, everything comes back as it was. "Arrow: no background and frame" hides the plate behind the arrow's text.
- **See-through by default:** the window has no background and frame now unless you switch them on (Options > Window > "No background and frame"); the same for the arrow's plate.
- **A key for the window:** Key Bindings > AddOns > Leveldon > "Show or hide the window" (a new file, so restart the game after updating).
- **Only record your run:** one switch hides the window and Leveldon's markers, bag frames and reminders while the recording and the shared route times go on. A second click brings everything back. Options > Sharing and data, or /lvd quiet.
- **Quicker routes:** quests the old routes took and then dropped come back where they pay off, for example Timberling Sprouts, The Coast Isn't Clear, Satyr Horns, Souvenirs of Death and Sharptalon's Claw, and Philmor's Favor in Stormwind for the Alliance. Most class routes end sooner (about 10 minutes, up to 37), none later.
- **Tauren shamans** now get their earth totem: Call of Earth comes in at level 4 in Camp Narache.
- **Quests next to their giver** are done right after you take them (Unwelcome Guests, The Great Outdoors, Hilary's Necklace, Trouble in the Valley and others).
- **Zephras Isle (Skyborne):** Anchors right after you take it, then an east loop with the Windstones on the way; warriors get The Warrior's Path.
- **Selling:** full bags never send you on a detour; you sell at the next hub or at a vendor right by your way. Only a hunter without ammo goes out of the way.
- **Profession books:** a book that was in your bags and is gone counts as read.
- **Humans:** priests buy the Skin of Sweet Rum in Goldshire and stop in Stormwind at level 18; the kobolds for Shhh! are done on the way to Goldshire; hints for the Grape Manifest and the Mining Pick.

## 0.2.5 Beta

- **Choose your route:** after your start area, level through any other start area of your side (Options > Route or `/lvd line`), with the hours, quests and reputation of each choice. You can switch in the middle of the route.
- **Routes rebuilt:** one route per race with your class's quests and trainers laid in where they cost the least walking, shorter ways between the steps, the corrections from playtests kept. Quests you take and drop again on the way are handed in where it pays, Rest and Relaxation comes at the end of Northshire.
- **Step list:** scrolls with the mouse wheel and a slider; on top the current step and what you can do right here, below the steps to come. The header is tidier (step n of m in the chapter).
- **Bags:** items a later quest needs get a frame in your bags, so you do not sell them.
- **Selling:** a fixed stop at the vendor when you are at a hub anyway, at one who repairs when one is near; vendors only close to your way. At an inn the hearthstone comes first.
- **Dying on purpose:** when you are not yet at the place where a death brings you to the right spirit healer, Leveldon leads you there first, then says to die.
- **Skipped a profession's training?** Its buys, skill-ups and Camping 101 steps go by as well.
- **Trainer spells by name:** talent ranks and Forever's new spells (Mind Flay 2 to 6, Penance, ...) are named and weighed like the others.
- **Open data only:** trainer spells, prices, shops, group quests and the routes come from open sources (What's Training, ForeverDB, CMaNGOS, All The Things) and from what players record.
- **Player reports worked in:** Call of Earth for orc and troll shamans at Spirit Rock in Durotar (not Mulgore), the shaman quest done together with the Burning Blade cave, a death in the cave back to the Valley of Trials, Tundra MacGrann's Stolen Stash only from level 10, no hearthstone on Zephras Isle before you bind it.
- **Lighter:** fewer new tables while you play; `/lvd mem` shows Leveldon's memory by part.

## 0.2.4 Beta

- **Options window:** the cog in Leveldon's title bar (or /lvd options) opens Leveldon's settings in Questdon's look, with tabs for the window, the route, sharing and help. Needs Questdon 1.3.9.
- **Without background and frame:** an option for a clean window that shows only the text.
- **Timed quests:** a timed quest is done and handed in right after you take it; Leveldon no longer sends you to other mobs while its clock runs.
- **Murlocs and other packs later:** quests against mobs that come in packs (murloc tribes, Defias) are planned a bit later, when you can handle them (Hides for the Forsaken from level 10).
- **Routes rebuilt:** quests you would take a whole level too early are left out unless the route comes back later, and the walking between a quest's objective places counts in the plan.
- **Professions window:** in front of the options window, with "No professions" and "Done" as two buttons side by side.
- **Step menu:** a long step text no longer covers "Skip this step".
- **Lighter:** the window is only drawn anew when something changed, so Leveldon makes far less new memory.
- **The speedrun line is left out** for now.

## 0.2.3 Beta

- **Compass with Questdon:** with Leveldon's window closed, Questdon's compass leads to your own quest again instead of Leveldon's step; in an objective area Leveldon's compass shows "In the objective area" instead of an empty distance.
- **Trainer levels:** Shred and Seal of Fury at the levels WoW Forever's trainers teach them (20 and 26).
- **Skip a quest:** right-click the current step for a small menu: skip this step, or skip the whole quest (taking, doing and handing in go by). One step back brings the quest back.
- **Routes rebuilt with the newest quest data:** new quests in Teldrassil, Darkshore, the Barrens and Duskwood, the Mulgore chains in the right order.
- **Faster routes:** low quests that cost more walking than they bring are left out (for example the three Stormwind deliveries at level 9), a few flight points are taken when you pass close by (Lakeshire, Darkshire, Auberdine), quests that want the same mobs are done together where it saves time, and the order of the steps is searched through again and again for shorter ways (finished quests are collected and handed in together when you come by anyway, never carried past their NPC). Quests the route would never hand in are no longer taken, and the hearthstone is only used when it is ready again. The 30 to 60 preview got real drop rates and the same treatment.
- **Money for training first:** professions come in the route where the money for your next class training is left over (no more "learned professions in Goldshire, no silver for the trainer"), and a learn step tells you how much to keep when your real money is short, so you can skip it for now.
- **Riding at 40:** a step at the riding trainer (120 gold; paladins and warlocks 100 gold, their mount comes with the class quest). Without the gold the route goes on on foot and Leveldon tells you in the chat once you have it.
- **Saving mode at the trainer:** Leveldon sends you to the class trainer only for the main spells and recommends them with their price (in the step and in the chat at the trainer). Everything else is your choice, so the gold goes to riding. The recommendation follows your talents: a fire mage gets Fireball, a balance druid Wrath and Moonfire, an elemental shaman Chain Lightning.
- **Gathering reminder:** an herbalist, miner or skinner sees "Pick herbs on the way: Herbalism 7 of 20" from early on, so the 20 for Camping 101 come along the way.
- **Drops that start a quest:** a kill step says when a mob there drops the start of a quest (for example Croaky in Elwynn Forest or Gruff Swiftbite near Westbrook), elites marked as such.
- **Buying goes on at once:** a buy step is done as soon as the items are in your bags.
- **Arrow to the turn-in:** right after you finish a quest's objectives, the arrow points at where you hand it in.
- **Group quests marked:** elite group quests like Book Return and Rare Books say "(group quest)" in the step, also in the book chain; with /lvd solo the chain stops before them.
- **Quests that are not offered left out:** the Scourge invasion quests of every capital (Investigate the Scourge of Stormwind, Ironforge, Orgrimmar and the others) and, for mages, Research Access.
- **Steps that were done early go by:** a hearthstone set, a flight path learned or a hearth already at home one step before the route asks for it no longer holds the route; a skipped quest stays skipped after a /reload, and a dungeon run does not wait for a quest of it you skipped.
- **Following you when you play ahead:** a quest still in your log keeps its turn-in, and the route does not jump while you work on a quest.
- **Trainer:** spells you could not pay at one visit are recommended again at the next, and spending talent points changes the recommendation at once. The pet trainer no longer counts as your class training.
- **The route keeps its place:** no more jumps over open steps after a visit to your trainer, a talent point or choosing professions; after a /reload you are on the same step (also a vendor or tool buy), and steps you skipped stay skipped.
- **Quests left out come back:** a quest left out because you were a level short, or because its prerequisite was not done yet, comes back once you can take it.
- **More realistic plan:** kill counts follow what players really needed (items the same mobs drop count once, drop chances seen in play), kills at levels 6 to 10 take longer, quests no route can finish or that are never offered are left out, and Camping 101 First Aid and Fishing come after learning the skill.
- **Fixes:** two quests above your level at the same NPC no longer move behind each other again and again; no trainer or innkeeper of the other faction in the route; quests that are only possible before their follow-up, after their dungeon run or as one of two choices are in the right order (or one of them left out); class quests are no longer pulled from far ahead; professions you drop in the list stay dropped; the riding reminder waits for level 40; a second Leveldon window no longer opens when switching dungeons; the sleeping bag reminder knows its time after a /reload.

## 0.2.2 Beta

- **Levels 30 to 60 as a preview:** the routes go on to level 60. That part is not tested yet, and the window says so.
- **Back after a login:** Leveldon starts at the step where you logged out (it was a few steps further when it had added trainer or vendor stops while you played), also after a route update.
- **A step back stays:** when you go back a step, Leveldon no longer jumps forward again by itself.
- **Trainer at the right time:** no walk back to the trainer when the route passes one of your class before its next fight; quests right where you stand come first.
- **Smoother start areas:** what you just finished is handed in before new quests are taken, Camping 101: Cooking is handed in right after learning Cooking, and quest items are bought as late as it makes sense (in Northshire and Goldshire, for example Rest and Relaxation as you leave, the fishing bait in Stormwind).

## 0.2.1 Beta

- **Deliveries on the way:** a quest you only hand in somewhere else is taken where it costs the least walking, for example Rest and Relaxation on the way out of Northshire.
- **Items for later quests:** an item a later quest of your route needs says so in its tooltip (also drops the quest data does not name, like Hops or apples), and a vendor window lists the ones in your bags so you do not sell them.
- **Kill counts from real drop rates:** the plan counts the kills an item needs with the item's drop rate instead of a flat guess, so the times and level milestones fit better (quests with rare drops take longer now).
- **Buy on the way what a quest wants:** items a quest wants handed in that a vendor sells (bait, spices, drinks, apples) are bought at a stop on the way before you take the quest, so you hand it in right away instead of searching.
- **Packs only above their level:** murlocs and Defias, which come in groups, are planned once you are above their highest level; the mine quests of a cave are done in one go.
- **Class quests right away:** once you have the level of a class quest of your route (the hunter's pet, the warlock's Voidwalker, the druid's bear, totems, stances), it comes next with its follow-ups; only the turn-ins right where you stand come first.
- **Leveldon follows you:** when a step waits for 10 minutes while you take or hand in quests that come later on the route, the route goes on from there and says so in the chat.
- **Professions learned later:** chose "none" and learned Cooking or Fishing anyway? Their steps come into your route by themselves.
- **Quests above your level stay out:** a quest you cannot take yet is never left as the current step.
- **Vendor stops for hunters:** below 100 arrows or bullets Leveldon sends you to the nearest vendor that sells them, whatever step you are on. The 200 arrows you start with no longer send you there, and grey loot alone only counts from level 4.

## 0.2.0 Beta

- **First public beta:** routes for levels 1 to 30 for every race and class, with quests, flight points, hearthstone, trainers and vendors. Needs Questdon 1.3.6 or newer.
- **New window:** chapter header, an optional speedrun line (/lvd run: your time against the plan, pauses when you do nothing), the current station with Questdon's compass and the objectives as small blocks, the next steps and level milestones. Handle at the bottom right for its size, Ctrl + mouse wheel for the text size, Shift + mouse wheel for the background.
- **Trainers and vendors on every hub visit:** your class trainer and the hub's vendor become steps of the visit when it is worth it (new skills; grey loot, full bags, worn gear or ammunition).
- **Needles over the NPC whose turn it is:** colour by kind (take, turn in, trainer, vendor, flight master and inn, named mobs). Needs the nameplates of friendly NPCs.
- **Sharing and export:** Leveldon shares how long steps take, which ones are skipped and report reasons with other Leveldon players (numbers only, through Questdon's channel, guild and group). /lvd export gives a text with your reports and notes to paste into a comment.
- **Fixes from the playtests:** a quest item that drops no longer makes the route skip the step you are on; the Nibbled-On Book in Northshire is farmed by everyone; Goldshire and Kharanos send you to the real innkeeper.
