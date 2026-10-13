# Changes

## 0.2.1 Beta

- **Deliveries on the way:** a quest you only hand in somewhere else is taken where it costs the least walking, for example Rest and Relaxation on the way out of Northshire.
- **Items for later quests:** an item a later quest of your route needs says so in its tooltip (also drops the quest data does not name, like Hops or apples), and a vendor window lists the ones in your bags so you do not sell them.
- **Kill counts from real drop rates:** the plan counts the kills an item needs with Wowhead's drop rates instead of a flat guess, so the times and level milestones fit better (quests with rare drops take longer now).
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
