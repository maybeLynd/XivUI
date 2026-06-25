<div align="center">

### XivUI for Final Fantasy XI

</div>

---

## Table of Contents

- [Installation](#installation)
- [Components](#components)
- [Themes](#themes)
- [Commands](#commands)
- [First load & data files](#first-load-and-data-files)
  - [Hotbars start empty](#hotbars-start-empty)
  - [XivUI Menu](#xivui-menu)
- [Icon Picker](#icon-picker)
  - [XivUI Menu Config](#xivui-menu-config)
  - [XivUI Hud Layout](#xivui-hud-layout)
  - [FFXI Theme](#ffxi-theme)
- [Tooltip](#tooltip)
- [Hotbar, StatusBar, ExpBar](#hotbar-statusbar-expbar)
- [Choice Hotbar](#choice-hotbar)
- [Castbar](#castbar)
- [TargetBar, Weakness Strip, Buff/Debuff Strip, Drops](#targetbar-weakness-strip-buff-debuff-strip-drops)
- [Skillchain and Dps Parser](#skillchain-and-dps-parser)
- [Additional Info](#additional-info)
- [Hotbar Sets](#hotbar-sets)
- [Patch Notes](#patch-notes)
- [Credits](#credits)

---

<details open>
<summary><strong>About XivUI</strong></summary>

<br>

A Final Fantasy XIV style UI for **Final Fantasy XI** that I have been working on for myself and friends. Because of that, it probably has a lot of our personal preferences tied into it.

I love FFXI and have played for 18+ years, with my humble beginnings as a taru starting on Ps2. I am currently on my second account after retiring the first one to start over with friends. The primary purpose of this addon was to attract friends of mine into playing FFXI that had never tried it prior or that have and are returning after a long absence. While I love FFXI's long standing history, I love playing with my friends more and so I made the UI somnething they are more familiar with which is FFXIV.

The large surge of players FFXI has been seeing made me feel that maybe this would benefit more than my friends and I so I decided to make it public for anyone to use. 
I will, of course, do my best to work out any bugs that are found when I can. Please understand if there are any delays with bug fixes, as I’ve been working on this during my free time after work, when I’m not working on other projects, or when I’m just getting my gaming on.

This merges and reskins a set of classic FFXI UI addons into one addon with an in-game config menu, along with some custom additions for a few of them with a focus on recreating as much of the FFXIV placements/visuals as possible.

> [!WARNING]
> I play with DgVoodoo and the Windower Large Address Aware on so it's possible that performance can vary depending on machine.

</details>

---

<details open>
<summary><strong>A Small Detour</strong></summary>

<br>

There were also some moments where I really had to do some soul-searching after realizing I had wasted a bunch of time working on something that already existed. Imagine my surprise when I was introduced to XIUI on Ashita, as someone who had only ever heard of and used Windower. Or when I started from Enemybar through Windower and began adding things I wanted to Enemybar, like seeing buffs on allies, cast bars, sub-targets, and more, then named it Targetbar because it was no longer only about handling enemy HP bars. It had become something that did more for whatever you were targeting. Then someone tells me, “Hey, you know there’s actually already a Targetbar that does a good amount of this.”

</details>

---

<details open>
<summary><strong>Why I Finished It Anyway</strong></summary>

<br>

Ultimately, I decided to stick with it anyway and finish what I was working on. I hope that at least some of you who find yourselves here think this addon is cool. If this helps any newcomers to FFXI settle in and endjoy the game or bring others in then I'd be proud to play my part. If not, there are myriad other awesome addons out there waiting to be found, made by the awesome community FFXI has harbored!

</details>

---

<a id="installation"></a>
## Installation

1. Copy the `XivUI` folder into your Windower `addons` directory:
   ```
   Windower4/addons/XivUI/
   ```
2. In the Windower console (press **Insert** in game), load it:
   ```
   lua load xivui
   ```
3. Open the configuration menu and tune anything you like:
   ```
   //xivui menu
   ```

To reload after changing files: `lua r xivui`. For a fast hotbar reload: `//htb reload`.

Everything you need to start is included. On first load XivUI will create its settings from defaults and makes a character folder for your hotbars automatically.

Then run: `//xivui menu` to get started with anything ranging from using the action panel to assign abilities/spells on your hotbar, change configs, or adjust the hud layout to your liking.

---

<a id="components"></a>
## Components

| Component | What it does |
|-----------|--------------|
| **statusbar** | HP / MP / TP main bar |
| **expbar** | Experience bar with optional EXP/hr |
| **targetbar** | Target HP bar, buff/debuff strip, and skillchain display |
| **xivparty** | FFXIV style party / alliance list / pet list |
| **xivhotbar3** | Multi row hotbars with auto generation, choice slots, and saved sets |
| **aggrolist** | Enmity / aggro list |
| **dps** | DPS parser |
| **requestwindow** | Party invite and trade request popups |
| **notification** | Loot toast messages |
| **castbar** | Spell cast + auto-attack timing bars |
| **enemyloot** | Drop / steal / despoil list for the current target |
| **enemyweak** | Elemental weakness / resistance readout for the current target |

Each component can be toggled on or off from **Config/Components** (or `//xui enable <name>` / `//xui disable <name>`).

---

<a id="themes"></a>
## Themes

XivUI ships with two visual themes, selectable in **Config/Theme** or with `//xui theme <name>`:

- **FFXIV** — a Final Fantasy XIV theme (default)
- **FFXI** — a Final Fantasy XI theme

---

<a id="commands"></a>
## Commands

Command prefixes: `//xivui`, `//xui`, `//htb`, `//xivhotbar`, `//xivhotbar3`.

See [`COMMANDS.txt`](COMMANDS.txt) for the full component command reference. Start with:

```
//xui menu              open the configuration menu

```

---

<a id="first-load-and-data-files"></a>
## First load & data files

- **`data/<component>/settings.xml`** — each component writes its own settings file from defaults the first time it loads (theme = FFXIV, plus the default on/off states). The `data/` folder is created automatically.
- **`cache/`** — created the first time a component needs to cache something (e.g. enemy loot you observe, learned debuff durations).
- **`components/xivhotbar3/data/<CharacterName>/`** — a character hotbar folder, created automatically the first time each character logs in.

<a id="hotbars-start-empty"></a>
### Hotbars start empty

You build them in the **XivUI Menu** (`//xui menu`):

- **AUTOGEN** tab: autofills bars from your learned actions, per job.
- **ACTIONS / MACROS / CHOICE** tabs: drag individual actions, macros, or choice groups onto slots.

Character files (`<job>.lua`, `General.lua`, `autogen_settings_<JOB>.lua`, `layout_<JOB>.lua`, `subjobs.lua`, `weaponsets.lua`, `trust_choices.lua`, `mode.lua`, the `sets/` folder, etc.) are created the first time you use the feature that needs it.

---

<a id="xivui-menu"></a>
### XivUI Menu

<img width="1243" height="733" alt="image" src="https://github.com/user-attachments/assets/309d05f7-4828-4851-bb18-394f1f98c79c" />
<img width="1233" height="733" alt="image" src="https://github.com/user-attachments/assets/3ac29628-97ed-4fcf-8871-618f478a4ee7" />

<a id="icon-picker"></a>
## Icon Picker

<img width="790" height="664" alt="image" src="https://github.com/user-attachments/assets/edba11dd-9f1b-40ee-9ab1-11f045cd1a43" />

<a id="xivui-menu-config"></a>
### XivUI Menu Config

<img width="1243" height="733" alt="image" src="https://github.com/user-attachments/assets/b081c61c-0309-4b27-9c38-92012c7ad28a" />

<a id="xivui-hud-layout"></a>
### XivUI Hud Layout

<img width="2557" height="1440" alt="image" src="https://github.com/user-attachments/assets/8e687555-f8c7-4f62-8c9f-e40a420eafbf" />

<a id="ffxi-theme"></a>
### FFXI Theme

<img width="2560" height="1438" alt="image" src="https://github.com/user-attachments/assets/a1b95988-b063-48e5-8062-2bdc03326646" />

<a id="tooltip"></a>
## Tooltip

<img width="985" height="445" alt="image" src="https://github.com/user-attachments/assets/1c1fceb4-5435-41f3-9780-1cac6ca609f8" />

<a id="hotbar-statusbar-expbar"></a>
## Hotbar, StatusBar, ExpBar, Hotbar Sets

<img width="886" height="219" alt="image" src="https://github.com/user-attachments/assets/afde31ff-78bd-46a2-adcf-0f6bc51ac5b0" />

<img width="214" height="250" alt="image" src="https://github.com/user-attachments/assets/e9b5f4c5-a012-4e26-bfe1-b91b0d8af3f3" />

<a id="choice-hotbar"></a>
## Choice Hotbar

<img width="781" height="244" alt="image" src="https://github.com/user-attachments/assets/7e530618-db2f-4214-9d31-71c64420bac7" />

<a id="castbar"></a>
## Castbar

<img width="220" height="61" alt="image" src="https://github.com/user-attachments/assets/4f872f13-46ca-4713-a489-165c215cdece" />

<a id="targetbar-weakness-strip-buff-debuff-strip-drops"></a>
## TargetBar, Weakness Strip, Buff/Debuff Strip, Drops

<img width="1252" height="105" alt="image" src="https://github.com/user-attachments/assets/14908ddc-231f-4969-806c-2629ccd93174" />

<img width="1219" height="112" alt="image" src="https://github.com/user-attachments/assets/0b46fb4b-59f0-42bb-a4d5-14c448c96514" />

<img width="1249" height="67" alt="image" src="https://github.com/user-attachments/assets/6db0eebe-579f-4915-9f10-2274e18fcd23" />

<img width="742" height="157" alt="image" src="https://github.com/user-attachments/assets/70d608ea-8a44-4c98-8238-3507293bcb17" />

<img width="403" height="388" alt="image" src="https://github.com/user-attachments/assets/50dd7906-4983-4d3a-8132-16a756629ac7" />

<a id="skillchain-and-dps-parser"></a>
## Skillchain and Dps Parser

<img width="397" height="192" alt="image" src="https://github.com/user-attachments/assets/3679abba-0e61-48cd-accf-1458a4cb2ea2" />

<img width="711" height="262" alt="image" src="https://github.com/user-attachments/assets/9cc8cf31-1391-4968-94d7-e472c3a88306" />

<a id="additional-info"></a>
## Additional Info

---

<details open>
<summary><strong>XivUI Menu</strong></summary>

<br>

<details open>
<summary><strong>Actions</strong></summary>

The actions panel displays the categories of what the combination of your Main/Sub job can use.

It will display job abilities, spells, weaponskills for weapons currently equipped, trusts, and things that have decision making such as individual summons, individual blood pacts, wards, rune fencer runes, etc.

You can drag the icons on to your hotbar to assign the selected action.

You can double click an icon to change the icon of the ability and add your own to the assets folder (or delete the ones you have no need for) to use with the Icon Picker.

</details>

---

<details open>
<summary><strong>Macros</strong></summary>

Lets you build a ability, spell, weapon skill, item use, and gear use applying a target and then choosing from an action by clicking on the box below Action. This opens a list of available actions your current job setup has access to.

Item assignation opens up a list of items in your inventory that the game considers usable.

With Gear use you can choose the slot of the equipment and it will populate a list of gear that the game considers usable.

For Command and Macros there is a .txt file with location printed on screen. You can type in the corresponding section in the .txt and save and it will immediately populate in the box in game.

> [!WARNING]
> Warning: The Macros was a request from a friend and is highly untested so I apologize in advance.

</details>

---

<details open>
<summary><strong>Choice</strong></summary>

The choice hotbar allows you to assign one slot to the hotbar that can hold multiple usable actions in a unique hotbar that only opens up when choice mode is toggled/primed and a choice icon is pressed.

For the Choice Maker, there is a Smart Assist which is just meant to give some quick choices based on your current main/sub job. For example, Rolls for Corsair is a choice slot that contains all of the Phantom Rolls in the choice hotbar so you can press one icon on your hotbar and have all of your phantom rolls at your disposal.

In Choice Maker, you can also manually create a choice that you'd like by clicking new choice and adding actions to the list.

Dynamic pet slots allows you to have an ability that when activated expands and retracts abilities that can only be used when a pet is summoned. For example, when you summon a wyvern it will populate the hotbar with things like Spirit Surge, Spirit Link, Spirit Bond, etc. Then when a pet is desummoned or otherwise no longer in a state considered summoned, the abilities will retract back into the slot used to summon it.

Drag Toggle when toggled on will allow you to drag action icons on top of eachother to create a Choice with the slot that was dragged onto being the root.

</details>

---

<details open>
<summary><strong>Autogen</strong></summary>

Autogen was made just to populate a quick hotbar for people that want to hit the ground running without worrying about setting up their own hotbar.

When toggled on, you can choose whichever category is available for your current Main/Sub job setup like Job abilities then choose a hotbar number and it will automatically populate the hotbar with all of the actions in that category. Including those you don't have unlocked yet.

You can assign multiple categories to a hotbar if you'd like and the order that you assign them in is the order they'll be placed on the hotbar.

Toggling it off will return you back to your hotbar setup for manual placement and saves your last set up that was done manually.

> [!NOTE]
> Autogen is not recommended for those who wish to customize their hotbars as the structure of it is pretty rigid and is only meant for those who want to play quickly.

</details>

---

<details open>
<summary><strong>Config</strong></summary>

The XivUI menu config contains toggles for nearly every available thing in the addon.

Some components are disabled by default but you can toggle any of them on or off depending on your own preference.

There are two themes to choose from: FFXI or FFXIV (default).

Plenty of configs so I encourage you to take a quick scroll through and try them out to find a setup to your liking.

> [!WARNING]
> There are two configs included at the very bottom which have a warning attached to them, these are the Enemy Weakness and Enemy Drops, these have a warning as they can be wrong and if you don't wish to be presented with possible wrong information then it's best to keep it off.

</details>

---

<details open>
<summary><strong>HUD Layout</strong></summary>

The HUD layout allows you to click any UI component (when clicked it will show orange highlight) and drag them around your screen to position them where you like.

When focused on a UI component you can also scroll with your mouse wheel to scale things smaller or larger.

For Hotbars, if you double click a bar it will allow you to select individual slots to place them however you would like on your screen while in this mode you can also scale individual slots as well.

If you wish to snap individually moved hotbar slots back to their hotbar you can double click on the slot.

</details>

</details>

---

<details open>
<summary><strong>TargetBar</strong></summary>

<br>

The targetbar contains a buff/debuff strip that will populate below the hp bar as icons with timers and drop when expired. There are some buffs/debuffs I added that were not originally tracked and can be considered experimental and possibly erroneous. Things like enemy ability buffs or things like Dancer's haste daze.

The timer of your buffs also give insight as to where a buff came from: White = Self applied, Blue = Party member, Yellow = Someone else.

When hovering your mouse over a buff/debuff, a tooltip will appear giving a brief description of the status.

The targetbar also contains a subtarget that shows you who is currently targetted by the target.

You can also see spell casts and ability usages to the top right of the hp bar.

Hp bar colors are categorized by what is being targetted: Red = Enemy, Blue = Player, Yellow = NPC, Gray = Objects. If you ever run into an object that is given a yellow hp bar you can go to /addons/XivUI/data/targetbar and add a string with the name in objects.txt and it will be corrected when reloading the addon.

Targetbar also contains skillchains to the bottom right of the hp bar. When something opens a skillchain it will populate on the bar with a list of weaponskills you can use colored by their property. There is also a timer that will show the open window. To the right of the weaponskill name will be a - or a + depending on what the weaponskill used will do for the skillchain.

> [!WARNING]
> Targetbar also contains a loot bag to the bottom right of the hp bar that when pressed will open a list containing the drops that can be obtained from the target. This includes kill drops, steal, despoil, gil, and crystals. % are also included. This addition can be wrong and thus should be taken with a grain of salt.

> [!WARNING]
> Targetbar also contains either 1 or 2 icons to the right of the targets name containing weaknesses (element/physical damage types) and resistances (status ailment resistances) that will be split into the left icon being things that the enemy is weak too or resists less and the right icon being things the enemy is resistant to/is immune to/absorbs. This like the loot bag can be wrong and should also be taken with a grain of salt.

</details>

---

<details open>
<summary><strong>Dps Parser</strong></summary>

<br>

Displays the time elapsed in battle. The total dps of the party. The zone and enemy encounter. The name of party members and their damage, dps, % of dmg done, crit %, block %, parry %, evasion %, guard %, and heals per second.

You can have skillchains and magic bursts display as a party total or added to the individual.

Pets can also be shown separated by their own damage or added to their owners damage.

Based on jobs, I've assigned some auto colors to each party member where they will be: Blue = tank, Red = DPS, Green = Healer, Lavender = Support, Brown = Pets, Gold = Skillchains/Magic burst and anything unknown is Gray.

As jobs can be multiple roles, in the config you can assign a party slot to a specific role so you can get the correct colors for your unique party setup.

</details>

---

<details open>
<summary><strong>Aggrolist</strong></summary>

<br>

Displays the mobs currently targetting either you or your party members.

If targetting you, there will be a red circle next to the enemy row or if targetting a party member the circle will be yellow.

</details>

---

<details open>
<summary><strong>Request Window</strong></summary>

<br>

Displays a pill when someone requests a party or trade with you. When pressed it opens up a confirmation window where you can quickly accept or reject a request.

</details>

---

<details open>
<summary><strong>Notification</strong></summary>

<br>

Displays a loot toast (small temporary notification) showing the drops you have obtained on screen as text before fading out.

In the config, you can also enable seeing a party member's loot gained.

</details>

---

<details open>
<summary><strong>Castbar</strong></summary>

<br>

Displays a cast bar when casting a spell and a bar that fills with your melee auto attacks and shows interval (and also multihits).

</details>

---

<details open>
<summary><strong>Xivparty</strong></summary>

<br>

This now displays a castbar and/or ability activations for your party members underneath their job icons.

A party pet list has also been added.

</details>

---

<details open>
<summary><strong>Hotbar</strong></summary>

<br>

Hotbars can be toggled on/off in the config and you can choose to have job specific layouts if you dont want a one size fits all hotbar setup.

In the config you can also toggle on/off seeing costs to the bottom left of the hotbar icon (for example ninjutsu showing how many ninja tools you have available or Angon showing you how many angons you have).

Hotbar also has a dedicated ranged button which when auto pinned will add a ranged icon to your hotbar in the first open slot.

This ranged button has multiple behaviors: Auto = It toggles and will continue to used ranged attacks in combat, Press = Requires you to press the slot to activate a ranged attack.

There are also modes made specifically for auto: All = It will do Ranged attacks non stop when able, Alternate = It will alternate between doing one melee attack then one ranged attack, Distance = It will only used ranged attacks when you are out of melee range.

There is also an auto equip ammo which will quickly fill your ammo slot with whatever usable ammo you have available and with ammo source you can choose where ammo is grabbed from.

Hotbar can toggle auto collapse gaps if you want to quickly elimate any gaps in your hotbar and it can automatically hide any unusable assigned slots on your hotbar.

Hotbar also displays a highlighted border around weaponskills that can be used for a skillchain with the color being the property.

You can press \ to change between the Main (Battle) hotbar or the General (Out of combat) hotbar. You can also have it autoswitch in the config.

Sets grid enables visibility of the Hotbar Sets.

</details>

---

<details open>
<summary><strong>Hotbar Sets</strong></summary>

<br>

Hotbar sets enabled displays a 3x3 grid with circles that can be pressed and held to save your current hotbar set up then pressed on a colored slot to quickly load the hotbar set that was saved.

</details>


<a id="hotbar-sets"></a>
## Hotbar Sets
Hotbar sets enabled displays a 3x3 grid with circles that can be pressed and held to save your current hotbar set up then pressed on a colored slot to quickly load the hotbar set that was saved.

<a id="patch-notes"></a>
## Patch Notes

### v0.1.3
- After noticing the last lua errors caused when hotbar component disabled, I found more issues caused by having certain things off. 

TL;DR: you can now turn stuff off and mess with settings in peace without Vana'diel yelling at you. o/

### v0.1.2
- Fixed Lua errors (`ui.lua` / `texts.lua`) that was caused when disabling the hotbar component.

<a id="credits"></a>
## Credits

XivUI brings together and builds on the work of many amazing FFXI addon authors with which I would not have completed this addon. It incorporates ideas or code derived from **xivparty - Tylas**, **XIVHotbar2 - Sabarjp, Fethur, Edeon, Akirane, Technyze**, **xivbar - Edeon**, **barfiller - Morath**, **enemybar - MmcKee**, **Debuffed - Xathe**, **Scoreboard - Suji**, **Skillchains - Ivaar**, re-skinned and unified under one addon. Original authorship/credit headers are retained in the relevant source files.

Maintained by **maybeLynd**.
