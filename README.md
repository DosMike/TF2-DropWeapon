# TF2 DropWeapon

The purpose of this plugin is to re-enable dropping weapons from players into the worls and picking them back up / re-equipping single inventory slots.
This allows for weapon handling similar to other Source games like CS.

I feel like it's important to mention that the goal of this plugin is not to give you arbitrary weapons (falsify inventory) to arbitrary classes,
but to merely give weapons already owned by a player back to them in a controlled manner, like you would expect from other valve games.

## For players, the idea is simple

Use your drop item key (Default `bind L dropitem`) to drop your active weapon (CTF flag as priority). To pick an item back up
use your action item key (default H) or, for a more reliable pickup, use a +use bind. Unless disabled, you can also just walk over the weapon to pick it up,
given you do not have another weapon in the same slot.

## For plugin devs

Using this plugin you can drop weapons, pick up any tf_dropped_weapon to a player, regenerate loadout slots from the current player inventory, equip stock items
for players on a whim, even by the weapon's classname; or react to weapons being dropped and picked up. See the include file for more information.

This plugin also partially restores SDKHook_WeaponDrop (i think) and SDKHook_DropWeapon native (bypassHooks needs to be false).

## ConVars & Commands

| ConVar   | Description   |
|-----|-----|
| sm_tf2dropweapon_supresscleanup 0 | By default the game checks the game mode and deletes already existing weapons before spawning more. Set to 1 to disable that check. |
| sm_tf2dropweapon_usetopickup 1 | The default key for picking up weapons seems to have issues. Set to 1 to allow +use to pick up weapons. |
| sm_tf2dropweapon_pickupany 1 | There are some restriction for picking up weapons. Set to 1 to ignore these. Note: Setting to one uses a reimplementation that might be more prone to gamedata updates, so try 0 if you're running into issues. |
| sm_tf2dropweapon_touchpickup 1 | Set to 1 to pick up weapons, that fit into a slot that is currently empty. |

The commands were used for testing, but feel free to enable them for your players:

| Command   | Description   |
|-----|-----|
| sm_dropweapon | Drop your weapon |
| sm_pickupweapon | Look at a weapon first |
| sm_giveweapon | ADMFLAG_CHEATS - Usage: (\<weapon>\|\<class> \<slot> ['stock']). Gives a player a weapon. Either use a weapon class name, or player class name and slot. For class and slot, gives from the loadout. If stock is specified uses a stock weapon. |
| sm_dwgive | ADMFLAG_CHEATS - Same as sm_giveweapon. Just a shorter alias that should not clash with other give weapon plugins. |

## Dependencies

* Nosoops [TF Econ Data](https://github.com/nosoop/SM-TFEconData) and [TF2Utils](https://github.com/nosoop/SM-TFUtils/) as well as [TF2PlayerClassData](https://github.com/DosMike/TF2-PlayerClassDataHook).
* Optionally use [TF2 Gravity Hands](https://github.com/DosMike/TF2-GraviHands) to prevent weapon-less players from A-posing.