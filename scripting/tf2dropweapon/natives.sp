#include <sourcemod>

static GlobalForward fwd_WeaponDrop;
static GlobalForward fwd_WeaponDropPost;
static GlobalForward fwd_WeaponPickup;
static GlobalForward fwd_WeaponPickupPost;

void InitNatives() {
	CreateNative("TF2DW_DropWeaponLoadoutSlot", Native_DropWeapon);
	CreateNative("TF2DW_GiveWeaponByClassname", Native_GiveClassname);
	CreateNative("TF2DW_GiveWeaponForLoadoutSlot", Native_GiveLoadout);
}

void InitForwards() {
	fwd_WeaponDrop = CreateGlobalForward("TF2DW_OnClientDropWeapon", ET_Event, Param_Cell, Param_Cell);
	fwd_WeaponDropPost = CreateGlobalForward("TF2DW_OnClientDropWeaponPost", ET_Event, Param_Cell, Param_Cell);
	fwd_WeaponPickup = CreateGlobalForward("TF2DW_OnClientPickupWeapon", ET_Event, Param_Cell, Param_Cell);
	fwd_WeaponPickupPost = CreateGlobalForward("TF2DW_OnClientPickupWeaponPost", ET_Event, Param_Cell, Param_Cell);
}

public any Native_DropWeapon(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int slot = GetNativeCell(2);
	if (!(1<=client<=MaxClients) || !IsClientInGame(client) || !IsPlayerAlive(client))
		ThrowNativeError(SP_ERROR_INDEX, "Invalid client index %i, not ingame and alive", client);
	if (!(0<=slot<6))
		ThrowNativeError(SP_ERROR_INDEX, "Invalid loadout slot %i", slot);
	
	int weapon = FindWeaponForLoadoutSlot(client, slot);
	return DropWeapon(client, weapon);
}

public any Native_GiveClassname(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	char classname[64];
	GetNativeString(2, classname, sizeof(classname));
	if (!(1<=client<=MaxClients) || !IsClientInGame(client) || !IsPlayerAlive(client))
		ThrowNativeError(SP_ERROR_INDEX, "Invalid client index %i, not ingame and alive", client);
	if (!IsValidWeaponClassname(classname))
		ThrowNativeError(SP_ERROR_PARAM, "Invalid classname %s, not a weapon or wearable", classname);
		
	return GiveWeaponFromItemView(client, classname);
}

public any Native_GiveLoadout(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int slot = GetNativeCell(2);
	bool useStock = GetNativeCell(3)!=0;
	if (!(1<=client<=MaxClients) || !IsClientInGame(client) || !IsPlayerAlive(client))
		ThrowNativeError(SP_ERROR_INDEX, "Invalid client index %i, not ingame and alive", client);
	if (!(0<=slot<6))
		ThrowNativeError(SP_ERROR_INDEX, "Invalid loadout slot %i", slot);
		
	if (useStock)
		return GivePlayerStockItem(client, slot);
	else
		return GivePlayerLoadoutItem(client, slot);
	
}

bool Notify_DropWeapon(int client, int weapon) {
	Call_StartForward(fwd_WeaponDrop);
	Call_PushCell(client);
	Call_PushCell(weapon);
	Action result;
	int error = Call_Finish(result);
	if (error != SP_ERROR_NONE) ThrowError("Error during FWD Drop Weapon %i %i", client, weapon);
	return result < Plugin_Handled;
}

void Notify_DropWeaponPost(int client, int droppedWeapon) {
	Call_StartForward(fwd_WeaponDropPost);
	Call_PushCell(client);
	Call_PushCell(droppedWeapon);
	int error = Call_Finish();
	if (error != SP_ERROR_NONE) ThrowError("Error during FWD Drop Weapon Post %i %i", client, droppedWeapon);
}

bool Notify_PickupWeapon(int client, int droppedWeapon) {
	Call_StartForward(fwd_WeaponPickup);
	Call_PushCell(client);
	Call_PushCell(droppedWeapon);
	Action result;
	int error = Call_Finish(result);
	if (error != SP_ERROR_NONE) ThrowError("Error during FWD Pickup Weapon %i %i", client, droppedWeapon);
	return result < Plugin_Handled;
}

void Notify_PickupWeaponPost(int client, int weapon) {
	Call_StartForward(fwd_WeaponPickupPost);
	Call_PushCell(client);
	Call_PushCell(weapon);
	int error = Call_Finish();
	if (error != SP_ERROR_NONE) ThrowError("Error during FWD Pickup Weapon Post %i %i", client, weapon);
}