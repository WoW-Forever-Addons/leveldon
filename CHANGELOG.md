# Changes

## 0.2.5 Beta

- **Open data only:** the trainer spells per level and their prices, the shop prices and the group quests now come from open sources (What's Training, ForeverDB, the open Classic database CMaNGOS, All The Things) and from what players record. A few spells without a name in these sources show the game's own name.

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
