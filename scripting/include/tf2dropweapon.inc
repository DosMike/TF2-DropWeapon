#if defined __tf2_dropweapon_included
#endinput
#endif
#define __tf2_dropweapon_included

#include <tf2>

/**
 * Client tries to drop their current weapon. If cancelled during weapon pickup,
 * picking up the other weapon is cancelled.
 *
 * You can also use the SDKHook_WeaponDrop. The SDKHook is called before this
 * forward, iif the weapon was dropped through SDKHook_DropWeapon().
 *
 * @param client - the player trying to pick up a weapon
 * @param weapon - the CTFWeapon* about to be dropped
 * @return Plugin_Handled or above to prevent
 */
forward Action TF2DW_OnClientDropWeapon(int client, int weapon);

/**
 * The client successfully dropped a weapon. The weapon itself if no longer
 * valid, but there's maybe a CTFDroppedWeapon in it's place. Under certain
 * conditions, no weapon is actually dropped and the slot is just deleted.
 *
 * Nevertheless, the intention for this forward was to drop the weapon. This is
 * NOT a forward for TF2_RemoveWeaponSlot!
 *
 * You can also use the SDKHook_WeaponDropPost. The SDKHook is called after this
 * forward, iif the weapon was dropped through SDKHook_DropWeapon().
 *
 * @param client - the player that dropped a weapon
 * @param droppedWeapon - the world instance, if spawned
 * @noreturn
 */
forward void TF2DW_OnClientDropWeaponPost(int client, int droppedWeapon);

/**
 * For a player picking up a weapon from a CTFDroppedWeapon instance.
 * After this forward, if there is a weapon already in the loadout slot, that
 * weapon will dropped. This forward being called implicates the weapon being
 * applicable to the players current TFClassType.
 * 
 * @param client - the player that is trying to equip the weapon
 * @param droppedWeapon - the CTFDroppedWeapon that is being picked up
 * @return Plugin_Handled or higher to prevent picking up
 */
forward Action TF2DW_OnClientPickupWeapon(int client, int droppedWeapon);

/**
 * A CTFDroppedWeapon was successfully picked up by the player and is now converted
 * to an appropriate CTFWeapon*.
 *
 * @param client - the player that picked up a weapon
 * @param weapon - the CTFWeapon* that was equipped
 * @noreturn
 */
forward void TF2DW_OnClientPickupWeaponPost(int client, int weapon);

/**
 * Force the player to drop their weapon in the specified loadout slot.
 * You can also use SDKHooks_DropWeapon(client, weapon, .bypassHooks=false) but
 * keep in mind that you have to explicitly enable hooks for this to work.
 * If you don't want SDK Callbacks to be called, you have to use this function.
 * 
 * @param client - the player to drop an item from
 * @param loadoutSlot - the loadout slot to drop (0..5)
 * @return CTFDroppedWeapon instance if spawned, INVALID_ENT_REFERENCE if 
 *         failed or the game prevented a dropped weapon from spawning.
 */
native int TF2DW_DropWeaponLoadoutSlot(int client, int loadoutSlot);

/**
 * Force give the player a weapon with the specified classname. This will resolve
 * to the item with the lowest matching itemDef. Multiclass item classnames
 * like tf_weapon_shotgun or saxxy will automatically be resolved for the TFClassType.
 * Will not reset the ammo for the weapons ammo type!
 * 
 * @param client - the player to give a weapon.
 * @param classname - weapon classname to resolve.
 * @return CTFWeapon* entity on success, INVALID_ENT_REFERENCE otherwise.
 */
native int TF2DW_GiveWeaponByClassname(int client, const char[] classname);

/**
 * Force give a player their class weapon for the specified loadoutSlot.
 * By default it will search the player inventory and give the equipped weapon.
 * Optionally you can set it to give the stock weapon for the specified slot.
 *
 * @param client - the player to give a weapon.
 * @param loadoutSlot - the loadoutSlot to re-equip.
 * @param stockItem - set true to force the stock weapon over their inventory.
 * @return CTFWeapon* entity on success, INVALID_ENT_REFERENCE otherwise.
 */
native int TF2DW_GiveWeaponForLoadoutSlot(int client, int loadoutSlot, bool stockItem=false);

/**
 * Create a dropped weapon in the world by classname at the specified position.
 * This will be a base weapon (lowest itemdef by classname for the given playerclass)
 * 
 * @param classname - the tf_weapon_* classname
 * @param class - a player class to resolve ambiguities (e.g. tf_weapon_pistol)
 * @param position - where to create the weapon
 * @return weapon entity on success, INVALID_ENT_REFERENCE otherwise.
 */
native int TF2DW_CreateDroppedWeaponByClassname(const char[] classname, TFClassType class, const float position[3]);

/**
 * Create a dropped weapon in the world by classname at the specified position.
 * This will be the same as a players inventory weapon for the given class and loadout slot.
 * 
 * @param client - the player whos inventory to look up
 * @param class - a player class (Unknown will be resolved to current class)
 * @param slot - the loadout slot for the player class inventory to query
 * @param position - where to create the weapon
 * @return weapon entity on success, INVALID_ENT_REFERENCE otherwise.
 */
native int TF2DW_CreateDroppedWeaponFromLoadout(int client, TFClassType class, int slot, const float position[3]);

/**
 * For a valid combination of player class and loadout slot, returns the default/stock itemDef
 *
 * @param class - playerclass
 * @param slot - 0 = primary, 1 = secondary, 2 = melee, 3 = build pda /
 *               disguise kit, 4 = destr pda / invis watch, rest is unsupported
 * @return itemDef or -1 if slot is empty for class
 * @throws on class enum violation, slot out of range
 */
native int TF2DW_GetStockWeaponItemDef(TFClassType class, int slot);

/**
 * Get the default clip and ammo size for a weapon. This takes some static attributes into account.
 * For some items, the player class is required to properly get the max ammo count (any multiclass item).
 * If you do not specify a specific class, one will be tried to guess. Guessed player class for an
 * item might result in inaccurate results.
 *
 * @param itemDef - item to look up. should be a weapon.
 * @param playerClass - class to help disambiguate max ammo coutns.
 * @param maxClip - out, default clip size
 * @param maxAmmo - out, default max ammo
 * @return false if itemDef is invalid, true on success
 * @throws if playerClass can not be resolved for given item
 */
native bool TF2DW_GetWeaponDefaultMaxClipAndAmmo(int itemDef, TFClassType playerClass=TFClass_Unknown, int& maxClip=0, int& maxAmmo=0);


public SharedPlugin __pl_tf2dropweapon = {
	name = "tf2dropweapon",
	file = "tf2dropweapon.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#if !defined REQUIRE_PLUGIN
public void __pl_tf2dropweapon_SetNTVOptional() {
	MarkNativeAsOptional("TF2DW_DropWeaponLoadoutSlot");
	MarkNativeAsOptional("TF2DW_GiveWeaponByClassname");
	MarkNativeAsOptional("TF2DW_GiveWeaponForLoadoutSlot");
	MarkNativeAsOptional("TF2DW_CreateDroppedWeaponByClassname");
	MarkNativeAsOptional("TF2DW_CreateDroppedWeaponFromLoadout");
	MarkNativeAsOptional("TF2DW_GetStockWeaponItemDef");
	MarkNativeAsOptional("TF2DW_GetWeaponDefaultMaxClipAndAmmo");
}
#endif