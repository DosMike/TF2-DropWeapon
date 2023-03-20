#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <tf_econ_data>
#include <tf2utils>
#include <tf2playerclassdata>

#undef REQUIRE_PLUGIN
#include <tf2gravihands>
#define REQUIRE_PLUGIN

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "23w12a"

public Plugin myinfo = {
	name = "[TF2] DropWeapon",
	author = "reBane",
	description = "Drop and pick up weapons like in other source games",
	version = PLUGIN_VERSION,
	url = "N/A"
}

ConVar cv_SupressWeaponCleanup;
ConVar cv_UseToPickup;
ConVar cv_IgnorePickupRestrictions;
ConVar cv_TouchPickup;
ConVar cv_Enabled;

ArrayList g_EntityAge;
float g_clDropTimes[MAXPLAYERS+1];

#include "tf2dropweapon/staticdata.sp"
#include "tf2dropweapon/hooks.sp"
#include "tf2dropweapon/natives.sp"

bool dep_GraviHands;
bool g_bLateLoad;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bLateLoad = late;
	InitNatives();
	
	RegPluginLibrary("tf2dropweapon");
	return APLRes_Success;
}

public void OnPluginStart() {
	InitHookData();
	
	cv_SupressWeaponCleanup = CreateConVar("sm_tf2dropweapon_supresscleanup", "0", "By default the game checks the game mode and deletes already existing weapons before spawning more. Set to 1 to disable that check.", FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	cv_UseToPickup = CreateConVar("sm_tf2dropweapon_usetopickup", "1", "The default key for picking up weapons seems to have issues. Set to 1 to allow +use to pick up weapons.", FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	cv_IgnorePickupRestrictions = CreateConVar("sm_tf2dropweapon_pickupany", "1", "There are some restriction for picking up weapons. Set to 1 to ignore these. Note: Setting to one uses a reimplementation that might be more prone to gamedata updates, so try 0 if you're running into issues.", FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	cv_TouchPickup = CreateConVar("sm_tf2dropweapon_touchpickup", "1", "Set to 1 to pick up weapons, that fit into a slot that is currently empty.", FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	cv_Enabled = CreateConVar("sm_tf2dropweapon_enabled", "1", "Enables sm_dropweapon/sm_pickupweapon, dropitem hook and proximity pickup. Set to 0 if you just got this plugin as library", FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	
	ConVar version = CreateConVar("sm_tf2dropweapon_version", PLUGIN_VERSION, "Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	version.SetString(PLUGIN_VERSION);
	version.AddChangeHook(OnVersionChanged);
	delete version;
	
	RegConsoleCmd("sm_dropweapon", ConCmd_Drop, "Drop your weapon");
	RegConsoleCmd("sm_pickupweapon", ConCmd_Pickup, "Look at a weapon first");
	RegAdminCmd("sm_giveweapon", ConCmd_GiveGun, ADMFLAG_CHEATS, "Usage: [player] (<weapon>|<class> <slot> ['stock'|<other>]) - Gives players a weapon. Either use a weapon class name, or player class name and slot. For class and slot, gives from the loadout, or stock if specified.");
	RegAdminCmd("sm_dwgive", ConCmd_GiveGun, ADMFLAG_CHEATS, "Same as sm_giveweapon. Just a shorter alias that should not clash with other give weapon plugins.");
	RegAdminCmd("sm_spawnweapon", ConCmd_SpawnGun, ADMFLAG_CHEATS, "Usage: (<weapon> <class>|<class> <slot> ['stock'|<player>]) - Creates a dropped weapon in the world based on the class name and player class or player class and loadout slot. For class and slot, gives from the loadout, or stock is specified.");
	RegAdminCmd("sm_dwspawn", ConCmd_SpawnGun, ADMFLAG_CHEATS, "Same as sm_spawnweapon. Just a shorter alias that should not clash with other give weapon plugins.");
	
	AddCommandListener(ConCmd_Dropitem, "dropitem");
	
	InitStaticData();
	InitForwards();
}
public void OnVersionChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	if (!StrEqual(newValue,PLUGIN_VERSION)) {
		convar.SetString(PLUGIN_VERSION);
	}
}

public void OnAllPluginsLoaded() {
	dep_GraviHands = (LibraryExists("tf2gravihands"));
}
public void OnLibraryAdded(const char[] name) {
	dep_GraviHands |= StrEqual(name, "tf2gravihands");
}
public void OnLibraryRemoved(const char[] name) {
	dep_GraviHands &=~ StrEqual(name, "tf2gravihands");
}


public void OnMapStart() {
	PrecacheSound("common/wpn_denyselect.wav");
	PrecacheSound("items/gunpickup2.wav");
	CreateTimer(0.1, Timer_PickupThink, 0, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	
	if (g_EntityAge == INVALID_HANDLE) {
		g_EntityAge = new ArrayList(2);
	} else {
		g_EntityAge.Clear();
	}
	
	if (g_bLateLoad) {
		//notify about all existing entites, to allow them to be hooked
		for (int i=1; i<GetMaxEntities(); i++) {
			if (IsValidEntity(i)) {
				char classname[72];
				GetEntityClassname(i, classname, sizeof(classname));
				OnEntityCreated(i, classname);
			}
		}
	}
}

int g_prevButtons[MAXPLAYERS+1];
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
	if (!cv_Enabled.BoolValue) return Plugin_Continue;
	
	bool inUse = (buttons & IN_USE) && !(g_prevButtons[client] & IN_USE);
	g_prevButtons[client] = buttons;
	
	if (inUse && client && IsClientInGame(client) && IsPlayerAlive(client) && cv_UseToPickup.BoolValue) {
		if (TryPickUpCursorEnt(client)) return Plugin_Handled;
	}
	return Plugin_Continue;
}



public Action ConCmd_Drop(int client, int args) {
	if (!cv_Enabled.BoolValue) {
		return Plugin_Continue;
	}
	
	if (client == 0 || !IsClientInGame(client)) {
		return Plugin_Handled;
	}
	
	if (!IsPlayerAlive(client)) {
		ReplyToCommand(client, "[SM] You need to be alive");
		return Plugin_Handled;
	}
	
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (weapon == INVALID_ENT_REFERENCE) {
		EmitSoundToClient(client, "common/wpn_denyselect.wav");
	} else {
//		SDKHooks_DropWeapon(client, weapon, .bypassHooks=false);
		DropWeapon(client, weapon, true, true, NULL_VECTOR, NULL_VECTOR);
		if (dep_GraviHands) TF2GH_PreventClientAPosing(client);
	}
	return Plugin_Handled;
}

public bool Trace_SelfHitFilter(int entity, int contentsMask, any data) {
	return entity != data;
}

public Action ConCmd_Pickup(int client, int args) {
	if (!cv_Enabled.BoolValue) return Plugin_Continue;
	
	TryPickUpCursorEnt(client);
	return Plugin_Handled;
}

public Action ConCmd_Dropitem(int client, const char[] command, int args) {
	if (!cv_Enabled.BoolValue || !IsPlayerAlive(client)) {
		return Plugin_Continue;
	}
	
	int carriedItem = GetEntPropEnt(client, Prop_Send, "m_hItem");
	if (carriedItem != INVALID_ENT_REFERENCE) {
		return Plugin_Continue;
	}
	
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (weapon != INVALID_ENT_REFERENCE) {
		//SDKHooks_DropWeapon(client, weapon, .bypassHooks=false);
		DropWeapon(client, weapon, true, true, NULL_VECTOR, NULL_VECTOR);
	}
	if (dep_GraviHands) TF2GH_PreventClientAPosing(client);
	
	return Plugin_Continue;
}

char[] GetFormatTF2ClassType(TFClassType class) {
	static char classnames[10][10] = {"unknown","scout","sniper","soldier","demoman","medic","heavy","pyro","spy","engineer"};
	return classnames[view_as<int>(class)];
}

/** Similar to FindTarget, but wont auto-reply. returns process target errors (<=0) or client index (>0) */
public int FindSingleTargetSilent(int client, const char[] pattern, int commandFilterFlags) {
	int targets[2];
	char tname[4];
	bool tnisml;
	int tcount = ProcessTargetString(pattern, client, targets, sizeof(targets), commandFilterFlags|COMMAND_FILTER_NO_MULTI, tname, 0, tnisml);
	return tcount >= 1 ? targets[0] : tcount;
}

public Action ConCmd_GiveGun(int client, int args) {
	if (client == 0 || !IsClientInGame(client)) {
		ReplyToCommand(client, "[SM] Invalid client state");
		return Plugin_Handled;
	}
	if (args <= 0) {
		char cmd[64];
		GetCmdArg(0, cmd, sizeof(cmd));
		ReplyToCommand(client, "[SM] Usage: %s [target] <weapon class> OR %s [target] <player class> <slot> ['stock'|<player>]", cmd, cmd);
		return Plugin_Handled;
	}
	int nextarg = 1;
	char buffer[100];
	
	GetCmdArg(1, buffer, sizeof(buffer));
	int targets[MAXPLAYERS+1];
	char tname[100];
	bool tnisml;
	int tcount = ProcessTargetString(buffer, client, targets, sizeof(targets), COMMAND_FILTER_ALIVE|COMMAND_FILTER_NO_BOTS, tname, sizeof(tname), tnisml);
	if (tcount <= 0) {
		targets[0] = client;
		tcount = 1;
		tnisml = false;
		GetClientName(client, tname, sizeof(tname));
	} else {
		nextarg += 1;
	}
	
	if (args < nextarg) {
		ReplyToCommand(client, "[SM] Missing next argument: weapon class or player class expected");
		return Plugin_Handled;
	}
	GetCmdArg(nextarg, buffer, sizeof(buffer));
	TFClassType class = TF2_GetClass(buffer);
	if (class != TFClass_Unknown) { //get slot
		nextarg += 1;
		if (args < nextarg) {
			ReplyToCommand(client, "[SM] Missing next argument: loadout slot expected");
			return Plugin_Handled;
		}
		GetCmdArg(nextarg, buffer, sizeof(buffer));
		nextarg += 1;
		
		int slot;
		if (StringToIntEx(buffer, slot)!=strlen(buffer)) {
			slot = TF2Econ_TranslateLoadoutSlotNameToIndex(buffer)+1;
		}
		if (slot < 1 || slot > 7) { //only want to accept slots up to pda2
			char allSlots[128];
			for (int i=0; i<7; i++) {
				char slotname[24];
				TF2Econ_TranslateLoadoutSlotIndexToName(i, slotname, sizeof(slotname));
				Format(allSlots, sizeof(allSlots), "%s, %s", allSlots, slotname);
			}
			if (allSlots[0]==0) allSlots = ", positive integer";
			ReplyToCommand(client, "[SM] Invalid loadout slot \"%s\": %s expected", buffer, allSlots[2]);
			return Plugin_Handled;
		}
		
		bool use_stock;
		int invSource=0; //0 is target
		if (args >= nextarg) {
			GetCmdArg(nextarg, buffer, sizeof(buffer));
			if (StrEqual(buffer, "stock")) use_stock = true;
			else if ((invSource = FindSingleTargetSilent(client, buffer, COMMAND_FILTER_NO_BOTS))<=0) {
				char reason[64];
				switch(invSource) {
					case COMMAND_TARGET_NONE: reason = "did not match a player";
					case COMMAND_TARGET_NOT_IN_GAME: reason = "is not fully ingame";
					case COMMAND_TARGET_IMMUNE: reason = "is immune";
					case COMMAND_TARGET_EMPTY_FILTER: reason = "did not match any plyer";
					case COMMAND_TARGET_NOT_HUMAN: reason = "is a bot";
					case COMMAND_TARGET_AMBIGUOUS: reason = "matched multiple players";
					default: reason = "is breaking the command";
				}
				ReplyToCommand(client, "[SM] Invalid optional argument: \"stock\" or player expected, \"%s\" %s", buffer, reason);
				return Plugin_Handled;
			}
		}
		
		int given;
		for (int i=0; i<tcount; i+=1) {
			int weapon;
			if (use_stock) {
				weapon = GivePlayerStockItem(targets[i], slot-1, class);
			} else {
				weapon = GivePlayerLoadoutItem(targets[i], slot-1, class, invSource);
			}
			if (weapon != INVALID_ENT_REFERENCE) {
				GivePlayerAmmo(targets[i], 9999, GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType"));
				PrintToChat(targets[i], "[SM] %N gave you %s weapon for %s slot %i", client, use_stock?"the stock":"your", GetFormatTF2ClassType(class), slot);
				given++;
			}
		}
		if (given) {
			if (tnisml) ReplyToCommand(client, "[SM] You gave %t their %s weapon for %s slot %i (%i/%i matched players)", tname, use_stock?"stock":"loadout", GetFormatTF2ClassType(class), slot, given, tcount);
			else ReplyToCommand(client, "[SM] You gave %s their %s weapon for %s slot %i (%i/%i matched players)", tname, use_stock?"stock":"loadout", GetFormatTF2ClassType(class), slot, given, tcount);
		} else {
			if (tnisml) ReplyToCommand(client, "[SM] %t can not use the %s %s weapon in slot %i", tname, GetFormatTF2ClassType(class), use_stock?"stock":"loadout", slot);
			else ReplyToCommand(client, "[SM] %s can not use the %s %s weapon in slot %i", tname, GetFormatTF2ClassType(class), use_stock?"stock":"loadout", slot);
		}
		return Plugin_Handled;
	}
	if (StrEqual(buffer,"saxxy")) {
		// keep
	} else if (StrContains(buffer, "weapon_")==0 || StrContains(buffer, "wearable")==0) {
		Format(buffer, sizeof(buffer), "tf_%s", buffer);
	} else if (StrContains(buffer, "tf_")!=0) { //not starting with tf_
		if (StrEqual(buffer, "demoshield") || StrEqual(buffer, "razorback"))
			Format(buffer, sizeof(buffer), "tf_wearable_%s", buffer);
		else
			Format(buffer, sizeof(buffer), "tf_weapon_%s", buffer);
	}
	if (!IsValidWeaponClassname(buffer)) {
		GetCmdArg(nextarg, buffer, sizeof(buffer));
		ReplyToCommand(client, "[SM] Invalid argument \"%s\", player class or weapon class expected.", buffer);
	} else {
		//skip prefix for readability: tf_wearable -> wearable, tf_weapon_bat -> bat, saxxy -> saxxy
		int fmtIdx = StrContains(buffer[3],"_");
		if (fmtIdx>0) fmtIdx+=4; else fmtIdx = (buffer[2]=='_' ? 3 : 0);
		
		int given;
		for (int i=0; i<tcount; i+=1) {
			int weapon = GiveWeaponFromItemView(targets[i], .weaponclass=buffer);
			if (weapon != INVALID_ENT_REFERENCE) {
				GivePlayerAmmo(targets[i], 9999, GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType"));
				PrintToChat(targets[i], "[SM] %N gave you the stock %s", client, buffer[fmtIdx]);
				given++;
			}
		}
		if (!given) {
			tnisml = false;
			strcopy(tname, sizeof(tname), "nobody");
		}
		if (tnisml) ReplyToCommand(client, "[SM] You gave %t a %s (%i/%i matched players)", tname, buffer[fmtIdx], given, tcount);
		else ReplyToCommand(client, "[SM] You gave %s a %s (%i/%i matched players)", tname, buffer[fmtIdx], given, tcount);
	}
	return Plugin_Handled;
}

public Action ConCmd_SpawnGun(int client, int args) {
	if (client == 0 || !IsClientInGame(client)) {
		ReplyToCommand(client, "[SM] Invalid client state");
		return Plugin_Handled;
	}
	if (args <= 0) {
		char cmd[64];
		GetCmdArg(0, cmd, sizeof(cmd));
		ReplyToCommand(client, "[SM] Usage: %s <weapon class> <player class> OR %s <player class> <slot> ['stock'|<player>]", cmd, cmd);
		return Plugin_Handled;
	}
	if (args < 1) {
		ReplyToCommand(client, "[SM] Missing next argument: weapon class or player class expected");
		return Plugin_Handled;
	}
	char bufferA[64];
	char bufferB[64];
	GetCmdArg(1, bufferA, sizeof(bufferA));
	GetCmdArg(2, bufferB, sizeof(bufferB));
	TFClassType pClass;
	int slot = -1;
	if ((pClass = TF2_GetClass(bufferA)) != TFClass_Unknown) {
		if (StringToIntEx(bufferB, slot)!=strlen(bufferB)) {
			slot = TF2Econ_TranslateLoadoutSlotNameToIndex(bufferB)+1;
		}
		if (args < 2) {
			ReplyToCommand(client, "[SM] Missing next argument: loadout slot expected");
			return Plugin_Handled;
		}
		if (slot < 1 || slot > 5) { //only want to accept slots up to pda2
			char allSlots[128];
			for (int i=0; i<7; i++) {
				char slotname[24];
				TF2Econ_TranslateLoadoutSlotIndexToName(i, slotname, sizeof(slotname));
				Format(allSlots, sizeof(allSlots), "%s, %s", allSlots, slotname);
			}
			if (allSlots[0]==0) allSlots = ", positive integer";
			ReplyToCommand(client, "[SM] Invalid loadout slot \"%s\": %s expected", bufferB, allSlots[2]);
			return Plugin_Handled;
		}
		slot -= 1; //from natural to index
	} else {
		//try to fix up classname
		if (StrEqual(bufferA,"saxxy")) {
			// keep
		} else if (StrContains(bufferA, "weapon_")==0 || StrContains(bufferA, "wearable")==0) {
			Format(bufferA, sizeof(bufferA), "tf_%s", bufferA);
		} else if (StrContains(bufferA, "tf_")!=0) { //not starting with tf_
			if (StrEqual(bufferA, "demoshield") || StrEqual(bufferA, "razorback"))
				Format(bufferA, sizeof(bufferA), "tf_wearable_%s", bufferA);
			else
				Format(bufferA, sizeof(bufferA), "tf_weapon_%s", bufferA);
		}
		if (!IsValidWeaponClassname(bufferA)) {
			GetCmdArg(1, bufferA, sizeof(bufferA));
			ReplyToCommand(client, "[SM] Invalid argument \"%s\", weapon class expected.", bufferA);
			return Plugin_Handled;
		}
		if (args < 2) {
			ReplyToCommand(client, "[SM] Missing next argument: player class expected");
			return Plugin_Handled;
		}
		if ((pClass = TF2_GetClass(bufferB)) == TFClass_Unknown) {
			ReplyToCommand(client, "[SM] Invalid argument: no such class \"%s\"", bufferB);
			return Plugin_Handled;
		}
	}
	Address pItem;
	char modelPath[PLATFORM_MAX_PATH];
	if (slot >= 0) {
		bool use_stock;
		int invSource=0; //0 is target
		if (args >= 3) {
			GetCmdArg(3, bufferA, sizeof(bufferA));
			if (StrEqual(bufferA, "stock")) use_stock = true;
			else if ((invSource = FindSingleTargetSilent(client, bufferA, COMMAND_FILTER_NO_BOTS))<=0) {
				char reason[64];
				switch(invSource) {
					case COMMAND_TARGET_NONE: reason = "did not match a player";
					case COMMAND_TARGET_NOT_IN_GAME: reason = "is not fully ingame";
					case COMMAND_TARGET_IMMUNE: reason = "is immune";
					case COMMAND_TARGET_EMPTY_FILTER: reason = "did not match any plyer";
					case COMMAND_TARGET_NOT_HUMAN: reason = "is a bot";
					case COMMAND_TARGET_AMBIGUOUS: reason = "matched multiple players";
					default: reason = "is breaking the command";
				}
				ReplyToCommand(client, "[SM] Invalid optional argument: \"stock\" or player expected, \"%s\" %s", bufferA, reason);
				return Plugin_Handled;
			}
		} else invSource = client;
		if (use_stock)
			pItem = GetBaseItemView(pClass, slot);
		else
			pItem = GetLoadoutItemView(invSource, pClass, slot);
		
		if (pItem != Address_Null) {
			int itemDef = GetItemViewItemDef(pItem);
			TF2Econ_GetItemDefinitionString(itemDef, "model_player", modelPath, sizeof(modelPath));
		}
	} else {
		int itemDef = GetDefaultItemDef(bufferA, pClass);
		if (itemDef < 0) {
			ReplyToCommand(client, "[SM] Invalid weapon class / player class combo: Unable to resolve %s for %s", bufferA, bufferB);
			return Plugin_Handled;
		}
		slot = TF2Econ_GetItemLoadoutSlot(itemDef, pClass);
		if (slot < 0 || slot >= 5) {
			ReplyToCommand(client, "[SM] Invalid state: Could not defer slot of itemdef %i (%s) for %s", itemDef, bufferA, bufferB);
			return Plugin_Handled;
		}
		TF2Econ_GetItemDefinitionString(itemDef, "model_player", modelPath, sizeof(modelPath));
		pItem = GetBaseItemView(pClass, slot);
	}
	if (pItem == Address_Null) {
		ReplyToCommand(client, "[SM] Invalid state: Could not load item view");
		return Plugin_Handled;
	}
	
	float origin[3], angles[3], fwd[3];
	GetClientEyePosition(client, origin);
	GetClientEyeAngles(client, angles);
	angles[0] = angles[2] = 0.0;
	GetAngleVectors(angles, fwd, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(fwd, 50.0);
	AddVectors(origin, fwd, origin);
	
	int weapon = CreateDroppedWeaponEnt(modelPath, pItem, origin, angles);
	
	if (weapon != INVALID_ENT_REFERENCE) {
		TF2Econ_GetItemClassName(GetItemViewItemDef(pItem), bufferA, sizeof(bufferA));
		ReplyToCommand(client, "[SM] You spawned a %s", bufferA);
	} else {
		ReplyToCommand(client, "[SM] Could not spawn weapon in world");
	}
	
	return Plugin_Handled;
}


public void OnEntityCreated(int entity, const char[] classname) {
	if (!IsValidEntity(entity)) return;
	if (StrEqual(classname, "tf_dropped_weapon") && g_EntityAge != INVALID_HANDLE) {
		any data[2];
		data[0] = EntIndexToEntRef(entity);
		data[1] = GetGameTime();
		g_EntityAge.PushArray(data);
	} else if (StrEqual(classname, "player") || StrEqual(classname, "bot")) {
		if (dh_WeaponDrop.HookEntity(Hook_Post, entity, Weapon_Drop_EntityCallback) == INVALID_HOOK_ID) {
			PrintToServer("Could not hook Weapon_Drop on %N", entity);
		}
	}
}
public void OnEntityDestroyed(int entity) {
	if (entity < 0 || g_EntityAge == INVALID_HANDLE) return;
	if (!IsValidEntity(entity)) return;
	int at = g_EntityAge.FindValue(EntIndexToEntRef(entity));
	if (at >= 0) g_EntityAge.Erase(at);
}

// ----- Common Code -----

/** Find a weapon by loadout slot on the player.
 * This ignores wether an item is valid for a player class, unlike TF2Util_GetPlayerLoadoutEntity
 * @param client
 * @param slot  loadout slot to scan for
 * @param weaponSlot optional out, actual base engine weapon slot
 * @return entity or -1 if invalid slot or no weapon for given slot
 */
int FindWeaponForLoadoutSlot(int client, int slot, int& weaponSlot=0) {
	TFClassType clClass = TF2_GetPlayerClass(client);
	for (int wslot; wslot<6; wslot+=1) {
		// get weapon in slot
		int weapon = GetPlayerWeaponSlot(client, wslot);
		if (weapon == INVALID_ENT_REFERENCE) continue;
		// get class or default loadout slot
		int defIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		int loadoutSlot = TF2Econ_GetItemLoadoutSlot(defIndex, clClass);
		if (loadoutSlot == -1) loadoutSlot = TF2Econ_GetItemDefaultLoadoutSlot(defIndex);
		// check
		if (loadoutSlot == slot) {
			weaponSlot = wslot;
			return weapon;
		}
	}
	return INVALID_ENT_REFERENCE;
}
TFObjectType GetFirstClassBuildable(TFClassType class) {
	TF2PlayerClassData data = new TF2PlayerClassData(class);
	data.Load();
	TFObjectType building = data.GetBuildable(1);
	delete data;
	return building;
}

/**
 * If you give a classname, the econ item is optional and the game will give the default item in that case.
 * If you specify an econItem, the classname is optional as it can be derived from the item definition index.
 */
int GiveWeaponFromItemView(int client, const char[] weaponclass="", Address econItem=Address_Null, bool dontReplace=false) {
	if (!IsClientInGame(client) || !IsPlayerAlive(client)) return INVALID_ENT_REFERENCE;
	char classname[64];
	if (StrContains(weaponclass, "tf_weapon_")==0 || StrContains(weaponclass, "tf_wearable")==0) {
		strcopy(classname, sizeof(classname), weaponclass);
	}
	if (classname[0]==0 && econItem==Address_Null)
		ThrowError("Unspecified Item");
	
	//get client class
	TFClassType clClass = TF2_GetPlayerClass(client);
	//get item loadout slot from dropped weapon
	int dItemId;
	if (econItem != Address_Null) {
		dItemId = GetItemViewItemDef(econItem);
	} else {
		dItemId = GetDefaultItemDef(classname, clClass);
		if (dItemId < 0) return INVALID_ENT_REFERENCE; //no applicable to current class;
	}
	int loSlot = TF2Econ_GetItemLoadoutSlot(dItemId, clClass);
	if ( loSlot == -1 ) return INVALID_ENT_REFERENCE;
	//get active weapon in loadout slot
	int wSlot;
	int aWeapon = FindWeaponForLoadoutSlot(client, loSlot, wSlot);
	//patch run pickup: no space in inventory -> stop
	if (dontReplace && aWeapon != INVALID_ENT_REFERENCE) {
		return INVALID_ENT_REFERENCE; //don't drop as requested
	}
	//translate weapon name for class ( dropped itemclass , class )
	if (classname[0] == 0) //no classname given, find one
		if ( !TF2Econ_GetItemClassName(dItemId, classname, sizeof(classname)) ) return INVALID_ENT_REFERENCE;
	//try to translate in any case
	TF2Econ_TranslateWeaponEntForClass(classname, sizeof(classname), clClass);
	//givenameditem ( translated name )
	int subtype = 0;
	if (StrEqual("tf_weapon_builder", classname) || StrEqual("tf_weapon_sapper", classname)) {
		// usually set after creation, dynamic casting the CTFWeaponBase to CTFWeaponBuilder
		// but since we have to determin the class differently anyways, we can set it immediately
		subtype = view_as<int>(GetFirstClassBuildable(clClass));
	}
	int nWeapon = GiveNamedItem(client, classname, subtype, econItem);
	//if not item created fail fast
	if ( nWeapon == INVALID_ENT_REFERENCE ) return INVALID_ENT_REFERENCE;
	//if has active weapon
	if ( aWeapon != INVALID_ENT_REFERENCE ) {
		
		//if player in respawn room and active weapon is own weapon
		float vec[3];
		GetClientAbsOrigin(client, vec);
		int nWeaponAccountId = GetEntProp(nWeapon, Prop_Send, "m_iAccountID");
		// dont spam spawn weapons in the spawn room. apparently a crash fix
		if (TF2Util_IsPointInRespawnRoom(vec, client, true) && (nWeaponAccountId == 0 || nWeaponAccountId == GetSteamAccountID(client))) {
			TF2_RemoveWeaponSlot(client, wSlot);
		} else if (aWeapon != INVALID_ENT_REFERENCE) {
			//if we can't drop a melee it's probably fists or gunslinger, just remove it
			if (!DropWeapon(client, aWeapon, false) && wSlot == 2) TF2_RemoveWeaponSlot(client, wSlot);
		}
	}
	//give new weapon
	int lastWeapon = GetEntPropEnt(client, Prop_Send, "m_hLastWeapon");
	SetEntProp(nWeapon, Prop_Send, "m_bValidatedAttachedEntity", 1);
	EquipPlayerWeapon(client, nWeapon);
	//re-set last active
	SetEntPropEnt(client, Prop_Send, "m_hLastWeapon", lastWeapon);
	//init from dropped weapon would be called here, but this was exctracted
	if (!Weapon_CanSwitchTo(client, nWeapon)) {
		SDKCall(sc_NextBestWeapon, client, nWeapon);
	}
	//update m_flSendPickupWeaponMessageTime to .1 in the future
	SetEntDataFloat(client, off_m_flSendPickupWeaponMessageTime, GetGameTime()+0.1, true);
	return nWeapon;
}

// ----- Drop Weapons -----
bool IsVectorEmpty(const float vec[3]) { return IsNullVector(vec) || (vec[0] == 0.0 && vec[1] == 0.0 && vec[2] == 0.0); }
bool DropWeapon(int client, int weapon, bool switchWeapon=true, bool compatCall=false, const float compatTarget[3]=NULL_VECTOR, const float compatVelocity[3]=NULL_VECTOR) {
	if (!IsPlayerAlive(client) || !IsValidEdict(weapon)) return false;
	char clz[64];
	GetEntityClassname(weapon, clz, sizeof(clz));
	
	//not an equipped weapon
	if (StrContains(clz, "tf_weapon_")!=0) return false;
	//dropping the engi builder breaks things
	else if (StrEqual(clz, "tf_weapon_builder") && GetEntProp(weapon, Prop_Send, "m_iObjectType")!=view_as<int>(TFObject_Sapper)) return false;
	//prevent funny floaty arm with invis watch
	else if (StrEqual(clz, "tf_weapon_invis")) return false;
	
	if (!Notify_DropWeapon(client, weapon)) {
		return false;
	}
	
	float position[3], angles[3];
	GetClientEyePosition(client, position);
	GetClientEyeAngles(client, angles);
	angles[2]=0.0;
	if (angles[0] > 0.0) angles[0] /= 2.0;
	if (compatCall && !IsVectorEmpty(compatTarget)) position = compatTarget;
	
	int nextWeapon = -1;
	int slot = -1;
	for (int sloti=0;sloti<6;sloti+=1) {
		int slotWeapon = GetPlayerWeaponSlot(client, sloti);
		if (slotWeapon == weapon) { slot = sloti; break; }
		else if (nextWeapon == -1) nextWeapon = slotWeapon;
	}
	if (slot < 0) return false;
	
	char model[PLATFORM_MAX_PATH];
	SDKCall(sc_WeaponGetWorldModel, weapon, model, sizeof(model));
	if (model[0]==0) return false;
	Address item = GetEconItemView(weapon, "CTFWeaponBase");
	
	int entity = SDKCall(sc_DroppedWeaponCreate, client, position, angles, model, item);
	if (entity == INVALID_ENT_REFERENCE) return false;
	SDKCall(sc_DroppedWeaponInit, entity, client, weapon, false, false);
	
	float velocity[3];
	if (compatCall && !IsVectorEmpty(compatVelocity)) {
		velocity = compatVelocity;
	} else {
		GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(velocity, 400.0);
	}
	TeleportEntity(entity, position, angles, velocity);
	
	TF2_RemoveWeaponSlot(client, slot);
	if (switchWeapon) SwitchToPreviousWeaponOr(client, weapon, nextWeapon);
	
	g_clDropTimes[client] = GetGameTime();
	
	Notify_DropWeaponPost(client, entity);
	
	return true;
}

int CreateDroppedWeaponEnt(const char[] model, Address pItem, const float origin[3], const float angles[3]) {
	if (model[0] == 0) return INVALID_ENT_REFERENCE; //aint working
	int droppedWeapon = CreateEntityByName("tf_dropped_weapon");
	if (droppedWeapon != INVALID_ENT_REFERENCE) {
		DispatchKeyValueVector(droppedWeapon, "origin", origin);
		DispatchKeyValueVector(droppedWeapon, "angles", angles);
		SetEntityModel(droppedWeapon, model);
		SetEconItemView(droppedWeapon, "CTFDroppedWeapon", pItem);
		
		DispatchSpawn(droppedWeapon);
		
		int itemDef;
		if ((itemDef = GetItemViewItemDef(pItem)) >= 0) {
			int clip = GetWeaponDefaultMaxClipByClassName(itemDef);
			SetDroppedWeaponAmmo(droppedWeapon, clip, 9999); //max ammo will fix itself on pickup
		}
	}
	return droppedWeapon;
}

public MRESReturn DHook_WeaponCreate(DHookReturn hReturn, DHookParam hParams) {
	if (!cv_SupressWeaponCleanup.BoolValue) return MRES_Ignored;
	
	//i had the option to mem patch, or re-implement. to make this toggle-able
	// it seemd easier to just re-implement.
	//replicated logic, skipping preconditions
	
	//int player = hParams.Get(1);//unused
	float origin[3], angles[3];
	hParams.GetVector(2, origin);
	hParams.GetVector(3, angles);
	char model[PLATFORM_MAX_PATH];
	hParams.GetString(4, model, sizeof(model));
	Address item = hParams.Get(5);
	
	int droppedWeapon = CreateDroppedWeaponEnt(model, item, origin, angles);
	hReturn.Value = droppedWeapon;
	return MRES_Supercede;
}

// ----- Pick up Weapons -----

bool TryPickUpCursorEnt(int client) {
	if (client == 0 || !IsClientInGame(client)) return false;
	
	//get cursor ent	
	float eyes[3], tmp[3], fwd[3], scan[3];
	GetClientEyePosition(client, eyes);
	GetClientEyeAngles(client, tmp);
	GetAngleVectors(tmp, fwd, NULL_VECTOR, NULL_VECTOR);
	//limit reach to 200
	scan = fwd;
	ScaleVector(scan, 200.0);
	AddVectors(scan, eyes, scan);
	//trace
	TR_TraceRayFilter(eyes, scan, MASK_SHOT_HULL, RayType_EndPoint, Trace_SelfHitFilter, client);
	
	int entity;
	if (!TR_DidHit() || (entity = TR_GetEntityIndex()) == INVALID_ENT_REFERENCE || entity == 0) {
		return false;
	}
	char classname[32];
	GetEntityClassname(entity, classname, sizeof(classname));
	if (!StrEqual(classname, "tf_dropped_weapon")) {
		return false;
	}
	
	if (PickupWeaponFromOther(client, entity, cv_IgnorePickupRestrictions.BoolValue) != INVALID_ENT_REFERENCE) {
		EmitSoundToAll("items/gunpickup2.wav", client);
	} else {
		EmitSoundToClient(client, "common/wpn_denyselect.wav");
	}
	return true;
}

/** Public interface to pick up dropped weapons.
 * Will delete dropped entity on success as expected.
 * @param client target to get the weapon
 * @param droppedWeapon the weapon to pick up
 * @param force if true, uses a custom implementation (see PickupWeaponFromOtherRe)
 * @return the new weapon entity on success
 */
int PickupWeaponFromOther(int client, int droppedWeapon, bool force) {
	if (!IsPlayerAlive(client) || !IsValidEdict(droppedWeapon)) return INVALID_ENT_REFERENCE;
	char clz[20];
	GetEntityClassname(droppedWeapon, clz, sizeof(clz));
	if (!StrEqual(clz, "tf_dropped_weapon")) return INVALID_ENT_REFERENCE; //not a dropped weapon
	
	if (!Notify_PickupWeapon(client, droppedWeapon)) return INVALID_ENT_REFERENCE;
	
	int newWeapon = (force ? PickupWeaponFromOtherRe(client, droppedWeapon) : SDKCall(sc_PickupOtherWeapon, client, droppedWeapon));
	if (newWeapon != INVALID_ENT_REFERENCE) {
		RemoveEdict(droppedWeapon);
		Notify_PickupWeaponPost(client, droppedWeapon);
	}
	return newWeapon;
}

/** Pick up a dropped weapon to a living player.
 * This does not delete the dropped weapon entity (as the original).
 * Ignores certain limitations the game normally has, like:
 * - the same slot has to have a weapon to drop
 * - player class check
 * @param act like "run over pickup", requiring an empty loadout slot to load into. opposite of default game behaviour!
 * @return picked up weapon on success, INVALID_ENT_REFERENCE otherwise
 */
int PickupWeaponFromOtherRe(int client, int droppedWeapon, bool runPickup=false) {
	if (!IsPlayerAlive(client) || !IsValidEdict(droppedWeapon)) return INVALID_ENT_REFERENCE;
	char classname[64];
	GetEntityClassname(droppedWeapon, classname, sizeof(classname));
	if (!StrEqual(classname, "tf_dropped_weapon")) return INVALID_ENT_REFERENCE; //not a dropped weapon
	
	//hack the item definition index, so stock shotguns can be picked up by any shotgun wielding class, as expected (stoopid vanilla behaviour)
	int itemDef = GetEntProp(droppedWeapon, Prop_Send, "m_iItemDefinitionIndex");
	int adjustedDef = AdjustItemDefForClass(itemDef, TF2_GetPlayerClass(client));
	if (adjustedDef != itemDef) { //stock item && adjustable to target class && was adjusted
		SetEntProp(droppedWeapon, Prop_Send, "m_iItemDefinitionIndex", adjustedDef);
		PrintToServer("Changed itemDef from %i to %i", itemDef, adjustedDef);
	}
	
	Address pItem = GetEconItemView(droppedWeapon, "CTFDroppedWeapon");
	int nWeapon = GiveWeaponFromItemView(client, .econItem=pItem, .dontReplace=runPickup);
	if (nWeapon != INVALID_ENT_REFERENCE) {
		//init picked up weapon from dropped weapon
		SDKCall(sc_PickedUpWeaponInit, droppedWeapon, client, nWeapon);
	}
	return nWeapon;
}


int GetClosestPlayers(const float pos[3], float maxDist, int[] clients, int maxClients) {
	ArrayList collection = new ArrayList(2);
	maxDist *= maxDist;
	for (int client=1;client<=MaxClients;client+=1) {
		if (!IsClientInGame(client) || !IsPlayerAlive(client)) continue;
		
		float clpos[3];
		GetClientAbsOrigin(client, clpos);
		float dist = GetVectorDistance(clpos, pos, true);
		
		if (dist > maxDist) continue;
		
		any distIdx[2]; distIdx[0] = dist; distIdx[1] = client;
		collection.PushArray(distIdx);
	}
	collection.Sort(Sort_Ascending, Sort_Float);
	int index;
	for (;index<maxClients && index<collection.Length;index+=1) {
		clients[index] = collection.Get(index,1);
	}
	delete collection;
	return index;
}
Action Timer_PickupThink(Handle timer) {
	if (!cv_TouchPickup.BoolValue || !cv_Enabled.BoolValue) return Plugin_Continue;
	
	for (int index = g_EntityAge.Length-1; index >= 0; index -= 1) {
		int entity = EntRefToEntIndex(g_EntityAge.Get(index,0));
		if (entity == INVALID_ENT_REFERENCE) { g_EntityAge.Erase(index); continue; }
		float age = g_EntityAge.Get(index,1);
		age = GetGameTime() - age;
		if (age < 1.0) continue;
		
		float origin[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
		int clients[10];
		int count = GetClosestPlayers(origin,48.0, clients, sizeof(clients));
		for (int target; target<count; target+=1) {
			if (TryPickupWeapon(clients[target], entity)) break;
		}
	}
	
	return Plugin_Continue;
}

bool TryPickupWeapon(int client, int weapon) {
	if (!IsValidEntity(weapon) || !(1<=client<=MaxClients) || !IsClientInGame(client) || !IsPlayerAlive(client)) return false;
	
	//safety check, abuse the notification timer to not pick up items too quickly, or they might get deleted
	float next = GetEntDataFloat(client, off_m_flSendPickupWeaponMessageTime);
	if (GetGameTime()-next < 0) return false;
	next = g_clDropTimes[client];
	if (GetGameTime()-next < 0.1) return false;
	
	int itemdef = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	TFClassType class = TF2_GetPlayerClass(client);
	int slot = TF2Econ_GetItemLoadoutSlot(itemdef, class);
	int slotWeapon = FindWeaponForLoadoutSlot(client, slot);
	
	// - if we try to pickup into a melee slot while unarmed, we want to force the pickup (hard)
	// - otherwise we only want to pick up the weapon if the slot is empty (soft)
	bool softPickup = !( slot == 2/*melee*/ && dep_GraviHands && TF2GH_IsClientUnarmed(client) );
	
	if (softPickup && slotWeapon != INVALID_ENT_REFERENCE) return false;
	bool picked = PickupWeaponFromOtherRe(client, weapon, softPickup) != INVALID_ENT_REFERENCE;
	if (picked) {
		RemoveEntity(weapon);
		EmitSoundToAll("items/gunpickup2.wav", client);
	}
	return picked;
}

// ----- Re-equip single items -----

/**
 * @param client - client to give item to
 * @param slot - loadout slot to load
 * @param class - class to load, or Unknown for clients current class
 * @param inventoryClient - client to load inventory from, or 0 for target
 * @return weapon entity on success
 */
int GivePlayerLoadoutItem(int client, int slot, TFClassType class=TFClass_Unknown, int inventoryClient=0) {
	if (!inventoryClient) inventoryClient = client;
	if (class == TFClass_Unknown) class = TF2_GetPlayerClass(client);
	Address pItem = GetLoadoutItemView(inventoryClient, class, slot);
	if (pItem == Address_Null) return INVALID_ENT_REFERENCE;
	return GiveWeaponFromItemView(client, .econItem=pItem);
}

int GivePlayerStockItem(int client, int slot, TFClassType class=TFClass_Unknown) {
	if (class == TFClass_Unknown) class = TF2_GetPlayerClass(client);
	int itemDef = GetStockWeaponItemDef(class, slot);
	if (itemDef == -1) return INVALID_ENT_REFERENCE;
	char classname[64];
	if (!TF2Econ_GetItemClassName(itemDef, classname, sizeof(classname))) return INVALID_ENT_REFERENCE;
	return GiveWeaponFromItemView(client, .weaponclass=classname);
}
