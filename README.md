# TF2 DropWeapon

The purpose of this plugin is to re-enable dropping weapons from players into the worls and picking them back up / re-equipping single inventory slots.
This allows for weapon handling similar to other Source games like CS.

I feel like it's important to mention that the goal of this plugin is not to give you arbitrary weapons (falsify inventory) to arbitrary classes,
but to merely give weapons already owned by a player back to them in a controlled manner, like you would expect from other valve games.

## For players, the idea is simple

Use your drop item key (Default `bind L dropitem`) to drop your active weapon (CTF flag as priority). To pick an item back up
use your action item key (default H) or, for a more reliable pickup, use a +use bind. Unless disabled, you can also just walk over the weapon to pick it up,
given you do not have another weapon in the same slot.

If you just want this as a library for other plugins, you can set `sm_tf2dropweapon_enabled 0` to set the plugin in library mode and disable all interactive/player functionallity.

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
| sm_tf2dropweapon_enabled 1 | Enables sm_dropweapon/sm_pickupweapon, dropitem hook and proximity pickup. Set to 0 if you just got this plugin as library. |

The commands were used for testing, but feel free to enable them for your players:

| Command   | Description   |
|-----|-----|
| sm_dropweapon | Drop your weapon |
| sm_pickupweapon | Look at a weapon first |
| sm_giveweapon | ADMFLAG_CHEATS - Usage: (\<weapon>\|\<class> \<slot> ['stock']). Gives a player a weapon. Either use a weapon class name, or player class name and slot. For class and slot, gives from the loadout. If stock is specified uses a stock weapon. |
| sm_dwgive | ADMFLAG_CHEATS - Same as sm_giveweapon. Just a shorter alias that should not clash with other give weapon plugins. |

## Natives/Forwards overview

| Function  | Summary  |
|-----|-----|
| `forward Action TF2DW_OnClientDropWeapon(int client, int weapon)` | React to when a weapons is dropped |
| `forward void TF2DW_OnClientDropWeaponPost(int client, int droppedWeapon)` | Listen to when a weapon was dropped |
| `forward Action TF2DW_OnClientPickupWeapon(int client, int droppedWeapon)` | React to when a weapon is picked up |
| `forward void TF2DW_OnClientPickupWeapon(int client, int droppedWeapon)` | Listen to when a weapon was picked up |
| `native int TF2DW_DropWeaponLoadoutSlot(int client, int loadoutSlot)` | Force a player to drop a weapon in the given loadout slot |
| `native int TF2DW_GiveWeaponByClassname(int client, const char[] classname)` | Equip a player with a weapon based on weapon classname and active player class (stock) |
| `native int TF2DW_GiveWeaponForLoadoutSlot(int client, int loadoutSlot, bool stockItem=false)` | Equip a player with a weapon based on weapon slot and active player class (uses loadout unless stockItem is true) |
| `native int TF2DW_CreateDroppedWeaponByClassname(const char[] classname, TFClassType class, const float position[3])` | Spawn a stock dropped weapon in the world based on weapon class name and specified player class |
| `native int TF2DW_CreateDroppedWeaponFromLoadout(int client, TFClassType class, int slot, const float position[3])` | Spawn a dropped weapon in the world based on player loadout, player class and weapon slot |
| `native int TF2DW_GetStockWeaponItemDef(TFClassType class, int slot)` | Get the stock item definition index for a given player class and loadout slot |
| `native bool TF2DW_GetWeaponDefaultMaxClipAndAmmo(int itemDef, TFClassType playerClass=TFClass_Unknown, int& maxClip=0, int& maxAmmo=0)` | Get a weapons default max ammo and clip size based on player class data and item attributes |

## Dependencies

* Nosoops [TF Econ Data](https://github.com/nosoop/SM-TFEconData) and [TF2Utils](https://github.com/nosoop/SM-TFUtils/) as well as [TF2PlayerClassData](https://github.com/DosMike/TF2-PlayerClassDataHook).
* Optionally use [TF2 Gravity Hands](https://github.com/DosMike/TF2-GraviHands) to prevent weapon-less players from A-posing.

## Module Plugins

### [TF2 DropWeapon SimpleConfig](module_config.md)
Simple configuration on what weapon / weapon slots can be dropped and picked up per team
